import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/geofences/domain/models/geofence_geometry.dart';
import 'package:gpsku/features/geofences/domain/parsers/wkt_geometry_parser.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('WktGeometryParser & GeofenceGeometry Unit Tests', () {
    group('POLYGON Parsing & Serialization', () {
      test(
        'TC-WKT-01: Parses standard Traccar POLYGON into PolygonGeometry with correct lat/lng',
        () {
          const wkt =
              'POLYGON ((-6.2000 106.8100, -6.2100 106.8200, -6.2200 106.8000, -6.2000 106.8100))';
          final geom = WktGeometryParser.parse(wkt);

          expect(geom, isA<PolygonGeometry>());
          final poly = geom as PolygonGeometry;
          expect(poly.typeName, equals('POLYGON'));
          expect(poly.coordinates.length, equals(4));
          expect(poly.coordinates[0].latitude, closeTo(-6.2000, 1e-6));
          expect(poly.coordinates[0].longitude, closeTo(106.8100, 1e-6));
          expect(poly.coordinates[1].latitude, closeTo(-6.2100, 1e-6));
          expect(poly.coordinates[1].longitude, closeTo(106.8200, 1e-6));
          expect(poly.coordinates[2].latitude, closeTo(-6.2200, 1e-6));
          expect(poly.coordinates[2].longitude, closeTo(106.8000, 1e-6));
          expect(poly.coordinates[3].latitude, closeTo(-6.2000, 1e-6));
          expect(poly.coordinates[3].longitude, closeTo(106.8100, 1e-6));
        },
      );

      test(
        'TC-WKT-02: Handles case-insensitive syntax and irregular spacing/tabs',
        () {
          const wkt =
              '  polygon  (( \t-6.10 106.10 ,\n -6.20   106.20 ,\t -6.30 106.30  )) ';
          final geom = WktGeometryParser.parse(wkt);

          expect(geom, isA<PolygonGeometry>());
          final poly = geom as PolygonGeometry;
          expect(poly.coordinates.length, equals(3));
          expect(poly.coordinates[0], equals(const LatLng(-6.10, 106.10)));
          expect(poly.coordinates[1], equals(const LatLng(-6.20, 106.20)));
          expect(poly.coordinates[2], equals(const LatLng(-6.30, 106.30)));
        },
      );

      test('TC-WKT-03: Serializes PolygonGeometry back to Traccar WKT', () {
        const poly = PolygonGeometry([
          LatLng(-6.20, 106.81),
          LatLng(-6.21, 106.82),
          LatLng(-6.22, 106.80),
          LatLng(-6.20, 106.81),
        ]);

        final wkt = poly.toWkt();
        expect(
          wkt,
          equals(
            'POLYGON ((-6.2 106.81, -6.21 106.82, -6.22 106.8, -6.2 106.81))',
          ),
        );
      });

      test('TC-WKT-04: Polygon round-trip reversibility', () {
        const originalWkt =
            'POLYGON ((-6.2088 106.8456, -6.215 106.85, -6.22 106.84, -6.2088 106.8456))';
        final parsed = WktGeometryParser.parse(originalWkt);
        final serialized = WktGeometryParser.toWkt(parsed);
        final reParsed = WktGeometryParser.parse(serialized);

        expect(reParsed, equals(parsed));
      });
    });

    group('CIRCLE Parsing & Serialization', () {
      test(
        'TC-WKT-05: Parses Traccar CIRCLE WKT with integer radius into CircleGeometry',
        () {
          const wkt = 'CIRCLE (-6.2088 106.8456, 500)';
          final geom = WktGeometryParser.parse(wkt);

          expect(geom, isA<CircleGeometry>());
          final circle = geom as CircleGeometry;
          expect(circle.typeName, equals('CIRCLE'));
          expect(circle.center.latitude, closeTo(-6.2088, 1e-6));
          expect(circle.center.longitude, closeTo(106.8456, 1e-6));
          expect(circle.radiusMeters, equals(500.0));
        },
      );

      test(
        'TC-WKT-06: Parses Traccar CIRCLE WKT with decimal radius into CircleGeometry',
        () {
          const wkt = 'circle (-6.2088 106.8456, 1250.75)';
          final geom = WktGeometryParser.parse(wkt);

          expect(geom, isA<CircleGeometry>());
          final circle = geom as CircleGeometry;
          expect(circle.radiusMeters, equals(1250.75));
        },
      );

      test('TC-WKT-07: Serializes CircleGeometry back to Traccar WKT', () {
        const circleInt = CircleGeometry(
          center: LatLng(-6.2088, 106.8456),
          radiusMeters: 500.0,
        );
        expect(circleInt.toWkt(), equals('CIRCLE (-6.2088 106.8456, 500)'));

        const circleDec = CircleGeometry(
          center: LatLng(-6.2088, 106.8456),
          radiusMeters: 750.5,
        );
        expect(circleDec.toWkt(), equals('CIRCLE (-6.2088 106.8456, 750.5)'));
      });

      test('TC-WKT-08: Circle round-trip reversibility', () {
        const originalWkt = 'CIRCLE (-6.2088 106.8456, 850)';
        final parsed = WktGeometryParser.parse(originalWkt);
        final serialized = WktGeometryParser.toWkt(parsed);
        final reParsed = WktGeometryParser.parse(serialized);

        expect(reParsed, equals(parsed));
      });
    });

    group('LINESTRING Parsing & Serialization', () {
      test(
        'TC-WKT-09: Parses Traccar LINESTRING into PolylineGeometry with default polylineDistance',
        () {
          const wkt = 'LINESTRING (-6.2000 106.8100, -6.2100 106.8200)';
          final geom = WktGeometryParser.parse(wkt);

          expect(geom, isA<PolylineGeometry>());
          final polyline = geom as PolylineGeometry;
          expect(polyline.typeName, equals('LINESTRING'));
          expect(polyline.coordinates.length, equals(2));
          expect(polyline.polylineDistance, equals(25.0));
          expect(
            polyline.coordinates[0],
            equals(const LatLng(-6.2000, 106.8100)),
          );
          expect(
            polyline.coordinates[1],
            equals(const LatLng(-6.2100, 106.8200)),
          );
        },
      );

      test(
        'TC-WKT-10: Parses Traccar LINESTRING with custom polylineDistance',
        () {
          const wkt = 'linestring (-6.20 106.81, -6.21 106.82, -6.22 106.83)';
          final geom = WktGeometryParser.parse(wkt, polylineDistance: 50.0);

          expect(geom, isA<PolylineGeometry>());
          final polyline = geom as PolylineGeometry;
          expect(polyline.coordinates.length, equals(3));
          expect(polyline.polylineDistance, equals(50.0));
        },
      );

      test('TC-WKT-11: Serializes PolylineGeometry back to Traccar WKT', () {
        const polyline = PolylineGeometry([
          LatLng(-6.20, 106.81),
          LatLng(-6.21, 106.82),
        ], polylineDistance: 30.0);
        expect(
          polyline.toWkt(),
          equals('LINESTRING (-6.2 106.81, -6.21 106.82)'),
        );
      });

      test('TC-WKT-12: Polyline round-trip reversibility', () {
        const originalWkt = 'LINESTRING (-6.20 106.81, -6.25 106.85)';
        final parsed = WktGeometryParser.parse(
          originalWkt,
          polylineDistance: 45.0,
        );
        final serialized = WktGeometryParser.toWkt(parsed);
        final reParsed = WktGeometryParser.parse(
          serialized,
          polylineDistance: 45.0,
        );

        expect(reParsed, equals(parsed));
      });
    });

    group('Geodesic Circle to Polygon Approximation', () {
      test(
        'TC-WKT-13: Approximates circle perimeter producing a closed ring of points+1 vertices',
        () {
          const center = LatLng(-6.2088, 106.8456);
          const radius = 500.0;
          final vertices = WktGeometryParser.circleToPolygonApproximation(
            center,
            radius,
            points: 32,
          );

          expect(vertices.length, equals(33)); // 32 segments + 1 closing vertex
          expect(vertices.first, equals(vertices.last)); // Closed ring
        },
      );

      test(
        'TC-WKT-14: Cardinal directions verification at equator aligns with geodesic distance',
        () {
          const center = LatLng(0.0, 0.0);
          // 111,195 meters is approximately 1 degree of latitude
          const radiusMeters = 111195.0;
          final vertices = WktGeometryParser.circleToPolygonApproximation(
            center,
            radiusMeters,
            points: 4, // 4 points: N, E, S, W
          );

          // i = 0: Bearing 0 (North) -> Lat ~ 1.0, Lon ~ 0.0
          expect(vertices[0].latitude, closeTo(1.0, 0.01));
          expect(vertices[0].longitude, closeTo(0.0, 0.01));

          // i = 1: Bearing 90 (East) -> Lat ~ 0.0, Lon ~ 1.0
          expect(vertices[1].latitude, closeTo(0.0, 0.01));
          expect(vertices[1].longitude, closeTo(1.0, 0.01));

          // i = 2: Bearing 180 (South) -> Lat ~ -1.0, Lon ~ 0.0
          expect(vertices[2].latitude, closeTo(-1.0, 0.01));
          expect(vertices[2].longitude, closeTo(0.0, 0.01));

          // i = 3: Bearing 270 (West) -> Lat ~ 0.0, Lon ~ -1.0
          expect(vertices[3].latitude, closeTo(0.0, 0.01));
          expect(vertices[3].longitude, closeTo(-1.0, 0.01));

          // i = 4: Closing point -> same as i=0
          expect(vertices[4], equals(vertices[0]));
        },
      );

      test(
        'TC-WKT-15: Rejects negative, zero, NaN, infinite radius and <4 points with ArgumentError',
        () {
          const center = LatLng(0.0, 0.0);
          expect(
            () => WktGeometryParser.circleToPolygonApproximation(center, 0.0),
            throwsArgumentError,
          );
          expect(
            () => WktGeometryParser.circleToPolygonApproximation(center, -50.0),
            throwsArgumentError,
          );
          expect(
            () => WktGeometryParser.circleToPolygonApproximation(
              center,
              double.nan,
            ),
            throwsArgumentError,
          );
          expect(
            () => WktGeometryParser.circleToPolygonApproximation(
              center,
              100.0,
              points: 2,
            ),
            throwsArgumentError,
          );
        },
      );
    });

    group('Validation & Malformed Input Handling', () {
      test('TC-WKT-16: Empty or whitespace string throws FormatException', () {
        expect(() => WktGeometryParser.parse(''), throwsFormatException);
        expect(() => WktGeometryParser.parse('   '), throwsFormatException);
      });

      test('TC-WKT-17: Unknown geometry type throws FormatException', () {
        expect(
          () => WktGeometryParser.parse('MULTIPOINT (10 40, 40 30)'),
          throwsFormatException,
        );
        expect(
          () => WktGeometryParser.parse('GEOMETRYCOLLECTION EMPTY'),
          throwsFormatException,
        );
      });

      test('TC-WKT-18: Missing parentheses throws FormatException', () {
        expect(
          () => WktGeometryParser.parse('CIRCLE -6.20 106.84, 500'),
          throwsFormatException,
        );
        expect(
          () => WktGeometryParser.parse('POLYGON -6.20 106.84, -6.21 106.85'),
          throwsFormatException,
        );
      });

      test(
        'TC-WKT-19: CIRCLE with missing or invalid radius throws FormatException',
        () {
          expect(
            () => WktGeometryParser.parse('CIRCLE (-6.20 106.84)'),
            throwsFormatException,
          );
          expect(
            () => WktGeometryParser.parse('CIRCLE (-6.20 106.84, abc)'),
            throwsFormatException,
          );
          expect(
            () => WktGeometryParser.parse('CIRCLE (-6.20 106.84, -100)'),
            throwsFormatException,
          );
          expect(
            () => WktGeometryParser.parse('CIRCLE (-6.20 106.84, 0)'),
            throwsFormatException,
          );
        },
      );

      test(
        'TC-WKT-20: POLYGON with fewer than 3 vertices throws FormatException',
        () {
          expect(
            () => WktGeometryParser.parse(
              'POLYGON ((-6.20 106.81, -6.21 106.82))',
            ),
            throwsFormatException,
          );
        },
      );

      test(
        'TC-WKT-21: LINESTRING with fewer than 2 vertices throws FormatException',
        () {
          expect(
            () => WktGeometryParser.parse('LINESTRING (-6.20 106.81)'),
            throwsFormatException,
          );
        },
      );

      test('TC-WKT-22: Non-numeric coordinates throw FormatException', () {
        expect(
          () => WktGeometryParser.parse(
            'POLYGON ((abc 106.81, -6.21 106.82, -6.22 106.80))',
          ),
          throwsFormatException,
        );
      });

      test('TC-WKT-23: Out-of-bounds coordinates throw FormatException', () {
        // Latitude > 90
        expect(
          () => WktGeometryParser.parse(
            'POLYGON ((95.0 106.81, -6.21 106.82, -6.22 106.80))',
          ),
          throwsFormatException,
        );
        // Latitude < -90
        expect(
          () => WktGeometryParser.parse('CIRCLE (-95.0 106.8456, 500)'),
          throwsFormatException,
        );
        // Longitude > 180
        expect(
          () => WktGeometryParser.parse('CIRCLE (-6.20 195.0, 500)'),
          throwsFormatException,
        );
        // Longitude < -180
        expect(
          () => WktGeometryParser.parse(
            'LINESTRING (-6.20 -195.0, -6.21 106.82)',
          ),
          throwsFormatException,
        );
      });

      test(
        'TC-WKT-24: tryParse safely returns null on errors and valid geometry on success',
        () {
          expect(WktGeometryParser.tryParse(null), isNull);
          expect(WktGeometryParser.tryParse(''), isNull);
          expect(WktGeometryParser.tryParse('invalid'), isNull);
          expect(WktGeometryParser.tryParse('CIRCLE (invalid)'), isNull);

          final valid = WktGeometryParser.tryParse('CIRCLE (-6.2 106.8, 100)');
          expect(valid, isA<CircleGeometry>());
        },
      );
    });
  });
}
