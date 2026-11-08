import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';

void main() {
  group('CameraCalculationHelper - Coordinate Validation Tests', () {
    test('TC-COORD-01: Valid geographic coordinates are accepted', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(-6.2088, 106.8456),
        isTrue,
      ); // Jakarta
      expect(
        CameraCalculationHelper.isValidCoordinate(51.5074, -0.1278),
        isTrue,
      ); // London
      expect(
        CameraCalculationHelper.isValidCoordinate(-33.8688, 151.2093),
        isTrue,
      ); // Sydney
      expect(
        CameraCalculationHelper.isValidCoordinate(40.7128, -74.0060),
        isTrue,
      ); // New York
    });

    test(
      'TC-COORD-02: Boundary valid coordinates (-90, 90, -180, 180) are accepted',
      () {
        expect(
          CameraCalculationHelper.isValidCoordinate(-90.0, 0.0),
          isTrue,
        ); // South Pole
        expect(
          CameraCalculationHelper.isValidCoordinate(90.0, 0.0),
          isTrue,
        ); // North Pole
        expect(
          CameraCalculationHelper.isValidCoordinate(0.0, -180.0),
          isTrue,
        ); // Date line West
        expect(
          CameraCalculationHelper.isValidCoordinate(0.0, 180.0),
          isTrue,
        ); // Date line East
        expect(
          CameraCalculationHelper.isValidCoordinate(-90.0, -180.0),
          isTrue,
        );
        expect(CameraCalculationHelper.isValidCoordinate(90.0, 180.0), isTrue);
      },
    );

    test('TC-COORD-03: Latitude below -90.0 is strictly rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(-90.0001, 106.8456),
        isFalse,
      );
      expect(CameraCalculationHelper.isValidCoordinate(-120.0, 0.0), isFalse);
      expect(CameraCalculationHelper.isValidCoordinate(-999.0, 10.0), isFalse);
    });

    test('TC-COORD-04: Latitude above 90.0 is strictly rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(90.0001, 106.8456),
        isFalse,
      );
      expect(CameraCalculationHelper.isValidCoordinate(120.0, 0.0), isFalse);
      expect(CameraCalculationHelper.isValidCoordinate(999.0, 10.0), isFalse);
    });

    test('TC-COORD-05: Longitude below -180.0 is strictly rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(-6.2088, -180.0001),
        isFalse,
      );
      expect(CameraCalculationHelper.isValidCoordinate(0.0, -185.0), isFalse);
      expect(CameraCalculationHelper.isValidCoordinate(0.0, -360.0), isFalse);
    });

    test('TC-COORD-06: Longitude above 180.0 is strictly rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(-6.2088, 180.0001),
        isFalse,
      );
      expect(CameraCalculationHelper.isValidCoordinate(0.0, 185.0), isFalse);
      expect(CameraCalculationHelper.isValidCoordinate(0.0, 360.0), isFalse);
    });

    test('TC-COORD-07: NaN and Infinite values are strictly rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(double.nan, 106.8456),
        isFalse,
      );
      expect(
        CameraCalculationHelper.isValidCoordinate(-6.2088, double.nan),
        isFalse,
      );
      expect(
        CameraCalculationHelper.isValidCoordinate(double.nan, double.nan),
        isFalse,
      );
      expect(
        CameraCalculationHelper.isValidCoordinate(double.infinity, 106.8456),
        isFalse,
      );
      expect(
        CameraCalculationHelper.isValidCoordinate(-6.2088, double.infinity),
        isFalse,
      );
      expect(
        CameraCalculationHelper.isValidCoordinate(double.negativeInfinity, 0.0),
        isFalse,
      );
    });

    test(
      'TC-COORD-08: The (0.0, 0.0) coordinate is strictly rejected while near-zero coordinates are preserved',
      () {
        // Exact (0, 0) and (-0, -0) Null Island coordinates rejected per Traccar FilterHandler.java
        expect(CameraCalculationHelper.isValidCoordinate(0.0, 0.0), isFalse);
        expect(CameraCalculationHelper.isValidCoordinate(-0.0, -0.0), isFalse);

        // Legitimate coordinates near equator & prime meridian must be preserved
        expect(
          CameraCalculationHelper.isValidCoordinate(0.0000005, 10.0),
          isTrue,
        ); // Equator proximity
        expect(
          CameraCalculationHelper.isValidCoordinate(10.0, 0.0000005),
          isTrue,
        ); // Prime meridian proximity
        expect(
          CameraCalculationHelper.isValidCoordinate(0.0000005, 0.0000005),
          isTrue,
        ); // Intersection proximity
        expect(
          CameraCalculationHelper.isValidCoordinate(0.00001, 106.8456),
          isTrue,
        );
        expect(
          CameraCalculationHelper.isValidCoordinate(51.5074, 0.00001),
          isTrue,
        );
      },
    );

    test('TC-COORD-09: Null coordinates are safely rejected', () {
      expect(
        CameraCalculationHelper.isValidCoordinate(null, 106.8456),
        isFalse,
      );
      expect(CameraCalculationHelper.isValidCoordinate(-6.2088, null), isFalse);
      expect(CameraCalculationHelper.isValidCoordinate(null, null), isFalse);
    });

    test(
      'TC-COORD-10: filterValidCoordinates filters mixed collection correctly',
      () {
        final input = [
          const LatLng(-6.2088, 106.8456), // Valid (Jakarta)
          const LatLng(0.0, 0.0), // Invalid (0, 0) Null Island
          LatLng(double.nan, 100.0), // Invalid (NaN)
          const LatLng(-7.2575, 112.7521), // Valid (Surabaya)
          LatLng(double.nan, double.nan), // Invalid (NaN)
        ];

        final filtered = CameraCalculationHelper.filterValidCoordinates(input);
        expect(filtered.length, equals(2));
        expect(filtered[0], equals(const LatLng(-6.2088, 106.8456)));
        expect(filtered[1], equals(const LatLng(-7.2575, 112.7521)));
      },
    );
  });
}
