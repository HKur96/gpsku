import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'package:gpsku/core/utils/position_ordering_guard.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';

/// State management provider for real-time fleet devices and positions.
/// Employs a 150ms coalescing buffer to prevent UI rebuild thrashing during
/// high-throughput WebSocket bursts, while strictly enforcing PositionOrderingGuard.
class LiveFleetProvider extends ChangeNotifier {
  final TraccarWebSocketService webSocketService;
  final Duration coalescingWindow;

  final Map<int, DeviceModel> _devices = {};
  final Map<int, PositionModel> _positions = {};
  final Map<int, GroupModel> _groups = {};
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  int? _selectedDeviceId;

  // Coalescing buffer structures
  final Map<int, DeviceModel> _pendingDevices = {};
  final Map<int, PositionModel> _pendingPositions = {};
  Timer? _flushTimer;

  StreamSubscription? _wsStateSub;
  StreamSubscription? _wsMessageSub;

  LiveFleetProvider({
    required this.webSocketService,
    this.coalescingWindow = const Duration(milliseconds: 150),
  }) {
    _initSubscriptions();
  }

  Map<int, DeviceModel> get devices => Map.unmodifiable(_devices);
  Map<int, PositionModel> get positions => Map.unmodifiable(_positions);
  Map<int, GroupModel> get groups => Map.unmodifiable(_groups);
  WebSocketConnectionState get connectionState => _connectionState;
  int? get selectedDeviceId => _selectedDeviceId;
  DeviceModel? get selectedDevice =>
      _selectedDeviceId != null ? _devices[_selectedDeviceId] : null;
  PositionModel? get selectedPosition =>
      _selectedDeviceId != null ? _positions[_selectedDeviceId] : null;

  bool get hasActiveBuffer => _flushTimer != null && _flushTimer!.isActive;

  void _initSubscriptions() {
    _connectionState = webSocketService.state;
    _wsStateSub = webSocketService.stateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _wsMessageSub = webSocketService.messageStream.listen(
      _handleIncomingPayload,
    );
  }

  /// Ingests incoming WebSocket payload (devices, positions, events).
  void _handleIncomingPayload(Map<String, dynamic> json) {
    bool hasUpdates = false;

    // Process devices array
    if (json.containsKey('devices') && json['devices'] is List) {
      for (final raw in json['devices']) {
        if (raw is Map) {
          final device = DeviceModel.fromJson(Map<String, dynamic>.from(raw));
          _pendingDevices[device.id] = device;
          hasUpdates = true;
        }
      }
    }

    // Process positions array with PositionOrderingGuard
    if (json.containsKey('positions') && json['positions'] is List) {
      for (final raw in json['positions']) {
        if (raw is Map) {
          final incomingPos = PositionModel.fromJson(
            Map<String, dynamic>.from(raw),
          );
          final existingPos =
              _pendingPositions[incomingPos.deviceId] ??
              _positions[incomingPos.deviceId];

          if (PositionOrderingGuard.shouldUpdate(existingPos, incomingPos)) {
            _pendingPositions[incomingPos.deviceId] = incomingPos;
            hasUpdates = true;
          } else {
            AppLogger.info(
              'Rejected stale position for device ${incomingPos.deviceId} '
              '(incoming fixTime: ${incomingPos.fixTime}, existing: ${existingPos?.fixTime})',
            );
          }
        }
      }
    }

    if (hasUpdates) {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(coalescingWindow, _flushPendingUpdates);
    }
  }

  /// Merges buffered pending state into public collections and notifies UI listeners.
  void _flushPendingUpdates() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_pendingDevices.isEmpty && _pendingPositions.isEmpty) {
      return;
    }

    if (_pendingDevices.isNotEmpty) {
      _devices.addAll(_pendingDevices);
      _pendingDevices.clear();
    }

    if (_pendingPositions.isNotEmpty) {
      _positions.addAll(_pendingPositions);
      _pendingPositions.clear();
    }

    notifyListeners();
  }

  /// Forces immediate synchronous flush of pending buffers (useful for testing and teardown).
  void flushImmediately() {
    _flushPendingUpdates();
  }

  /// Seeds or merges initial devices and positions loaded from REST API.
  /// When [clearExisting] is false, strictly preserves existing real-time positions
  /// that are newer than incoming REST positions via [PositionOrderingGuard].
  void setInitialFleetData({
    required List<DeviceModel> initialDevices,
    required List<PositionModel> initialPositions,
    List<GroupModel> initialGroups = const [],
    bool clearExisting = false,
  }) {
    if (clearExisting) {
      _devices.clear();
      _positions.clear();
      _groups.clear();
      _pendingDevices.clear();
      _pendingPositions.clear();
    }

    for (final dev in initialDevices) {
      _devices[dev.id] = dev;
    }

    for (final grp in initialGroups) {
      _groups[grp.id] = grp;
    }

    for (final pos in initialPositions) {
      final existing =
          _pendingPositions[pos.deviceId] ?? _positions[pos.deviceId];
      if (PositionOrderingGuard.shouldUpdate(existing, pos)) {
        _positions[pos.deviceId] = pos;
      }
    }

    notifyListeners();
  }

  /// Updates or sets operational groups metadata.
  void updateGroups(List<GroupModel> updatedGroups) {
    if (updatedGroups.isEmpty) return;
    for (final grp in updatedGroups) {
      _groups[grp.id] = grp;
    }
    notifyListeners();
  }

  /// Updates or adds devices metadata without touching positions.
  /// Used for background metadata refresh upon WebSocket reconnection.
  void updateDevices(List<DeviceModel> updatedDevices) {
    if (updatedDevices.isEmpty) return;
    for (final dev in updatedDevices) {
      _devices[dev.id] = dev;
    }
    notifyListeners();
  }

  /// Updates positions monotonically using [PositionOrderingGuard].
  void updatePositions(List<PositionModel> updatedPositions) {
    if (updatedPositions.isEmpty) return;
    bool hasUpdates = false;
    for (final pos in updatedPositions) {
      final existing =
          _pendingPositions[pos.deviceId] ?? _positions[pos.deviceId];
      if (PositionOrderingGuard.shouldUpdate(existing, pos)) {
        _positions[pos.deviceId] = pos;
        hasUpdates = true;
      }
    }
    if (hasUpdates) {
      notifyListeners();
    }
  }

  void selectDevice(int? deviceId) {
    if (_selectedDeviceId != deviceId) {
      _selectedDeviceId = deviceId;
      notifyListeners();
    }
  }

  void clearFleet() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _devices.clear();
    _positions.clear();
    _groups.clear();
    _pendingDevices.clear();
    _pendingPositions.clear();
    _selectedDeviceId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _wsStateSub?.cancel();
    _wsMessageSub?.cancel();
    super.dispose();
  }
}
