import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'camera_calculation_helper.dart';
import 'map_asset_registrar.dart';

/// Abstraction layer for MapLibre symbol operations.
///
/// Enables complete decoupling of [FleetMarkerManager] from native platform channel
/// specifics, allowing 100% headless automated unit and widget testing.
abstract class MapSymbolController {
  Future<Symbol> addSymbol(SymbolOptions options, [Map<String, dynamic>? data]);
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes);
  Future<void> removeSymbol(Symbol symbol);
  Future<void> removeSymbols(Iterable<Symbol> symbols);
  Future<void> clearSymbols();
  void addSymbolTappedListener(void Function(Symbol symbol) listener);
  void removeSymbolTappedListener(void Function(Symbol symbol) listener);
  bool get isDisposed;
}

/// Production adapter bridging [MapLibreMapController] to [MapSymbolController].
class MapLibreSymbolAdapter implements MapSymbolController {
  final MapLibreMapController _controller;

  MapLibreSymbolAdapter(this._controller);

  @override
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) {
    return _controller.addSymbol(options, data);
  }

  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) {
    return _controller.updateSymbol(symbol, changes);
  }

  @override
  Future<void> removeSymbol(Symbol symbol) {
    return _controller.removeSymbol(symbol);
  }

  @override
  Future<void> removeSymbols(Iterable<Symbol> symbols) {
    return _controller.removeSymbols(symbols);
  }

  @override
  Future<void> clearSymbols() {
    return _controller.clearSymbols();
  }

  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {
    _controller.onSymbolTapped.add(listener);
  }

  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {
    _controller.onSymbolTapped.remove(listener);
  }

  @override
  bool get isDisposed => _controller.isDisposed;
}

/// High-performance symbol layer coordinator for the GPSku live fleet map.
///
/// Responsibilities:
/// 1. Synchronizes fleet devices and positions from [LiveFleetProvider] onto the MapLibre canvas.
/// 2. Performs surgical in-place symbol updates to maintain 60–120 FPS without UI jank.
/// 3. Resolves category and status color icons from [MapAssetRegistrar] (28 variants + direction).
/// 4. Reflects heading/course rotation ([PositionModel.course]) smoothly on markers.
/// 5. Elevates and highlights selected vehicle markers ([LiveFleetProvider.selectedDeviceId]).
/// 6. Captures marker tap events and dispatches device selection intents.
class FleetMarkerManager {
  MapSymbolController? _controller;
  LiveFleetProvider? _liveFleetProvider;
  VoidCallback? _fleetListener;
  bool _isDisposed = false;

  /// External callback fired when a vehicle marker is clicked/tapped.
  void Function(int deviceId)? onMarkerTapped;

  /// Active map symbols indexed by device ID.
  final Map<int, Symbol> _deviceSymbols = {};

  /// Reverse index mapping MapLibre symbol string ID to Traccar device ID.
  final Map<String, int> _symbolIdToDeviceId = {};

  /// Cache of last rendered states for surgical diffing.
  final Map<int, LatLng> _renderedCoords = {};
  final Map<int, double> _renderedRotations = {};
  final Map<int, String> _renderedIconIds = {};
  final Map<int, String> _renderedTitles = {};
  int? _renderedSelectedDeviceId;

  /// Mutex guards to serialize asynchronous platform channel operations.
  bool _isSyncInProgress = false;
  bool _needsResync = false;

  FleetMarkerManager({this.onMarkerTapped});

  /// Whether a live, non-disposed map controller is attached.
  bool get isReady =>
      _controller != null && !_controller!.isDisposed && !_isDisposed;

  /// Count of active vehicle symbols currently managed on the map.
  int get symbolCount => _deviceSymbols.length;

  /// Retrieves the active [Symbol] for [deviceId], or null if not rendered.
  Symbol? getSymbolForDevice(int deviceId) => _deviceSymbols[deviceId];

  /// Whether a symbol is currently registered for [deviceId].
  bool isMarkerRegistered(int deviceId) => _deviceSymbols.containsKey(deviceId);

  /// Retrieves the last rendered icon ID for [deviceId].
  String? getRenderedIconId(int deviceId) => _renderedIconIds[deviceId];

  /// Retrieves the last rendered coordinate for [deviceId].
  LatLng? getRenderedCoordinate(int deviceId) => _renderedCoords[deviceId];

  /// Retrieves the last rendered rotation for [deviceId].
  double? getRenderedRotation(int deviceId) => _renderedRotations[deviceId];

  /// Attaches a production [MapLibreMapController] to this marker manager.
  void attach(
    MapLibreMapController controller, {
    LiveFleetProvider? fleetProvider,
  }) {
    attachController(
      MapLibreSymbolAdapter(controller),
      fleetProvider: fleetProvider,
    );
  }

  /// Attaches an abstract [MapSymbolController] (useful for testing or custom controllers).
  void attachController(
    MapSymbolController controller, {
    LiveFleetProvider? fleetProvider,
  }) {
    if (_isDisposed) {
      AppLogger.warn(
        'FleetMarkerManager: Attempted to attach controller to disposed manager.',
      );
      return;
    }

    detach();

    _controller = controller;
    _controller!.addSymbolTappedListener(_handleSymbolTapped);

    if (fleetProvider != null) {
      _liveFleetProvider = fleetProvider;
      _fleetListener = _onFleetProviderChanged;
      _liveFleetProvider!.addListener(_fleetListener!);
      // Initial synchronization pass
      syncFromProvider();
    }
  }

  /// Detaches the active controller and fleet provider.
  Future<void> detach({bool clearMapSymbols = false}) async {
    if (_liveFleetProvider != null && _fleetListener != null) {
      _liveFleetProvider!.removeListener(_fleetListener!);
      _fleetListener = null;
      _liveFleetProvider = null;
    }

    if (_controller != null && !_controller!.isDisposed) {
      _controller!.removeSymbolTappedListener(_handleSymbolTapped);
      if (clearMapSymbols && _deviceSymbols.isNotEmpty) {
        try {
          await _controller!.clearSymbols();
        } catch (e) {
          AppLogger.warn(
            'FleetMarkerManager: Error clearing symbols on detach: $e',
          );
        }
      }
    }

    _controller = null;
    _deviceSymbols.clear();
    _symbolIdToDeviceId.clear();
    _renderedCoords.clear();
    _renderedRotations.clear();
    _renderedIconIds.clear();
    _renderedTitles.clear();
    _renderedSelectedDeviceId = null;
    _isSyncInProgress = false;
    _needsResync = false;
  }

  /// Disposes this marker manager and unregisters all listeners.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    detach();
  }

  /// Listener invoked when [LiveFleetProvider] notifies changes.
  void _onFleetProviderChanged() {
    syncFromProvider();
  }

  /// Synchronizes markers using current state from the attached [LiveFleetProvider].
  Future<void> syncFromProvider() async {
    if (_liveFleetProvider == null || !isReady) return;

    await syncFleet(
      devices: _liveFleetProvider!.devices,
      positions: _liveFleetProvider!.positions,
      selectedDeviceId: _liveFleetProvider!.selectedDeviceId,
    );
  }

  /// Synchronizes fleet symbols from explicit entity maps.
  ///
  /// Serializes operations to avoid concurrent interleaving of async platform calls.
  Future<void> syncFleet({
    required Map<int, DeviceModel> devices,
    required Map<int, PositionModel> positions,
    int? selectedDeviceId,
  }) async {
    if (!isReady) return;

    if (_isSyncInProgress) {
      _needsResync = true;
      return;
    }

    _isSyncInProgress = true;
    _needsResync = false;

    try {
      await _executeSync(
        devices: devices,
        positions: positions,
        selectedDeviceId: selectedDeviceId,
      );
    } catch (e, stack) {
      AppLogger.error(
        'FleetMarkerManager: Error during symbol synchronization: $e',
        e,
        stack,
      );
    } finally {
      _isSyncInProgress = false;
      if (_needsResync && isReady) {
        _needsResync = false;
        // Schedule next sync on microtask queue
        scheduleMicrotask(() => syncFromProvider());
      }
    }
  }

  /// Internal synchronization worker with surgical in-place diffing.
  Future<void> _executeSync({
    required Map<int, DeviceModel> devices,
    required Map<int, PositionModel> positions,
    int? selectedDeviceId,
  }) async {
    if (!isReady) return;

    final validDeviceIds = <int>{};
    final selectionChanged = _renderedSelectedDeviceId != selectedDeviceId;
    _renderedSelectedDeviceId = selectedDeviceId;

    // 1. Process all devices that have valid positions
    for (final device in devices.values) {
      final position = positions[device.id];
      if (position == null) continue;

      // Validate geographic coordinates
      if (!CameraCalculationHelper.isValidCoordinate(
        position.latitude,
        position.longitude,
      )) {
        continue;
      }

      validDeviceIds.add(device.id);

      final coord = LatLng(position.latitude, position.longitude);
      final rotation = _normalizeCourse(position.course);
      final isSelected = device.id == selectedDeviceId;
      final iconId = resolveIconId(
        device: device,
        position: position,
        isSelected: isSelected,
      );
      final title = device.name.isNotEmpty
          ? device.name
          : 'Device #${device.id}';
      final zIndex = isSelected ? 100 : 1;

      final existingSymbol = _deviceSymbols[device.id];

      if (existingSymbol == null) {
        // --- ADD NEW SYMBOL ---
        final options = SymbolOptions(
          geometry: coord,
          iconImage: iconId,
          iconRotate: rotation,
          iconSize: 1.0,
          textField: title,
          textSize: 11.0,
          textOffset: const Offset(0, 1.8),
          textAnchor: 'top',
          zIndex: zIndex,
        );

        try {
          final symbol = await _controller!.addSymbol(options, {
            'deviceId': device.id,
          });
          _deviceSymbols[device.id] = symbol;
          _symbolIdToDeviceId[symbol.id] = device.id;
          _renderedCoords[device.id] = coord;
          _renderedRotations[device.id] = rotation;
          _renderedIconIds[device.id] = iconId;
          _renderedTitles[device.id] = title;
        } catch (e) {
          AppLogger.warn(
            'FleetMarkerManager: Failed to add symbol for device ${device.id}: $e',
          );
        }
      } else {
        // --- IN-PLACE SURGICAL UPDATE ---
        final prevCoord = _renderedCoords[device.id];
        final prevRotation = _renderedRotations[device.id];
        final prevIconId = _renderedIconIds[device.id];
        final prevTitle = _renderedTitles[device.id];

        final coordChanged =
            prevCoord == null ||
            prevCoord.latitude != coord.latitude ||
            prevCoord.longitude != coord.longitude;
        final rotationChanged =
            prevRotation == null || (prevRotation - rotation).abs() > 0.1;
        final iconChanged = prevIconId != iconId;
        final titleChanged = prevTitle != title;

        // Only issue platform channel call if at least one visible property changed
        if (coordChanged ||
            rotationChanged ||
            iconChanged ||
            titleChanged ||
            selectionChanged) {
          final updatedOptions = SymbolOptions(
            geometry: coord,
            iconRotate: rotation,
            iconImage: iconId,
            textField: title,
            zIndex: zIndex,
          );

          try {
            await _controller!.updateSymbol(existingSymbol, updatedOptions);
            _renderedCoords[device.id] = coord;
            _renderedRotations[device.id] = rotation;
            _renderedIconIds[device.id] = iconId;
            _renderedTitles[device.id] = title;
          } catch (e) {
            AppLogger.warn(
              'FleetMarkerManager: Failed to update symbol for device ${device.id}: $e',
            );
          }
        }
      }
    }

    // 2. Remove symbols for devices that no longer exist or lost valid positions
    final toRemove = <int>[];
    for (final deviceId in _deviceSymbols.keys) {
      if (!validDeviceIds.contains(deviceId)) {
        toRemove.add(deviceId);
      }
    }

    for (final deviceId in toRemove) {
      final symbol = _deviceSymbols.remove(deviceId);
      if (symbol != null) {
        _symbolIdToDeviceId.remove(symbol.id);
        _renderedCoords.remove(deviceId);
        _renderedRotations.remove(deviceId);
        _renderedIconIds.remove(deviceId);
        _renderedTitles.remove(deviceId);
        try {
          await _controller!.removeSymbol(symbol);
        } catch (e) {
          AppLogger.warn(
            'FleetMarkerManager: Failed to remove symbol for device $deviceId: $e',
          );
        }
      }
    }
  }

  /// Internal handler for MapLibre symbol tap callback.
  void _handleSymbolTapped(Symbol symbol) {
    if (_isDisposed) return;

    int? deviceId;
    final dynamic data = symbol.data;
    if (data is Map && data['deviceId'] is int) {
      deviceId = data['deviceId'] as int;
    } else if (_symbolIdToDeviceId.containsKey(symbol.id)) {
      deviceId = _symbolIdToDeviceId[symbol.id];
    }

    if (deviceId != null) {
      AppLogger.info(
        'FleetMarkerManager: Marker tapped for deviceId=$deviceId',
      );
      onMarkerTapped?.call(deviceId);
      _liveFleetProvider?.selectDevice(deviceId);
    }
  }

  /// Normalizes course heading to a valid [0.0, 360.0) range.
  static double _normalizeCourse(double course) {
    if (course.isNaN || course.isInfinite) return 0.0;
    final normalized = course % 360.0;
    return normalized < 0.0 ? normalized + 360.0 : normalized;
  }

  /// Resolves the status color token ('success', 'error', 'neutral', 'info').
  static String resolveStatusColor({
    required DeviceModel device,
    PositionModel? position,
    bool isSelected = false,
  }) {
    if (isSelected) {
      return 'info';
    }

    if (position != null && position.attributes.containsKey('color')) {
      final customColor = position.attributes['color']
          ?.toString()
          .toLowerCase();
      if (customColor != null &&
          MapAssetRegistrar.supportedStatusColors.contains(customColor)) {
        return customColor;
      }
    }

    switch (device.status.toLowerCase()) {
      case 'online':
        return 'success';
      case 'offline':
        return 'error';
      case 'unknown':
      default:
        return 'neutral';
    }
  }

  /// Resolves the canonical MapLibre icon identifier (e.g. 'car-success', 'truck-error').
  static String resolveIconId({
    required DeviceModel device,
    PositionModel? position,
    bool isSelected = false,
  }) {
    final category = device.category ?? 'default';
    final statusColor = resolveStatusColor(
      device: device,
      position: position,
      isSelected: isSelected,
    );
    return MapAssetRegistrar.buildIconId(category, statusColor);
  }
}
