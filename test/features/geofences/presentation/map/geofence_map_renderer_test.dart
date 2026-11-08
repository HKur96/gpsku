import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/models/geofence_geometry.dart';
import 'package:gpsku/features/geofences/presentation/map/geofence_map_renderer.dart';
import 'package:gpsku/features/geofences/presentation/map/geofence_map_style_config.dart';
import 'package:gpsku/features/geofences/presentation/map/geofence_spatial_helper.dart';
import 'package:gpsku/features/geofences/presentation/map/map_geofence_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MockMapGeofenceController implements MapGeofenceController {
  final List<String> operationLog = [];
  final Map<String, Map<String, dynamic>> sources = {};
  final Map<String, FillLayerProperties> fillLayers = {};
  final Map<String, LineLayerProperties> lineLayers = {};
  final Map<String, SymbolLayerProperties> symbolLayers = {};
  final Map<String, bool> layerVisibility = {};
  final Map<String, String?> layerBelowId = {};

  CameraUpdate? lastCameraUpdate;
  Duration? lastCameraDuration;
  bool isDisposedValue = false;

  @override
  bool get isDisposed => isDisposedValue;

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    operationLog.add('addGeoJsonSource:$sourceId');
    sources[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    operationLog.add('setGeoJsonSource:$sourceId');
    sources[sourceId] = geojson;
  }

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    FillLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) async {
    operationLog.add('addFillLayer:$layerId');
    fillLayers[layerId] = properties;
    layerBelowId[layerId] = belowLayerId;
    layerVisibility[layerId] = true;
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) async {
    operationLog.add('addLineLayer:$layerId');
    lineLayers[layerId] = properties;
    layerBelowId[layerId] = belowLayerId;
    layerVisibility[layerId] = true;
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) async {
    operationLog.add('addSymbolLayer:$layerId');
    symbolLayers[layerId] = properties;
    layerBelowId[layerId] = belowLayerId;
    layerVisibility[layerId] = true;
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    operationLog.add('setLayerVisibility:$layerId:$visible');
    layerVisibility[layerId] = visible;
  }

  @override
  Future<void> removeLayer(String layerId) async {
    operationLog.add('removeLayer:$layerId');
    fillLayers.remove(layerId);
    lineLayers.remove(layerId);
    symbolLayers.remove(layerId);
    layerVisibility.remove(layerId);
    layerBelowId.remove(layerId);
  }

  @override
  Future<void> removeSource(String sourceId) async {
    operationLog.add('removeSource:$sourceId');
    sources.remove(sourceId);
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    operationLog.add('animateCamera');
    lastCameraUpdate = cameraUpdate;
    lastCameraDuration = duration;
    return true;
  }
}

void main() {
  group('GeofenceMapRenderer & Spatial Rendering Engine Tests', () {
    late MockMapGeofenceController mockController;
    late GeofenceMapRenderer renderer;

    final testGeofences = [
      const GeofenceModel(
        id: 1,
        name: 'Depot North',
        area:
            'POLYGON ((-6.10 106.80, -6.11 106.82, -6.12 106.80, -6.10 106.80))',
        attributes: {'color': '#4CAF50'},
      ),
      const GeofenceModel(
        id: 2,
        name: 'Airport Perimeter',
        area: 'CIRCLE (-6.1255 106.6559, 2000.0)',
        attributes: {'color': '#1E88E5'},
      ),
    ];

    setUp(() {
      mockController = MockMapGeofenceController();
      renderer = GeofenceMapRenderer(
        controller: mockController,
        styleConfig: const GeofenceMapStyleConfig(
          belowLayerId: 'vehicle-marker-layer',
        ),
      );
    });

    tearDown(() async {
      await renderer.dispose();
    });

    group('Initial Layer & Source Injection', () {
      test(
        'TC-GMR-01: Injects GeoJSON source, fill, line, and symbol layers with belowLayerId on first render',
        () async {
          final success = await renderer.renderGeofences(testGeofences);

          expect(success, isTrue);
          expect(renderer.isReady, isTrue);
          expect(renderer.currentGeofences.length, equals(2));

          // Verify sequence
          expect(
            mockController.operationLog,
            containsAllInOrder([
              'addGeoJsonSource:geofence-source',
              'addFillLayer:geofence-fill-layer',
              'addLineLayer:geofence-line-layer',
              'addSymbolLayer:geofence-symbol-layer',
            ]),
          );

          // Verify belowLayerId for Z-index ordering
          expect(
            mockController.layerBelowId['geofence-fill-layer'],
            equals('vehicle-marker-layer'),
          );
          expect(
            mockController.layerBelowId['geofence-line-layer'],
            equals('vehicle-marker-layer'),
          );
          expect(
            mockController.layerBelowId['geofence-symbol-layer'],
            equals('vehicle-marker-layer'),
          );

          // Verify source content
          final source = mockController.sources['geofence-source'];
          expect(source, isNotNull);
          expect((source!['features'] as List).length, equals(2));
        },
      );

      test('TC-GMR-02: Respects showLabels = false configuration', () async {
        final noLabelRenderer = GeofenceMapRenderer(
          controller: mockController,
          styleConfig: const GeofenceMapStyleConfig(showLabels: false),
        );

        await noLabelRenderer.renderGeofences(testGeofences);

        expect(
          mockController.operationLog,
          contains('addGeoJsonSource:geofence-source'),
        );
        expect(
          mockController.operationLog,
          contains('addFillLayer:geofence-fill-layer'),
        );
        expect(
          mockController.operationLog,
          contains('addLineLayer:geofence-line-layer'),
        );
        expect(
          mockController.operationLog,
          isNot(contains('addSymbolLayer:geofence-symbol-layer')),
        );

        await noLabelRenderer.dispose();
      });
    });

    group('In-Place Reactive Updates', () {
      test(
        'TC-GMR-03: Subsequent renderGeofences calls invoke setGeoJsonSource without recreating layers',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          final updatedGeofences = [
            ...testGeofences,
            const GeofenceModel(
              id: 3,
              name: 'Southern Depot',
              area: 'CIRCLE (-6.30 106.85, 800)',
            ),
          ];

          final success = await renderer.renderGeofences(updatedGeofences);

          expect(success, isTrue);
          expect(
            mockController.operationLog,
            equals(['setGeoJsonSource:geofence-source']),
          );

          // Verify updated features
          final source = mockController.sources['geofence-source'];
          expect((source!['features'] as List).length, equals(3));
          expect(renderer.currentGeofences.length, equals(3));
        },
      );
    });

    group('Visibility Toggling', () {
      test(
        'TC-GMR-04: setVisibility(false) hides fill, line, and symbol layers',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          await renderer.setVisibility(false);

          expect(renderer.isVisible, isFalse);
          expect(
            mockController.operationLog,
            containsAllInOrder([
              'setLayerVisibility:geofence-fill-layer:false',
              'setLayerVisibility:geofence-line-layer:false',
              'setLayerVisibility:geofence-symbol-layer:false',
            ]),
          );
        },
      );

      test(
        'TC-GMR-05: setVisibility(true) restores visibility on all layers',
        () async {
          await renderer.renderGeofences(testGeofences);
          await renderer.setVisibility(false);
          mockController.operationLog.clear();

          await renderer.setVisibility(true);

          expect(renderer.isVisible, isTrue);
          expect(
            mockController.operationLog,
            containsAllInOrder([
              'setLayerVisibility:geofence-fill-layer:true',
              'setLayerVisibility:geofence-line-layer:true',
              'setLayerVisibility:geofence-symbol-layer:true',
            ]),
          );
        },
      );

      test(
        'TC-GMR-06: Preserves hidden state when rendering new geofences while invisible',
        () async {
          await renderer.renderGeofences(testGeofences);
          await renderer.setVisibility(false);
          mockController.operationLog.clear();

          await renderer.renderGeofences([testGeofences[0]]);

          expect(
            mockController.operationLog,
            contains('setGeoJsonSource:geofence-source'),
          );
          expect(
            mockController.operationLog,
            contains('setLayerVisibility:geofence-fill-layer:false'),
          );
          expect(renderer.isVisible, isFalse);
        },
      );
    });

    group('Safe Teardown Ordering (Anti-SIGSEGV)', () {
      test(
        'TC-GMR-07: clearGeofences strictly removes SymbolLayer -> LineLayer -> FillLayer -> Source',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          await renderer.clearGeofences();

          // Exact teardown sequence verification:
          expect(
            mockController.operationLog,
            equals([
              'removeLayer:geofence-symbol-layer',
              'removeLayer:geofence-line-layer',
              'removeLayer:geofence-fill-layer',
              'removeSource:geofence-source',
            ]),
          );
          expect(renderer.currentGeofences, isEmpty);
        },
      );

      test(
        'TC-GMR-08: Re-rendering after clearGeofences re-injects full source and layer stack',
        () async {
          await renderer.renderGeofences(testGeofences);
          await renderer.clearGeofences();
          mockController.operationLog.clear();

          await renderer.renderGeofences(testGeofences);

          expect(
            mockController.operationLog,
            containsAllInOrder([
              'addGeoJsonSource:geofence-source',
              'addFillLayer:geofence-fill-layer',
              'addLineLayer:geofence-line-layer',
              'addSymbolLayer:geofence-symbol-layer',
            ]),
          );
        },
      );
    });

    group('Centroid & Bounds Camera Navigation', () {
      test(
        'TC-GMR-09: centerOnGeofence animates camera to computed centroid',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          final success = await renderer.centerOnGeofence(
            testGeofences[0],
            zoom: 14.0,
            duration: const Duration(milliseconds: 500),
          );

          expect(success, isTrue);
          expect(mockController.operationLog, contains('animateCamera'));
          expect(mockController.lastCameraUpdate, isNotNull);
          expect(
            mockController.lastCameraDuration,
            equals(const Duration(milliseconds: 500)),
          );
        },
      );

      test(
        'TC-GMR-10: fitGeofenceBounds animates camera to bounding envelope with padding',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          final success = await renderer.fitGeofenceBounds(
            testGeofences[1],
            padding: const EdgeInsets.all(40.0),
          );

          expect(success, isTrue);
          expect(mockController.operationLog, contains('animateCamera'));
          expect(mockController.lastCameraUpdate, isNotNull);
        },
      );

      test(
        'TC-GMR-11: fitAllGeofences fits cumulative bounding box for all active geofences',
        () async {
          await renderer.renderGeofences(testGeofences);
          mockController.operationLog.clear();

          final success = await renderer.fitAllGeofences();

          expect(success, isTrue);
          expect(mockController.operationLog, contains('animateCamera'));
        },
      );

      test(
        'TC-GMR-12: Camera navigation returns false for invalid geometry or unready state',
        () async {
          const invalidGeofence = GeofenceModel(
            id: 999,
            name: 'Invalid',
            area: 'NOT_VALID_WKT',
          );

          final res1 = await renderer.centerOnGeofence(invalidGeofence);
          final res2 = await renderer.fitGeofenceBounds(invalidGeofence);

          expect(res1, isFalse);
          expect(res2, isFalse);
        },
      );
    });

    group('GeofenceSpatialHelper Mathematical Precision Tests', () {
      test(
        'TC-GMR-13: Computes exact centroid for Circle, Polygon, and Polyline',
        () {
          // Circle centroid is exactly center
          const circle = CircleGeometry(
            center: LatLng(-6.2000, 106.8000),
            radiusMeters: 500,
          );
          expect(
            GeofenceSpatialHelper.calculateCentroid(circle),
            equals(const LatLng(-6.2000, 106.8000)),
          );

          // Polygon centroid (excluding duplicate closing vertex)
          const polygon = PolygonGeometry([
            LatLng(-6.10, 106.10),
            LatLng(-6.20, 106.20),
            LatLng(-6.30, 106.10),
            LatLng(-6.10, 106.10), // duplicate closer
          ]);
          final polyCentroid = GeofenceSpatialHelper.calculateCentroid(polygon);
          expect(polyCentroid.latitude, closeTo(-6.20, 1e-4));
          expect(polyCentroid.longitude, closeTo(106.1333, 1e-4));

          // Polyline centroid
          const polyline = PolylineGeometry([
            LatLng(-6.00, 106.00),
            LatLng(-6.20, 106.20),
          ], polylineDistance: 25.0);
          final lineCentroid = GeofenceSpatialHelper.calculateCentroid(
            polyline,
          );
          expect(lineCentroid.latitude, closeTo(-6.10, 1e-4));
          expect(lineCentroid.longitude, closeTo(106.10, 1e-4));
        },
      );

      test(
        'TC-GMR-14: Computes bounding envelope for Circle and expands with radius in meters',
        () {
          const circle = CircleGeometry(
            center: LatLng(0.0, 0.0),
            radiusMeters: 111195.0,
          ); // Exactly 1 degree of latitude
          final bounds = GeofenceSpatialHelper.calculateBounds(circle);

          expect(bounds.southwest.latitude, closeTo(-1.0, 1e-3));
          expect(bounds.northeast.latitude, closeTo(1.0, 1e-3));
          expect(bounds.southwest.longitude, closeTo(-1.0, 1e-3));
          expect(bounds.northeast.longitude, closeTo(1.0, 1e-3));
        },
      );

      test(
        'TC-GMR-15: Computes collection bounds for multiple mixed geometries',
        () {
          const circle = CircleGeometry(
            center: LatLng(-6.0, 106.0),
            radiusMeters: 1000,
          );
          const poly = PolygonGeometry([
            LatLng(-6.5, 106.5),
            LatLng(-6.6, 106.6),
            LatLng(-6.4, 106.4),
          ]);

          final bounds = GeofenceSpatialHelper.calculateCollectionBounds([
            circle,
            poly,
          ]);

          expect(bounds, isNotNull);
          expect(bounds!.southwest.latitude, lessThan(-6.5));
          expect(bounds.northeast.latitude, greaterThan(-6.01));
          expect(bounds.southwest.longitude, lessThan(106.01));
          expect(bounds.northeast.longitude, greaterThan(106.5));
        },
      );

      test('TC-GMR-16: Returns null for empty collection bounds', () {
        expect(GeofenceSpatialHelper.calculateCollectionBounds([]), isNull);
      });
    });

    group('Lifecycle & Attachment Edge Cases', () {
      test(
        'TC-GMR-17: Detach and attach controller without losing rendered state',
        () async {
          await renderer.renderGeofences(testGeofences);
          renderer.detach();

          expect(renderer.isReady, isFalse);
          final failCall = await renderer.renderGeofences(testGeofences);
          expect(failCall, isFalse);

          final newMock = MockMapGeofenceController();
          renderer.attach(newMock);
          expect(renderer.isReady, isTrue);
        },
      );

      test('TC-GMR-18: Controller disposed flag is respected', () {
        mockController.isDisposedValue = true;
        expect(renderer.isReady, isFalse);
      });
    });
  });
}
