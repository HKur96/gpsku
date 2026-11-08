import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/models/geofence_geometry.dart';

void main() {
  group('GeofenceModel Unit Tests', () {
    const samplePolygonWkt =
        'POLYGON ((-6.20 106.81, -6.21 106.82, -6.22 106.80, -6.20 106.81))';
    const sampleCircleWkt = 'CIRCLE (-6.2088 106.8456, 500)';
    const samplePolylineWkt =
        'LINESTRING (-6.20 106.81, -6.21 106.82, -6.22 106.83)';

    group('JSON Serialization & Deserialization', () {
      test(
        'TC-GFM-01: fromJson parses full Traccar geofence JSON correctly',
        () {
          final json = {
            'id': 12,
            'name': 'Gudang Logistik Cakung',
            'description': 'Pusat distribusi logistik utama',
            'area': samplePolygonWkt,
            'calendarId': 5,
            'attributes': {
              'color': '#1E88E5',
              'speedLimit': 20.0,
              'mapLineWidth': 3,
              'mapLineOpacity': 0.8,
            },
          };

          final model = GeofenceModel.fromJson(json);

          expect(model.id, equals(12));
          expect(model.name, equals('Gudang Logistik Cakung'));
          expect(model.description, equals('Pusat distribusi logistik utama'));
          expect(model.area, equals(samplePolygonWkt));
          expect(model.calendarId, equals(5));
          expect(model.color, equals('#1E88E5'));
          expect(model.speedLimit, equals(20.0));
          expect(model.mapLineWidth, equals(3));
          expect(model.mapLineOpacity, equals(0.8));
        },
      );

      test('TC-GFM-02: fromJson handles null/missing optional attributes', () {
        final json = {'id': 1, 'name': 'Area Terbuka', 'area': sampleCircleWkt};

        final model = GeofenceModel.fromJson(json);

        expect(model.id, equals(1));
        expect(model.name, equals('Area Terbuka'));
        expect(model.description, isNull);
        expect(model.calendarId, isNull);
        expect(model.attributes, isEmpty);
        expect(model.color, isNull);
        expect(model.speedLimit, isNull);
        expect(model.polylineDistance, isNull);
      });

      test('TC-GFM-03: toJson formats correctly for POST (id=0 omitted)', () {
        const model = GeofenceModel(
          id: 0,
          name: 'Zona Baru',
          area: sampleCircleWkt,
          description: 'Zona baru dibuat',
          attributes: {'color': '#4CAF50'},
        );

        final json = model.toJson();

        expect(json.containsKey('id'), isFalse);
        expect(json['name'], equals('Zona Baru'));
        expect(json['area'], equals(sampleCircleWkt));
        expect(json['description'], equals('Zona baru dibuat'));
        expect(json['attributes'], equals({'color': '#4CAF50'}));
      });

      test('TC-GFM-04: toJson formats correctly for PUT (id included)', () {
        const model = GeofenceModel(
          id: 99,
          name: 'Zona Update',
          area: sampleCircleWkt,
          calendarId: 3,
        );

        final json = model.toJson();

        expect(json['id'], equals(99));
        expect(json['name'], equals('Zona Update'));
        expect(json['calendarId'], equals(3));
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('attributes'), isFalse);
      });
    });

    group('Convenience Getters & Geometry Integration', () {
      test(
        'TC-GFM-05: Flags isPolygon, isCircle, isPolyline match area type',
        () {
          const poly = GeofenceModel(id: 1, name: 'P', area: samplePolygonWkt);
          expect(poly.isPolygon, isTrue);
          expect(poly.isCircle, isFalse);
          expect(poly.isPolyline, isFalse);

          const circ = GeofenceModel(id: 2, name: 'C', area: sampleCircleWkt);
          expect(circ.isPolygon, isFalse);
          expect(circ.isCircle, isTrue);
          expect(circ.isPolyline, isFalse);

          const line = GeofenceModel(id: 3, name: 'L', area: samplePolylineWkt);
          expect(line.isPolygon, isFalse);
          expect(line.isCircle, isFalse);
          expect(line.isPolyline, isTrue);
        },
      );

      test(
        'TC-GFM-06: geometry getter parses valid area into typed GeofenceGeometry',
        () {
          const poly = GeofenceModel(id: 1, name: 'P', area: samplePolygonWkt);
          expect(poly.geometry, isA<PolygonGeometry>());
          expect(
            (poly.geometry as PolygonGeometry).coordinates.length,
            equals(4),
          );

          const circ = GeofenceModel(id: 2, name: 'C', area: sampleCircleWkt);
          expect(circ.geometry, isA<CircleGeometry>());
          expect((circ.geometry as CircleGeometry).radiusMeters, equals(500.0));

          const line = GeofenceModel(
            id: 3,
            name: 'L',
            area: samplePolylineWkt,
            attributes: {'polylineDistance': 35.0},
          );
          expect(line.geometry, isA<PolylineGeometry>());
          expect(
            (line.geometry as PolylineGeometry).polylineDistance,
            equals(35.0),
          );
        },
      );

      test(
        'TC-GFM-07: tryGeometry returns null on invalid area without throwing',
        () {
          const invalid = GeofenceModel(
            id: 4,
            name: 'Bad',
            area: 'NOT_A_VALID_WKT',
          );

          expect(invalid.tryGeometry, isNull);
          expect(() => invalid.geometry, throwsFormatException);
        },
      );
    });

    group('Immutability, CopyWith & Value Equality', () {
      test('TC-GFM-08: copyWith overrides specified fields', () {
        const original = GeofenceModel(
          id: 10,
          name: 'Original',
          area: sampleCircleWkt,
          attributes: {'color': '#111111'},
        );

        final modified = original.copyWith(
          name: 'Modified Name',
          attributes: {'color': '#222222', 'speedLimit': 40.0},
        );

        expect(modified.id, equals(10));
        expect(modified.name, equals('Modified Name'));
        expect(modified.area, equals(sampleCircleWkt));
        expect(modified.color, equals('#222222'));
        expect(modified.speedLimit, equals(40.0));
      });

      test(
        'TC-GFM-09: Value equality and hashCode compare fields and attributes map',
        () {
          const g1 = GeofenceModel(
            id: 7,
            name: 'Geofence #7',
            area: samplePolygonWkt,
            attributes: {'color': '#FF0000'},
          );

          const g2 = GeofenceModel(
            id: 7,
            name: 'Geofence #7',
            area: samplePolygonWkt,
            attributes: {'color': '#FF0000'},
          );

          const g3 = GeofenceModel(
            id: 7,
            name: 'Geofence #7',
            area: samplePolygonWkt,
            attributes: {'color': '#00FF00'}, // Different color
          );

          expect(g1, equals(g2));
          expect(g1.hashCode, equals(g2.hashCode));
          expect(g1, isNot(equals(g3)));
        },
      );
    });
  });
}
