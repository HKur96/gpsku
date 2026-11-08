import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/reports/presentation/map/map_route_controller.dart';
import 'package:gpsku/features/reports/presentation/map/route_map_asset_registrar.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MockRouteController implements MapRouteController {
  final Map<String, Uint8List> registeredImages = {};
  bool isDisposedValue = false;

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool defer = false,
    double pixelRatio = 1.0,
  ]) async {
    registeredImages[name] = bytes;
  }

  @override
  bool get isDisposed => isDisposedValue;

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {}
  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {}
  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) async {}
  @override
  Future<void> removeLayer(String layerId) async {}
  @override
  Future<void> removeSource(String sourceId) async {}
  @override
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) async => Symbol('mock', const SymbolOptions());
  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {}
  @override
  Future<void> removeSymbol(Symbol symbol) async {}
  @override
  Future<void> removeSymbols(Iterable<Symbol> symbols) async {}
  @override
  Future<void> clearSymbols() async {}
  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {}
  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {}
  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteMapAssetRegistrar Unit Tests', () {
    test(
      'TC-ASSET-01: Generates valid PNG bytes for route-start-pin',
      () async {
        final bytes = await RouteMapAssetRegistrar.generateWaypointMarkerBytes(
          iconId: RouteMapAssetRegistrar.startIconId,
          color: const Color(0xFF2E7D32),
          label: 'S',
        );

        expect(bytes, isNotEmpty);
        // Verify PNG magic number [0x89, 0x50, 0x4E, 0x47]
        expect(bytes[0], 0x89);
        expect(bytes[1], 0x50);
        expect(bytes[2], 0x4E);
        expect(bytes[3], 0x47);
      },
    );

    test('TC-ASSET-02: Generates valid PNG bytes for route-end-pin', () async {
      final bytes = await RouteMapAssetRegistrar.generateWaypointMarkerBytes(
        iconId: RouteMapAssetRegistrar.endIconId,
        color: const Color(0xFFC62828),
        label: 'F',
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('TC-ASSET-03: Generates valid PNG bytes for route-stop-pin', () async {
      final bytes = await RouteMapAssetRegistrar.generateWaypointMarkerBytes(
        iconId: RouteMapAssetRegistrar.stopIconId,
        color: const Color(0xFFEF6C00),
        label: 'P',
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('TC-ASSET-04: Caches generated bitmaps in memory', () async {
      expect(RouteMapAssetRegistrar.cachedBitmapCount, greaterThanOrEqualTo(3));
    });

    test('TC-ASSET-05: Registers all 3 icons into controller', () async {
      final mock = MockRouteController();
      final count = await RouteMapAssetRegistrar.registerRouteIcons(mock);

      expect(count, 3);
      expect(
        mock.registeredImages.containsKey(RouteMapAssetRegistrar.startIconId),
        isTrue,
      );
      expect(
        mock.registeredImages.containsKey(RouteMapAssetRegistrar.endIconId),
        isTrue,
      );
      expect(
        mock.registeredImages.containsKey(RouteMapAssetRegistrar.stopIconId),
        isTrue,
      );
    });
  });
}
