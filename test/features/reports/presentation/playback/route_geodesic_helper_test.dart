import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/reports/presentation/playback/route_geodesic_helper.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('RouteGeodesicHelper Mathematical Unit Tests', () {
    test(
      'TC-GEO-MATH-01: distanceBetween computes great-circle distance accurately',
      () {
        // Monas (-6.1754, 106.8272) to Bundaran HI (-6.1950, 106.8230) ~2.22 km
        const p1 = LatLng(-6.1754, 106.8272);
        const p2 = LatLng(-6.1950, 106.8230);

        final distanceMeters = RouteGeodesicHelper.distanceBetween(p1, p2);

        expect(distanceMeters, greaterThan(2100.0));
        expect(distanceMeters, lessThan(2350.0));
      },
    );

    test('TC-GEO-MATH-02: distanceBetween identical points returns 0.0', () {
      const p = LatLng(-6.2088, 106.8456);
      expect(RouteGeodesicHelper.distanceBetween(p, p), 0.0);
    });

    test(
      'TC-GEO-MATH-03: calculateBearing computes cardinal bearings accurately',
      () {
        // Due North: from (0, 0) to (1, 0)
        final northBearing = RouteGeodesicHelper.calculateBearing(
          const LatLng(0.0, 0.0),
          const LatLng(1.0, 0.0),
        );
        expect(northBearing, closeTo(0.0, 0.1));

        // Due East: from (0, 0) to (0, 1)
        final eastBearing = RouteGeodesicHelper.calculateBearing(
          const LatLng(0.0, 0.0),
          const LatLng(0.0, 1.0),
        );
        expect(eastBearing, closeTo(90.0, 0.1));

        // Due South: from (0, 0) to (-1, 0)
        final southBearing = RouteGeodesicHelper.calculateBearing(
          const LatLng(0.0, 0.0),
          const LatLng(-1.0, 0.0),
        );
        expect(southBearing, closeTo(180.0, 0.1));

        // Due West: from (0, 0) to (0, -1)
        final westBearing = RouteGeodesicHelper.calculateBearing(
          const LatLng(0.0, 0.0),
          const LatLng(0.0, -1.0),
        );
        expect(westBearing, closeTo(270.0, 0.1));
      },
    );

    test(
      'TC-GEO-MATH-04: interpolateCoordinate computes exact intermediate positions',
      () {
        const p1 = LatLng(-6.0, 106.0);
        const p2 = LatLng(-6.4, 106.8);

        final start = RouteGeodesicHelper.interpolateCoordinate(p1, p2, 0.0);
        expect(start.latitude, closeTo(-6.0, 0.0001));
        expect(start.longitude, closeTo(106.0, 0.0001));

        final mid = RouteGeodesicHelper.interpolateCoordinate(p1, p2, 0.5);
        expect(mid.latitude, closeTo(-6.2, 0.0001));
        expect(mid.longitude, closeTo(106.4, 0.0001));

        final end = RouteGeodesicHelper.interpolateCoordinate(p1, p2, 1.0);
        expect(end.latitude, closeTo(-6.4, 0.0001));
        expect(end.longitude, closeTo(106.8, 0.0001));
      },
    );

    test(
      'TC-GEO-MATH-05: interpolateBearing smoothly handles 360/0 degree wrap-around',
      () {
        // 350 degrees to 10 degrees -> midpoint should be 0 (or 360), NOT 180
        final midHeading = RouteGeodesicHelper.interpolateBearing(
          350.0,
          10.0,
          0.5,
        );
        expect(midHeading == 0.0 || midHeading == 360.0, isTrue);

        // 10 degrees to 350 degrees -> midpoint should be 0
        final revHeading = RouteGeodesicHelper.interpolateBearing(
          10.0,
          350.0,
          0.5,
        );
        expect(revHeading == 0.0 || revHeading == 360.0, isTrue);

        // Standard within range: 90 to 180 -> midpoint is 135
        final normal = RouteGeodesicHelper.interpolateBearing(90.0, 180.0, 0.5);
        expect(normal, closeTo(135.0, 0.01));
      },
    );
  });
}
