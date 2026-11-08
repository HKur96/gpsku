import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/presentation/map/route_geojson_builder.dart';

void main() {
  group('RouteGeoJsonBuilder Unit Tests', () {
    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    test(
      'TC-GEO-01: Converts valid coordinates into RFC 7946 LineString with [lng, lat] ordering',
      () {
        final positions = [
          PositionModel(
            id: 1,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2088,
            longitude: 106.8456,
          ),
          PositionModel(
            id: 2,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2100,
            longitude: 106.8500,
          ),
        ];

        final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
          positions,
        );

        expect(geojson['type'], 'FeatureCollection');
        final features = geojson['features'] as List;
        expect(features.length, 1);

        final feature = features.first as Map<String, dynamic>;
        expect(feature['type'], 'Feature');

        final geometry = feature['geometry'] as Map<String, dynamic>;
        expect(geometry['type'], 'LineString');

        final coordinates = geometry['coordinates'] as List;
        expect(coordinates.length, 2);

        // Strict RFC 7946 GeoJSON: [longitude, latitude]
        expect(coordinates[0], [106.8456, -6.2088]);
        expect(coordinates[1], [106.8500, -6.2100]);
      },
    );

    test(
      'TC-GEO-02: Returns empty FeatureCollection when positions list is empty',
      () {
        final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
          [],
        );

        expect(geojson['type'], 'FeatureCollection');
        final features = geojson['features'] as List;
        expect(features, isEmpty);
      },
    );

    test(
      'TC-GEO-03: Returns empty FeatureCollection when single valid coordinate exists (prevents LineString crash)',
      () {
        final positions = [
          PositionModel(
            id: 1,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2088,
            longitude: 106.8456,
          ),
        ];

        final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
          positions,
        );

        expect(geojson['type'], 'FeatureCollection');
        final features = geojson['features'] as List;
        expect(features, isEmpty);
      },
    );

    test(
      'TC-GEO-04: Filters out (0.0, 0.0) Null Island and out-of-range coordinates',
      () {
        final positions = [
          PositionModel(
            id: 1,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: 0.0,
            longitude: 0.0, // Should be filtered
          ),
          PositionModel(
            id: 2,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2088,
            longitude: 106.8456, // Valid
          ),
          PositionModel(
            id: 3,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: 95.0, // Invalid latitude
            longitude: 106.8500,
          ),
          PositionModel(
            id: 4,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2100,
            longitude: 106.8500, // Valid
          ),
        ];

        final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
          positions,
        );
        final features = geojson['features'] as List;
        expect(features.length, 1);

        final geometry = features.first['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List;
        expect(coordinates.length, 2);
        expect(coordinates[0], [106.8456, -6.2088]);
        expect(coordinates[1], [106.8500, -6.2100]);
      },
    );

    test(
      'TC-GEO-05: extractValidCoordinates returns unmodifiable List<LatLng>',
      () {
        final positions = [
          PositionModel(
            id: 1,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.2088,
            longitude: 106.8456,
          ),
        ];

        final valid = RouteGeoJsonBuilder.extractValidCoordinates(positions);
        expect(valid.length, 1);
        expect(valid.first.latitude, closeTo(-6.2088, 0.0001));
        expect(valid.first.longitude, closeTo(106.8456, 0.0001));
        expect(
          () => (valid as dynamic).add(valid.first),
          throwsUnsupportedError,
        );
      },
    );

    test('TC-GEO-06: Passes custom properties into Feature', () {
      final positions = [
        PositionModel(
          id: 1,
          deviceId: 42,
          serverTime: tTime,
          fixTime: tTime,
          latitude: -6.2,
          longitude: 106.8,
        ),
        PositionModel(
          id: 2,
          deviceId: 42,
          serverTime: tTime,
          fixTime: tTime,
          latitude: -6.3,
          longitude: 106.9,
        ),
      ];

      final geojson = RouteGeoJsonBuilder.buildLineStringFeatureCollection(
        positions,
        properties: {'stroke': '#1E88E5', 'deviceId': 42},
      );

      final feature =
          (geojson['features'] as List).first as Map<String, dynamic>;
      expect(feature['properties'], {'stroke': '#1E88E5', 'deviceId': 42});
    });
  });
}
