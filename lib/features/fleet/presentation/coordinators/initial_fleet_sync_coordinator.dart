import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/datasources/traccar_websocket_service.dart';
import '../../data/models/device_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/position_model.dart';
import '../../domain/repositories/fleet_repository.dart';
import '../providers/live_fleet_provider.dart';

/// Lifecycle state machine for initial fleet synchronization.
enum FleetSyncState {
  notInitialized,
  loading,
  ready,
  partialData,
  error,
  reconnecting,
}

/// Status outcome of a synchronization attempt.
enum FleetSyncStatus { success, partial, failure, cancelled }

/// Immutable result object describing the outcome of a fleet synchronization attempt.
@immutable
class FleetSyncResult {
  final FleetSyncStatus status;
  final int devicesCount;
  final int positionsCount;
  final Failure? failure;
  final String? message;

  const FleetSyncResult({
    required this.status,
    this.devicesCount = 0,
    this.positionsCount = 0,
    this.failure,
    this.message,
  });

  bool get isSuccess => status == FleetSyncStatus.success;
  bool get isPartial => status == FleetSyncStatus.partial;
  bool get isFailure => status == FleetSyncStatus.failure;
  bool get isCancelled => status == FleetSyncStatus.cancelled;

  @override
  String toString() =>
      'FleetSyncResult(status: $status, devices: $devicesCount, positions: $positionsCount, failure: $failure)';
}

/// Coordinates initial fleet synchronization using the "Defensive Dual-Fetch with Monotonic Handover"
/// strategy accepted in P7.3.0.
///
/// Responsibilities:
/// 1. Concurrently fetches REST devices and positions to establish initial fleet state before activating WebSocket.
/// 2. Merges fleet entities into [LiveFleetProvider] without wiping newer real-time positions.
/// 3. Initiates WebSocket connection after REST seeding or on partial device availability.
/// 4. Handles background metadata refresh of `/api/devices` upon WebSocket reconnection.
/// 5. Protects against duplicate concurrent sync requests and handles cancellation/logout cleanly.
class InitialFleetSyncCoordinator extends ChangeNotifier {
  final FleetRepository fleetRepository;
  final LiveFleetProvider liveFleetProvider;
  final TraccarWebSocketService webSocketService;

  FleetSyncState _syncState = FleetSyncState.notInitialized;
  String? _errorMessage;
  Failure? _lastFailure;

  CancelToken? _activeCancelToken;
  Future<FleetSyncResult>? _inFlightSync;
  StreamSubscription<WebSocketConnectionState>? _wsStateSubscription;

  bool _isReconnectingRefreshActive = false;
  bool _isDisposed = false;
  WebSocketConnectionState _previousWsState =
      WebSocketConnectionState.disconnected;
  bool _hasEverConnected = false;
  final Duration metadataRefreshCooldown;
  DateTime? _lastMetadataRefreshTime;

  InitialFleetSyncCoordinator({
    required this.fleetRepository,
    required this.liveFleetProvider,
    required this.webSocketService,
    bool autoListenReconnection = true,
    this.metadataRefreshCooldown = const Duration(seconds: 3),
  }) {
    if (autoListenReconnection) {
      _startReconnectionListener();
    }
  }

  FleetSyncState get syncState => _syncState;
  String? get errorMessage => _errorMessage;
  Failure? get lastFailure => _lastFailure;
  bool get isLoading => _syncState == FleetSyncState.loading;
  bool get isReady => _syncState == FleetSyncState.ready;
  bool get hasPartialData => _syncState == FleetSyncState.partialData;
  bool get hasError => _syncState == FleetSyncState.error;
  bool get isReconnecting => _syncState == FleetSyncState.reconnecting;
  DateTime? get lastMetadataRefreshTime => _lastMetadataRefreshTime;

  /// Starts listening to WebSocket connection state transitions to trigger
  /// device metadata refresh upon successful reconnection.
  void _startReconnectionListener() {
    _previousWsState = webSocketService.state;
    _wsStateSubscription = webSocketService.stateStream.listen(
      _handleWebSocketStateChange,
    );
  }

  void _handleWebSocketStateChange(WebSocketConnectionState newState) {
    if (_isDisposed) return;

    if (newState == WebSocketConnectionState.connected) {
      // Reconnection condition: We were previously connected, entered reconnecting state,
      // and now reconnected successfully.
      if (_hasEverConnected &&
          _previousWsState == WebSocketConnectionState.reconnecting) {
        AppLogger.info(
          'InitialFleetSyncCoordinator: Reconnection detected. Triggering device metadata refresh.',
        );
        refreshDevicesMetadata();
      }
      _hasEverConnected = true;
      if (_syncState == FleetSyncState.reconnecting) {
        _setSyncState(FleetSyncState.ready);
      }
    } else if (newState == WebSocketConnectionState.reconnecting) {
      if (_syncState == FleetSyncState.ready ||
          _syncState == FleetSyncState.partialData) {
        _setSyncState(FleetSyncState.reconnecting);
      }
    }

    _previousWsState = newState;
  }

  /// Refreshes device metadata in the background upon WebSocket reconnection.
  /// Does NOT reset positions or disrupt ongoing WebSocket telemetry streams.
  ///
  /// Protected by a cooldown guard (minimum 3 seconds by default) to prevent
  /// request spamming during rapid network flapping.
  Future<void> refreshDevicesMetadata({bool ignoreCooldown = false}) async {
    if (_isDisposed || _isReconnectingRefreshActive) return;

    final now = DateTime.now();
    if (!ignoreCooldown && _lastMetadataRefreshTime != null) {
      final elapsed = now.difference(_lastMetadataRefreshTime!);
      if (elapsed < metadataRefreshCooldown) {
        AppLogger.info(
          'InitialFleetSyncCoordinator: Metadata refresh throttled (cooldown active: ${elapsed.inMilliseconds}ms < ${metadataRefreshCooldown.inMilliseconds}ms).',
        );
        return;
      }
    }

    _isReconnectingRefreshActive = true;
    _lastMetadataRefreshTime = now;
    try {
      final result = await fleetRepository.getDevices();
      result.fold(
        (failure) {
          AppLogger.warn(
            'InitialFleetSyncCoordinator: Metadata refresh failed: ${failure.message}. '
            'Preserving existing fleet data.',
          );
        },
        (devices) {
          AppLogger.info(
            'InitialFleetSyncCoordinator: Metadata refresh succeeded (${devices.length} devices updated).',
          );
          liveFleetProvider.updateDevices(devices);
        },
      );
    } catch (e) {
      AppLogger.warn(
        'InitialFleetSyncCoordinator: Error during metadata refresh: $e',
      );
    } finally {
      _isReconnectingRefreshActive = false;
    }
  }

  /// Executes the initial fleet synchronization lifecycle:
  /// 1. Concurrently fetches `/api/devices` and `/api/positions`.
  /// 2. Evaluates responses and seeds [LiveFleetProvider].
  /// 3. Connects [TraccarWebSocketService] when data is available.
  Future<FleetSyncResult> synchronizeFleet({
    bool connectWebSocketOnSuccess = true,
  }) async {
    if (_isDisposed) {
      return const FleetSyncResult(
        status: FleetSyncStatus.cancelled,
        message: 'Coordinator is disposed',
      );
    }

    // Concurrency Protection: Serialize in-flight sync to prevent duplicate requests
    if (_inFlightSync != null) {
      AppLogger.info(
        'InitialFleetSyncCoordinator: Sync already in-flight, returning active future.',
      );
      return _inFlightSync!;
    }

    _inFlightSync = _executeDualFetchSync(
      connectWebSocketOnSuccess: connectWebSocketOnSuccess,
    );

    try {
      final result = await _inFlightSync!;
      return result;
    } finally {
      _inFlightSync = null;
    }
  }

  Future<FleetSyncResult> _executeDualFetchSync({
    required bool connectWebSocketOnSuccess,
  }) async {
    _setSyncState(FleetSyncState.loading);
    _errorMessage = null;
    _lastFailure = null;

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    try {
      AppLogger.info(
        'InitialFleetSyncCoordinator: Starting concurrent fetch (devices + positions + groups)...',
      );

      // Concurrent Multi-Fetch
      final results = await Future.wait([
        fleetRepository.getDevices(cancelToken: cancelToken),
        fleetRepository.getPositions(cancelToken: cancelToken),
        fleetRepository.getGroups(cancelToken: cancelToken),
      ]);

      if (cancelToken.isCancelled || _isDisposed) {
        return const FleetSyncResult(
          status: FleetSyncStatus.cancelled,
          message: 'Synchronization was cancelled',
        );
      }

      final devicesResult = results[0] as Either<Failure, List<DeviceModel>>;
      final positionsResult =
          results[1] as Either<Failure, List<PositionModel>>;
      final groupsResult = results[2] as Either<Failure, List<GroupModel>>;

      return await _processDualFetchResults(
        devicesResult: devicesResult,
        positionsResult: positionsResult,
        groupsResult: groupsResult,
        connectWebSocketOnSuccess: connectWebSocketOnSuccess,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || cancelToken.isCancelled) {
        return const FleetSyncResult(
          status: FleetSyncStatus.cancelled,
          message: 'Request cancelled',
        );
      }
      _lastFailure = NetworkFailure(e.message ?? 'Network error');
      _errorMessage = _lastFailure!.message;
      _setSyncState(FleetSyncState.error);
      return FleetSyncResult(
        status: FleetSyncStatus.failure,
        failure: _lastFailure,
        message: _errorMessage,
      );
    } catch (e) {
      if (cancelToken.isCancelled || _isDisposed) {
        return const FleetSyncResult(
          status: FleetSyncStatus.cancelled,
          message: 'Synchronization was cancelled',
        );
      }
      _lastFailure = UnexpectedFailure(e.toString());
      _errorMessage = _lastFailure!.message;
      _setSyncState(FleetSyncState.error);
      return FleetSyncResult(
        status: FleetSyncStatus.failure,
        failure: _lastFailure,
        message: _errorMessage,
      );
    } finally {
      if (_activeCancelToken == cancelToken) {
        _activeCancelToken = null;
      }
    }
  }

  Future<FleetSyncResult> _processDualFetchResults({
    required Either<Failure, List<DeviceModel>> devicesResult,
    required Either<Failure, List<PositionModel>> positionsResult,
    required Either<Failure, List<GroupModel>> groupsResult,
    required bool connectWebSocketOnSuccess,
  }) async {
    // Process groups gracefully without failing the overall sync
    groupsResult.fold(
      (failure) {
        AppLogger.warn(
          'InitialFleetSyncCoordinator: Groups fetch failed (${failure.message}), continuing without groups.',
        );
      },
      (groups) {
        liveFleetProvider.updateGroups(groups);
      },
    );

    final bool isDevicesSuccess = devicesResult.isRight();
    final bool isPositionsSuccess = positionsResult.isRight();

    // Case 1: Both REST requests succeeded
    if (isDevicesSuccess && isPositionsSuccess) {
      final devices = devicesResult.getOrElse((_) => const []);
      final positions = positionsResult.getOrElse((_) => const []);

      AppLogger.info(
        'InitialFleetSyncCoordinator: Dual-fetch succeeded (${devices.length} devices, ${positions.length} positions).',
      );

      liveFleetProvider.setInitialFleetData(
        initialDevices: devices,
        initialPositions: positions,
        clearExisting: false,
      );

      _setSyncState(FleetSyncState.ready);

      if (connectWebSocketOnSuccess) {
        await webSocketService.connect();
      }

      return FleetSyncResult(
        status: FleetSyncStatus.success,
        devicesCount: devices.length,
        positionsCount: positions.length,
      );
    }

    // Case 2: Devices succeeded, Positions failed
    if (isDevicesSuccess && !isPositionsSuccess) {
      final devices = devicesResult.getOrElse((_) => const []);
      final Failure posFailure = positionsResult.fold(
        (f) => f,
        (_) => const UnexpectedFailure('Unknown failure'),
      );

      AppLogger.warn(
        'InitialFleetSyncCoordinator: Positions fetch failed (${posFailure.message}), '
        'retaining ${devices.length} devices as partial data.',
      );

      liveFleetProvider.updateDevices(devices);
      _lastFailure = posFailure;
      _errorMessage = 'Gagal memuat posisi armada: ${posFailure.message}';
      _setSyncState(FleetSyncState.partialData);

      // Connect WebSocket: WebSocket initial positions payload will deliver missing positions
      if (connectWebSocketOnSuccess) {
        await webSocketService.connect();
      }

      return FleetSyncResult(
        status: FleetSyncStatus.partial,
        devicesCount: devices.length,
        failure: posFailure,
        message: _errorMessage,
      );
    }

    // Case 3: Positions succeeded, Devices failed
    if (!isDevicesSuccess && isPositionsSuccess) {
      final positions = positionsResult.getOrElse((_) => const []);
      final Failure devFailure = devicesResult.fold(
        (f) => f,
        (_) => const UnexpectedFailure('Unknown failure'),
      );

      AppLogger.warn(
        'InitialFleetSyncCoordinator: Devices fetch failed (${devFailure.message}), '
        'retaining ${positions.length} positions as partial data.',
      );

      liveFleetProvider.updatePositions(positions);
      _lastFailure = devFailure;
      _errorMessage = 'Gagal memuat daftar perangkat: ${devFailure.message}';
      _setSyncState(FleetSyncState.partialData);

      return FleetSyncResult(
        status: FleetSyncStatus.partial,
        positionsCount: positions.length,
        failure: devFailure,
        message: _errorMessage,
      );
    }

    // Case 4: Both failed
    final Failure devFailure = devicesResult.fold(
      (f) => f,
      (_) => const UnexpectedFailure('Unknown failure'),
    );
    final Failure posFailure = positionsResult.fold(
      (f) => f,
      (_) => const UnexpectedFailure('Unknown failure'),
    );

    AppLogger.error(
      'InitialFleetSyncCoordinator: Dual-fetch completely failed (devices: ${devFailure.message}, positions: ${posFailure.message})',
    );

    _lastFailure = devFailure;
    _errorMessage = 'Gagal memuat data armada: ${devFailure.message}';
    _setSyncState(FleetSyncState.error);

    return FleetSyncResult(
      status: FleetSyncStatus.failure,
      failure: devFailure,
      message: _errorMessage,
    );
  }

  void _setSyncState(FleetSyncState newState) {
    if (_syncState != newState && !_isDisposed) {
      _syncState = newState;
      notifyListeners();
    }
  }

  /// Cancels any active in-flight REST synchronization requests.
  void cancel() {
    _activeCancelToken?.cancel('Synchronization cancelled by caller');
    _activeCancelToken = null;
    _inFlightSync = null;
    if (_syncState == FleetSyncState.loading) {
      _setSyncState(FleetSyncState.notInitialized);
    }
  }

  /// Resets coordinator state back to [FleetSyncState.notInitialized].
  void reset() {
    cancel();
    _errorMessage = null;
    _lastFailure = null;
    _hasEverConnected = false;
    _setSyncState(FleetSyncState.notInitialized);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    cancel();
    _wsStateSubscription?.cancel();
    _wsStateSubscription = null;
    super.dispose();
  }
}
