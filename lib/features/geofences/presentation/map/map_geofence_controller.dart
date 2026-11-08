import 'package:maplibre_gl/maplibre_gl.dart';

/// Abstraction interface for MapLibre map layer, source, and camera operations
/// required for geofence spatial rendering.
///
/// Decouples geofence rendering from native platform channels to enable
/// 100% headless automated unit and widget testing.
abstract class MapGeofenceController {
  /// Adds a GeoJSON source with [sourceId] and GeoJSON data to the style.
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson);

  /// Updates existing GeoJSON source data in-place without destroying layers.
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson);

  /// Adds a native fill layer referencing [sourceId].
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    FillLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  });

  /// Adds a native line layer referencing [sourceId].
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  });

  /// Adds a native symbol layer referencing [sourceId] for text labels.
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  });

  /// Sets the visibility of the layer identified by [layerId].
  Future<void> setLayerVisibility(String layerId, bool visible);

  /// Removes the style layer identified by [layerId].
  Future<void> removeLayer(String layerId);

  /// Removes the style source identified by [sourceId].
  Future<void> removeSource(String sourceId);

  /// Animates the camera viewport.
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration});

  /// Checks if the underlying native controller is disposed.
  bool get isDisposed;
}

/// Production adapter bridging [MapLibreMapController] to [MapGeofenceController].
class MapLibreGeofenceAdapter implements MapGeofenceController {
  final MapLibreMapController _controller;

  MapLibreGeofenceAdapter(this._controller);

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _controller.addGeoJsonSource(sourceId, geojson);
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _controller.setGeoJsonSource(sourceId, geojson);
  }

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    FillLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) {
    return _controller.addFillLayer(
      sourceId,
      layerId,
      properties,
      belowLayerId: belowLayerId,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) {
    return _controller.addLineLayer(
      sourceId,
      layerId,
      properties,
      belowLayerId: belowLayerId,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) {
    return _controller.addSymbolLayer(
      sourceId,
      layerId,
      properties,
      belowLayerId: belowLayerId,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) {
    return _controller.setLayerVisibility(layerId, visible);
  }

  @override
  Future<void> removeLayer(String layerId) {
    return _controller.removeLayer(layerId);
  }

  @override
  Future<void> removeSource(String sourceId) {
    return _controller.removeSource(sourceId);
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) {
    return _controller.animateCamera(cameraUpdate, duration: duration);
  }

  @override
  bool get isDisposed => _controller.isDisposed;
}
