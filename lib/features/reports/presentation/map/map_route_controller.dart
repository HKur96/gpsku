import 'dart:typed_data';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Abstraction layer for MapLibre map line, source, symbol, and camera operations.
/// Decouples route rendering from native platform channels for 100% headless testing.
abstract class MapRouteController {
  /// Adds a GeoJSON source with [sourceId] and GeoJSON map data.
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson);

  /// Updates existing GeoJSON source data without recreating layers.
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson);

  /// Adds a native line layer referencing [sourceId].
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  });

  /// Removes the style layer identified by [layerId].
  Future<void> removeLayer(String layerId);

  /// Removes the style source identified by [sourceId].
  Future<void> removeSource(String sourceId);

  /// Registers an in-memory bitmap image for marker icons.
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool defer = false,
    double pixelRatio = 1.0,
  ]);

  /// Adds a map symbol (marker) to the canvas.
  Future<Symbol> addSymbol(SymbolOptions options, [Map<String, dynamic>? data]);

  /// Updates properties of an existing symbol.
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes);

  /// Removes a single symbol.
  Future<void> removeSymbol(Symbol symbol);

  /// Removes multiple symbols.
  Future<void> removeSymbols(Iterable<Symbol> symbols);

  /// Removes all symbols managed by the map.
  Future<void> clearSymbols();

  /// Adds a listener for marker taps.
  void addSymbolTappedListener(void Function(Symbol symbol) listener);

  /// Removes a listener for marker taps.
  void removeSymbolTappedListener(void Function(Symbol symbol) listener);

  /// Animates the camera viewport.
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration});

  /// Checks if the underlying native controller is disposed.
  bool get isDisposed;
}

/// Production adapter bridging [MapLibreMapController] to [MapRouteController].
class MapLibreRouteAdapter implements MapRouteController {
  final MapLibreMapController _controller;

  MapLibreRouteAdapter(this._controller);

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _controller.addGeoJsonSource(sourceId, geojson);
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _controller.setGeoJsonSource(sourceId, geojson);
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
  Future<void> removeLayer(String layerId) {
    return _controller.removeLayer(layerId);
  }

  @override
  Future<void> removeSource(String sourceId) {
    return _controller.removeSource(sourceId);
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool defer = false,
    double pixelRatio = 1.0,
  ]) {
    return _controller.addImage(name, bytes, defer, pixelRatio);
  }

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
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) {
    return _controller.animateCamera(cameraUpdate, duration: duration);
  }

  @override
  bool get isDisposed => _controller.isDisposed;
}
