import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/presentation/map/geofence_geojson_builder.dart';

void main() {
  group('GeofenceGeoJsonBuilder Unit Tests', () {
    group('Hex Color Normalization Tests', () {
      test('TC-GJB-01: Normalizes standard 6-digit hex color', () {
        expect(
          GeofenceGeoJsonBuilder.normalizeHexColor('#4CAF50'),
          equals('#4CAF50'),
        );
        expect(
          GeofenceGeoJsonBuilder.normalizeHexColor('#1e88e5'),
          equals('#1e88e5'),
        );
      });

      test(
        'TC-GJB-02: Normalizes 8-digit ARGB hex color by stripping alpha',
        () {
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor('#FF4CAF50'),
            equals('#4CAF50'),
          );
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor('#80E53935'),
            equals('#E53935'),
          );
        },
      );

      test(
        'TC-GJB-03: Normalizes 3-digit short hex color (#RGB -> #RRGGBB)',
        () {
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor('#FFF'),
            equals('#FFFFFF'),
          );
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor('#123'),
            equals('#112233'),
          );
        },
      );

      test('TC-GJB-04: Normalizes 0x prefixed hex integers (ARGB and RGB)', () {
        expect(
          GeofenceGeoJsonBuilder.normalizeHexColor('0xFF4CAF50'),
          equals('#4CAF50'),
        );
        expect(
          GeofenceGeoJsonBuilder.normalizeHexColor('0X1E88E5'),
          equals('#1E88E5'),
        );
      });

      test('TC-GJB-05: Normalizes bare 6-digit hex strings', () {
        expect(
          GeofenceGeoJsonBuilder.normalizeHexColor('FF9800'),
          equals('#FF9800'),
        );
      });

      test(
        'TC-GJB-06: Returns fallback for null, empty, or invalid color values',
        () {
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor(null),
            equals(GeofenceGeoJsonBuilder.fallbackColorHex),
          );
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor(''),
            equals(GeofenceGeoJsonBuilder.fallbackColorHex),
          );
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor('invalid-color'),
            equals(GeofenceGeoJsonBuilder.fallbackColorHex),
          );
          expect(
            GeofenceGeoJsonBuilder.normalizeHexColor(
              'invalid',
              fallback: '#000000',
            ),
            equals('#000000'),
          );
        },
      );
    });

    group('FeatureCollection Generation Tests', () {
      test(
        'TC-GJB-07: Returns empty FeatureCollection for empty geofence list',
        () {
          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([]);

          expect(geojson['type'], equals('FeatureCollection'));
          expect(geojson['features'], isEmpty);
        },
      );

      test(
        'TC-GJB-08: Skips malformed geofence perimeter without throwing',
        () {
          const invalidGeofence = GeofenceModel(
            id: 99,
            name: 'Broken Geofence',
            area: 'INVALID WKT SYNTAX',
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            invalidGeofence,
          ]);

          expect(geojson['features'], isEmpty);
        },
      );

      test(
        'TC-GJB-09: Transforms Polygon geofence into RFC 7946 Polygon with [lng, lat] and closed ring',
        () {
          const polygonGeofence = GeofenceModel(
            id: 101,
            name: 'Jakarta Port Zone',
            description: 'Customs restricted perimeter',
            area:
                'POLYGON ((-6.1000 106.8800, -6.1100 106.8900, -6.1200 106.8700, -6.1000 106.8800))',
            attributes: {
              'color': '#FF5722',
              'speedLimit': 40.0,
              'mapLineWidth': 3.0,
              'mapLineOpacity': 0.4,
            },
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            polygonGeofence,
          ]);

          final features = geojson['features'] as List;
          expect(features.length, equals(1));

          final feature = features[0] as Map<String, dynamic>;
          expect(feature['type'], equals('Feature'));
          expect(feature['id'], equals(101));

          final geometry = feature['geometry'] as Map<String, dynamic>;
          expect(geometry['type'], equals('Polygon'));

          final rings = geometry['coordinates'] as List;
          expect(rings.length, equals(1));
          final ring = rings[0] as List;
          expect(ring.length, equals(4));

          // Coordinate order verification: [longitude, latitude]
          expect(ring[0][0], closeTo(106.8800, 1e-6));
          expect(ring[0][1], closeTo(-6.1000, 1e-6));
          expect(ring[1][0], closeTo(106.8900, 1e-6));
          expect(ring[1][1], closeTo(-6.1100, 1e-6));
          expect(ring[2][0], closeTo(106.8700, 1e-6));
          expect(ring[2][1], closeTo(-6.1200, 1e-6));
          expect(ring[3][0], closeTo(106.8800, 1e-6));
          expect(ring[3][1], closeTo(-6.1000, 1e-6));

          // Closed ring check
          expect(ring.first[0], equals(ring.last[0]));
          expect(ring.first[1], equals(ring.last[1]));

          // Properties verification
          final props = feature['properties'] as Map<String, dynamic>;
          expect(props['id'], equals(101));
          expect(props['name'], equals('Jakarta Port Zone'));
          expect(props['color'], equals('#FF5722'));
          expect(props['strokeColor'], equals('#FF5722'));
          expect(props['strokeWidth'], equals(3.0));
          expect(props['fillOpacity'], equals(0.4));
          expect(props['geomType'], equals('POLYGON'));
          expect(props['speedLimit'], equals(40.0));
        },
      );

      test(
        'TC-GJB-10: Automatically closes unclosed Polygon coordinate rings',
        () {
          // Open ring with 3 distinct vertices (first != last)
          const unclosedPolygon = GeofenceModel(
            id: 102,
            name: 'Unclosed Triangle',
            area: 'POLYGON ((-6.10 106.80, -6.11 106.82, -6.12 106.81))',
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            unclosedPolygon,
          ]);

          final features = geojson['features'] as List;
          expect(features.length, equals(1));
          final rings = features[0]['geometry']['coordinates'] as List;
          final ring = rings[0] as List;

          // Must be closed with 4 points (last == first)
          expect(ring.length, equals(4));
          expect(ring.first[0], equals(ring.last[0]));
          expect(ring.first[1], equals(ring.last[1]));
        },
      );

      test(
        'TC-GJB-11: Transforms Circle geofence into 64-vertex Polygon approximation with closed ring',
        () {
          const circleGeofence = GeofenceModel(
            id: 201,
            name: 'Depot Warehouse Radius',
            area: 'CIRCLE (-6.2088 106.8456, 1500.0)',
            attributes: {'color': '#4CAF50', 'mapLineWidth': 2.5},
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            circleGeofence,
          ]);

          final features = geojson['features'] as List;
          expect(features.length, equals(1));

          final feature = features[0] as Map<String, dynamic>;
          expect(feature['id'], equals(201));

          final geometry = feature['geometry'] as Map<String, dynamic>;
          expect(geometry['type'], equals('Polygon'));

          final rings = geometry['coordinates'] as List;
          final ring = rings[0] as List;

          // 64 segments = 65 vertices including closed last vertex
          expect(ring.length, equals(65));
          expect(ring.first[0], equals(ring.last[0]));
          expect(ring.first[1], equals(ring.last[1]));

          final props = feature['properties'] as Map<String, dynamic>;
          expect(props['name'], equals('Depot Warehouse Radius'));
          expect(props['geomType'], equals('CIRCLE'));
          expect(props['radiusMeters'], equals(1500.0));
          expect(props['color'], equals('#4CAF50'));
          expect(props['strokeWidth'], equals(2.5));
        },
      );

      test(
        'TC-GJB-12: Transforms LineString geofence into GeoJSON LineString with fillOpacity 0.0',
        () {
          const polylineGeofence = GeofenceModel(
            id: 301,
            name: 'Main Delivery Corridor',
            area:
                'LINESTRING (-6.2000 106.8100, -6.2100 106.8200, -6.2200 106.8300)',
            attributes: {'color': '#E91E63', 'polylineDistance': 50.0},
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            polylineGeofence,
          ]);

          final features = geojson['features'] as List;
          expect(features.length, equals(1));

          final feature = features[0] as Map<String, dynamic>;
          expect(feature['id'], equals(301));

          final geometry = feature['geometry'] as Map<String, dynamic>;
          expect(geometry['type'], equals('LineString'));

          final coords = geometry['coordinates'] as List;
          expect(coords.length, equals(3));
          expect(coords[0][0], closeTo(106.8100, 1e-6));
          expect(coords[0][1], closeTo(-6.2000, 1e-6));
          expect(coords[1][0], closeTo(106.8200, 1e-6));
          expect(coords[1][1], closeTo(-6.2100, 1e-6));
          expect(coords[2][0], closeTo(106.8300, 1e-6));
          expect(coords[2][1], closeTo(-6.2200, 1e-6));

          final props = feature['properties'] as Map<String, dynamic>;
          expect(props['geomType'], equals('LINESTRING'));
          expect(props['polylineDistance'], equals(50.0));
          expect(props['fillOpacity'], equals(0.0));
        },
      );

      test(
        'TC-GJB-13: Handles mixed collections preserving order and skipping invalid items',
        () {
          const validCircle = GeofenceModel(
            id: 1,
            name: 'Circle Area',
            area: 'CIRCLE (-6.20 106.80, 500)',
          );
          const invalidItem = GeofenceModel(
            id: 2,
            name: 'Corrupted Area',
            area: '',
          );
          const validPoly = GeofenceModel(
            id: 3,
            name: 'Poly Area',
            area:
                'POLYGON ((-6.30 106.90, -6.31 106.91, -6.32 106.90, -6.30 106.90))',
          );

          final geojson = GeofenceGeoJsonBuilder.buildFeatureCollection([
            validCircle,
            invalidItem,
            validPoly,
          ]);

          final features = geojson['features'] as List;
          expect(features.length, equals(2));
          expect(features[0]['id'], equals(1));
          expect(features[1]['id'], equals(3));
        },
      );
    });
  });
}
