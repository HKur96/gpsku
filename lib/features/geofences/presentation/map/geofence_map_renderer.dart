import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import '../../data/models/geofence_model.dart';
import '../../domain/models/geofence_geometry.dart';
import 'geofence_geojson_builder.dart';
import 'geofence_map_style_config.dart';
import 'geofence_spatial_helper.dart';
import 'map_geofence_controller.dart';

/// High-performance spatial coordinator for rendering Traccar geofences
/// (polygons, circles, and polylines) on MapLibre GL.
///
/// Features:
/// - Reactive in-place GeoJSON updates (`setGeoJsonSource`) without layer re-creation.
/// - Layer ordering & Z-index injection below vehicle markers (`belowLayerId`).
/// - Visibility toggling (show / hide geofence layers).
/// - Safe teardown ordering: SymbolLayer -> LineLayer -> FillLayer -> Source to prevent native SIGSEGV crashes.
/// - Geofence centroid centering & bounding box camera framing.
class GeofenceMapRenderer {
  MapGeofenceController? _controller;
  GeofenceMapStyleConfig _styleConfig;

  bool _isDisposed = false;
  bool _sourceAdded = false;
  bool _fillLayerAdded = false;
  bool _lineLayerAdded = false;
  bool _symbolLayerAdded = false;
  bool _isVisible = true;

  List<GeofenceModel> _currentGeofences = [];

  GeofenceMapRenderer({
    MapGeofenceController? controller,
    GeofenceMapStyleConfig styleConfig = const GeofenceMapStyleConfig(),
  }) : _controller = controller,
       _styleConfig = styleConfig;

  /// Binds a [MapGeofenceController] instance.
  void attach(MapGeofenceController controller) {
    if (_isDisposed) {
      AppLogger.warn(
        'GeofenceMapRenderer: Cannot attach to disposed renderer.',
      );
      return;
    }
    _controller = controller;
  }

  /// Detaches the active controller without destroying renderer state.
  void detach() {
    _controller = null;
  }

  /// Updates styling configuration.
  void updateStyleConfig(GeofenceMapStyleConfig config) {
    _styleConfig = config;
  }

  /// Whether a valid controller is bound and ready for map operations.
  bool get isReady =>
      _controller != null && !_controller!.isDisposed && !_isDisposed;

  /// Current layer visibility state.
  bool get isVisible => _isVisible;

  /// Currently rendered geofence entities.
  List<GeofenceModel> get currentGeofences =>
      List.unmodifiable(_currentGeofences);

  /// Renders or updates [geofences] onto the MapLibre canvas.
  ///
  /// Uses in-place GeoJSON updates if layers are already initialized.
  /// Returns `true` if map synchronization succeeded.
  Future<bool> renderGeofences(List<GeofenceModel> geofences) async {
    if (!isReady) {
      AppLogger.warn(
        'GeofenceMapRenderer: renderGeofences aborted — controller not ready.',
      );
      return false;
    }

    _currentGeofences = List.unmodifiable(geofences);
    final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection(geofences);

    try {
      // 1. Source Injection / In-place Update
      if (!_sourceAdded) {
        await _controller!.addGeoJsonSource(
          GeofenceGeoJsonBuilder.defaultSourceId,
          geojson,
        );
        _sourceAdded = true;
      } else {
        await _controller!.setGeoJsonSource(
          GeofenceGeoJsonBuilder.defaultSourceId,
          geojson,
        );
      }

      // 2. Fill Layer Injection (Below markers)
      if (!_fillLayerAdded) {
        final fillProps = FillLayerProperties(
          fillColor: _styleConfig.fillColor,
          fillOpacity: _styleConfig.fillOpacity,
        );

        await _controller!.addFillLayer(
          GeofenceGeoJsonBuilder.defaultSourceId,
          GeofenceGeoJsonBuilder.defaultFillLayerId,
          fillProps,
          belowLayerId: _styleConfig.belowLayerId,
        );
        _fillLayerAdded = true;
      }

      // 3. Line Layer Injection (Perimeter outline)
      if (!_lineLayerAdded) {
        final lineProps = LineLayerProperties(
          lineColor: _styleConfig.lineColor,
          lineWidth: _styleConfig.lineWidth,
          lineOpacity: _styleConfig.lineOpacity,
          lineCap: 'round',
          lineJoin: 'round',
        );

        await _controller!.addLineLayer(
          GeofenceGeoJsonBuilder.defaultSourceId,
          GeofenceGeoJsonBuilder.defaultLineLayerId,
          lineProps,
          belowLayerId: _styleConfig.belowLayerId,
        );
        _lineLayerAdded = true;
      }

      // 4. Symbol Layer Injection (Title Text Labels)
      if (_styleConfig.showLabels && !_symbolLayerAdded) {
        final symbolProps = SymbolLayerProperties(
          textField: _styleConfig.labelField,
          textSize: _styleConfig.labelSize,
          textColor: _styleConfig.labelColor,
          textHaloColor: _styleConfig.labelHaloColor,
          textHaloWidth: _styleConfig.labelHaloWidth,
          textAnchor: 'center',
          textAllowOverlap: false,
        );

        await _controller!.addSymbolLayer(
          GeofenceGeoJsonBuilder.defaultSourceId,
          GeofenceGeoJsonBuilder.defaultSymbolLayerId,
          symbolProps,
          belowLayerId: _styleConfig.belowLayerId,
        );
        _symbolLayerAdded = true;
      }

      // 5. Ensure visibility state is respected
      if (!_isVisible) {
        await setVisibility(false);
      }

      return true;
    } catch (e, stack) {
      AppLogger.error(
        'GeofenceMapRenderer: Error during renderGeofences',
        e,
        stack,
      );
      return false;
    }
  }

  /// Toggles visibility of all geofence spatial layers (fill, line, symbol).
  Future<void> setVisibility(bool visible) async {
    _isVisible = visible;
    if (!isReady) return;

    try {
      if (_fillLayerAdded) {
        await _controller!.setLayerVisibility(
          GeofenceGeoJsonBuilder.defaultFillLayerId,
          visible,
        );
      }
      if (_lineLayerAdded) {
        await _controller!.setLayerVisibility(
          GeofenceGeoJsonBuilder.defaultLineLayerId,
          visible,
        );
      }
      if (_symbolLayerAdded) {
        await _controller!.setLayerVisibility(
          GeofenceGeoJsonBuilder.defaultSymbolLayerId,
          visible,
        );
      }
    } catch (e) {
      AppLogger.warn('GeofenceMapRenderer: Error setting visibility: $e');
    }
  }

  /// Centers the camera viewport on [geofence] centroid.
  Future<bool> centerOnGeofence(
    GeofenceModel geofence, {
    double? zoom,
    Duration? duration,
  }) async {
    if (!isReady) return false;
    final geom = geofence.tryGeometry;
    if (geom == null) return false;

    try {
      final centroid = GeofenceSpatialHelper.calculateCentroid(geom);
      final cameraUpdate = zoom != null
          ? CameraUpdate.newLatLngZoom(centroid, zoom)
          : CameraUpdate.newLatLng(centroid);

      final result = await _controller!.animateCamera(
        cameraUpdate,
        duration: duration,
      );
      return result ?? true;
    } catch (e) {
      AppLogger.warn('GeofenceMapRenderer: Error centering on geofence: $e');
      return false;
    }
  }

  /// Frames the camera viewport to fit [geofence] bounding envelope.
  Future<bool> fitGeofenceBounds(
    GeofenceModel geofence, {
    EdgeInsets? padding,
    Duration? duration,
  }) async {
    if (!isReady) return false;
    final geom = geofence.tryGeometry;
    if (geom == null) return false;

    try {
      final bounds = GeofenceSpatialHelper.calculateBounds(geom);
      final effectivePadding = padding ?? _styleConfig.boundsPadding;

      final cameraUpdate = CameraUpdate.newLatLngBounds(
        bounds,
        left: effectivePadding.left,
        top: effectivePadding.top,
        right: effectivePadding.right,
        bottom: effectivePadding.bottom,
      );

      final result = await _controller!.animateCamera(
        cameraUpdate,
        duration: duration,
      );
      return result ?? true;
    } catch (e) {
      AppLogger.warn('GeofenceMapRenderer: Error fitting geofence bounds: $e');
      return false;
    }
  }

  /// Frames the camera viewport to fit all currently rendered geofences.
  Future<bool> fitAllGeofences({
    EdgeInsets? padding,
    Duration? duration,
  }) async {
    if (!isReady || _currentGeofences.isEmpty) return false;

    final geometries = _currentGeofences
        .map((g) => g.tryGeometry)
        .whereType<GeofenceGeometry>();

    final bounds = GeofenceSpatialHelper.calculateCollectionBounds(geometries);
    if (bounds == null) return false;

    try {
      final effectivePadding = padding ?? _styleConfig.boundsPadding;
      final cameraUpdate = CameraUpdate.newLatLngBounds(
        bounds,
        left: effectivePadding.left,
        top: effectivePadding.top,
        right: effectivePadding.right,
        bottom: effectivePadding.bottom,
      );

      final result = await _controller!.animateCamera(
        cameraUpdate,
        duration: duration,
      );
      return result ?? true;
    } catch (e) {
      AppLogger.warn(
        'GeofenceMapRenderer: Error fitting all geofences bounds: $e',
      );
      return false;
    }
  }

  /// Safely removes geofence layers and source from the map canvas.
  ///
  /// Enforces strict teardown order:
  /// SymbolLayer -> LineLayer -> FillLayer -> GeoJsonSource
  /// to prevent native MapLibre GL SIGSEGV crashes.
  Future<void> clearGeofences() async {
    final controller = _controller;
    if (controller == null || controller.isDisposed) return;

    try {
      // 1. Remove SymbolLayer FIRST
      if (_symbolLayerAdded) {
        await controller.removeLayer(
          GeofenceGeoJsonBuilder.defaultSymbolLayerId,
        );
        _symbolLayerAdded = false;
      }

      // 2. Remove LineLayer SECOND
      if (_lineLayerAdded) {
        await controller.removeLayer(GeofenceGeoJsonBuilder.defaultLineLayerId);
        _lineLayerAdded = false;
      }

      // 3. Remove FillLayer THIRD
      if (_fillLayerAdded) {
        await controller.removeLayer(GeofenceGeoJsonBuilder.defaultFillLayerId);
        _fillLayerAdded = false;
      }

      // 4. Remove Source LAST (after all dependent layers are unlinked)
      if (_sourceAdded) {
        await controller.removeSource(GeofenceGeoJsonBuilder.defaultSourceId);
        _sourceAdded = false;
      }

      _currentGeofences = const [];
    } catch (e, stack) {
      AppLogger.error(
        'GeofenceMapRenderer: Error during clearGeofences',
        e,
        stack,
      );
    }
  }

  /// Disposes the renderer, detaches from the controller, and cleans up map resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await clearGeofences();
    _controller = null;
  }
}
