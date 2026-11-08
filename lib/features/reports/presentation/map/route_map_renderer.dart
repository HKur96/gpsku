import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'map_route_controller.dart';
import 'route_geojson_builder.dart';
import 'route_map_asset_registrar.dart';
import 'route_map_style_config.dart';

/// High-performance coordinator for rendering historical route polylines,
/// start/end terminus pins, stop markers, and dynamic camera framing on MapLibre.
class RouteMapRenderer {
  MapRouteController? _controller;
  RouteMapStyleConfig _styleConfig;
  bool _isDisposed = false;

  bool _sourceAdded = false;
  bool _layerAdded = false;

  final List<Symbol> _activeSymbols = [];
  final Map<String, StopReportModel> _symbolIdToStop = {};
  PositionModel? _currentStart;
  PositionModel? _currentEnd;

  /// Optional callbacks for waypoint marker interaction.
  void Function(StopReportModel stop)? onStopTapped;
  void Function(PositionModel start)? onStartTapped;
  void Function(PositionModel end)? onEndTapped;

  RouteMapRenderer({
    MapRouteController? controller,
    RouteMapStyleConfig styleConfig = const RouteMapStyleConfig(),
  }) : _controller = controller,
       _styleConfig = styleConfig;

  /// Attaches a [MapRouteController] and binds symbol click listeners.
  void attach(MapRouteController controller) {
    if (_isDisposed) {
      AppLogger.warn(
        'RouteMapRenderer: Attempted to attach to disposed instance.',
      );
      return;
    }
    _controller = controller;
    _controller?.addSymbolTappedListener(_handleSymbolTapped);
  }

  /// Detaches the controller without disposing the renderer.
  void detach() {
    _controller?.removeSymbolTappedListener(_handleSymbolTapped);
    _controller = null;
  }

  /// Updates styling configuration.
  void updateStyleConfig(RouteMapStyleConfig config) {
    _styleConfig = config;
  }

  /// Whether a valid controller is attached and non-disposed.
  bool get isReady =>
      _controller != null && !_controller!.isDisposed && !_isDisposed;

  /// Formats stop duration into compact human-readable text for map marker labels.
  static String formatDurationLabel(Duration duration) {
    if (duration.inHours > 0) {
      final mins = duration.inMinutes % 60;
      return mins > 0
          ? '${duration.inHours}j ${mins}m'
          : '${duration.inHours}j';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}d';
  }

  /// Renders route telemetry points and stop markers onto the map:
  /// 1. Updates / injects GeoJSON LineString source and LineLayer.
  /// 2. Places Start (Green), End (Red), and Stop (Amber) markers.
  /// 3. Frames camera viewport to fit route bounds.
  Future<bool> renderRoute({
    required List<PositionModel> positions,
    List<StopReportModel> stops = const [],
    bool animateCamera = true,
    Duration? cameraDuration,
  }) async {
    if (!isReady) {
      AppLogger.warn(
        'RouteMapRenderer: renderRoute aborted — controller not ready.',
      );
      return false;
    }

    final validCoords = RouteGeoJsonBuilder.extractValidCoordinates(positions);

    // 1. Handle Empty Route Edge Case
    if (validCoords.isEmpty) {
      await clearRoute();
      return false;
    }

    // 2. Generate and inject GeoJSON LineString
    final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
      positions,
    );
    await _syncLineLayer(geojson);

    // 3. Render Waypoint Markers (Start, End, Stops)
    await _renderWaypoints(positions, validCoords, stops);

    // 4. Frame Camera Viewport
    if (animateCamera) {
      await fitRouteBounds(validCoords, duration: cameraDuration);
    }

    return true;
  }

  /// Synchronizes GeoJSON source and line layer with native MapLibre engine.
  Future<void> _syncLineLayer(Map<String, dynamic> geojson) async {
    if (!isReady) return;

    try {
      if (!_sourceAdded) {
        await _controller!.addGeoJsonSource(
          RouteGeoJsonBuilder.defaultSourceId,
          geojson,
        );
        _sourceAdded = true;
      } else {
        await _controller!.setGeoJsonSource(
          RouteGeoJsonBuilder.defaultSourceId,
          geojson,
        );
      }

      if (!_layerAdded) {
        final lineProps = LineLayerProperties(
          lineColor: _styleConfig.lineColor,
          lineWidth: _styleConfig.lineWidth,
          lineOpacity: _styleConfig.lineOpacity,
          lineCap: _styleConfig.lineCap,
          lineJoin: _styleConfig.lineJoin,
        );

        await _controller!.addLineLayer(
          RouteGeoJsonBuilder.defaultSourceId,
          RouteGeoJsonBuilder.defaultLayerId,
          lineProps,
        );
        _layerAdded = true;
      }
    } catch (e, stack) {
      AppLogger.error(
        'RouteMapRenderer: Failed to sync GeoJSON line layer',
        e,
        stack,
      );
    }
  }

  /// Renders start, end, and stop symbols.
  Future<void> _renderWaypoints(
    List<PositionModel> rawPositions,
    List<LatLng> validCoords,
    List<StopReportModel> stops,
  ) async {
    await _clearSymbols();

    if (!isReady || validCoords.isEmpty) return;

    // Find first and last valid PositionModels
    final firstPos = rawPositions.firstWhere(
      (p) => CameraCalculationHelper.isValidCoordinate(p.latitude, p.longitude),
    );
    final lastPos = rawPositions.lastWhere(
      (p) => CameraCalculationHelper.isValidCoordinate(p.latitude, p.longitude),
    );

    _currentStart = firstPos;
    _currentEnd = lastPos;

    // A. Start Marker (Green)
    final startSymbol = await _controller!.addSymbol(
      SymbolOptions(
        geometry: LatLng(firstPos.latitude, firstPos.longitude),
        iconImage: RouteMapAssetRegistrar.startIconId,
        iconSize: 1.0,
        iconAnchor: 'center',
      ),
      {'type': 'start'},
    );
    _activeSymbols.add(startSymbol);

    // B. End Marker (Red) - Only if different point from start or route > 1 point
    if (validCoords.length > 1) {
      final endSymbol = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(lastPos.latitude, lastPos.longitude),
          iconImage: RouteMapAssetRegistrar.endIconId,
          iconSize: 1.0,
          iconAnchor: 'center',
        ),
        {'type': 'end'},
      );
      _activeSymbols.add(endSymbol);
    }

    // C. Stop Markers (Amber with duration text)
    for (final stop in stops) {
      if (CameraCalculationHelper.isValidCoordinate(
        stop.latitude,
        stop.longitude,
      )) {
        final label = formatDurationLabel(stop.durationTime);
        final symbol = await _controller!.addSymbol(
          SymbolOptions(
            geometry: LatLng(stop.latitude, stop.longitude),
            iconImage: RouteMapAssetRegistrar.stopIconId,
            iconSize: 0.9,
            iconAnchor: 'center',
            textField: label,
            textSize: 11.0,
            textColor: '#FFFFFF',
            textHaloColor: '#000000',
            textHaloWidth: 1.5,
            textOffset: const Offset(0, 1.8),
          ),
          {'type': 'stop'},
        );
        _activeSymbols.add(symbol);
        _symbolIdToStop[symbol.id] = stop;
      }
    }
  }

  /// Fits the camera viewport to encompass all valid coordinates.
  Future<bool> fitRouteBounds(
    List<LatLng> coordinates, {
    Duration? duration,
  }) async {
    if (!isReady || coordinates.isEmpty) return false;

    // Single point edge-case
    if (coordinates.length == 1) {
      final update = CameraUpdate.newLatLngZoom(coordinates.first, 15.0);
      await _controller!.animateCamera(update, duration: duration);
      return true;
    }

    final bounds = CameraCalculationHelper.calculateBounds(coordinates);
    if (bounds == null) return false;

    final padding = _styleConfig.boundsPadding;
    final update = CameraUpdate.newLatLngBounds(
      bounds,
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    );

    try {
      await _controller!.animateCamera(update, duration: duration);
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'RouteMapRenderer: Camera animation to bounds failed',
        e,
        stack,
      );
      return false;
    }
  }

  void _handleSymbolTapped(Symbol symbol) {
    final stop = _symbolIdToStop[symbol.id];
    if (stop != null) {
      onStopTapped?.call(stop);
      return;
    }

    if (_activeSymbols.isNotEmpty &&
        symbol.id == _activeSymbols.first.id &&
        _currentStart != null) {
      onStartTapped?.call(_currentStart!);
      return;
    }

    if (_activeSymbols.length > 1 &&
        symbol.id == _activeSymbols[1].id &&
        _currentEnd != null) {
      onEndTapped?.call(_currentEnd!);
    }
  }

  Future<void> _clearSymbols() async {
    if (!isReady) return;
    try {
      if (_activeSymbols.isNotEmpty) {
        await _controller!.removeSymbols(_activeSymbols);
        _activeSymbols.clear();
      }
      _symbolIdToStop.clear();
    } catch (e) {
      AppLogger.warn('RouteMapRenderer: Failed clearing symbols: $e');
    }
  }

  /// Safely removes route layer, source, and waypoint markers.
  /// Strict ordering: Layers removed BEFORE sources to prevent native MapLibre crashes.
  Future<void> clearRoute() async {
    await _clearSymbols();

    if (!isReady) return;

    try {
      // 1. Remove LineLayer FIRST
      if (_layerAdded) {
        await _controller!.removeLayer(RouteGeoJsonBuilder.defaultLayerId);
        _layerAdded = false;
      }

      // 2. Remove GeoJSON source SECOND
      if (_sourceAdded) {
        await _controller!.removeSource(RouteGeoJsonBuilder.defaultSourceId);
        _sourceAdded = false;
      }
    } catch (e, stack) {
      AppLogger.error('RouteMapRenderer: Error during clearRoute', e, stack);
    }
  }

  /// Disposes renderer, detaches listeners, and cleans up native map resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await clearRoute();
    detach();
  }
}
