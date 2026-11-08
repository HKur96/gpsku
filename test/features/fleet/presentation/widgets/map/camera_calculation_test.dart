import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_map_constants.dart';

void main() {
  group('CameraCalculationHelper - Camera & Bounds Calculations Tests', () {
    test('TC-CAM-01: Empty coordinate collection returns null bounds', () {
      final bounds = CameraCalculationHelper.calculateBounds([]);
      expect(bounds, isNull);
    });

    test(
      'TC-CAM-02: Collection containing only invalid coordinates returns null bounds',
      () {
        final invalidList = [
          const LatLng(0.0, 0.0),
          LatLng(double.nan, 10.0),
          LatLng(double.nan, double.nan),
        ];
        final bounds = CameraCalculationHelper.calculateBounds(invalidList);
        expect(bounds, isNull);
      },
    );

    test('TC-CAM-03: Single valid coordinate returns degenerate bounds', () {
      final singlePoint = [const LatLng(-6.2088, 106.8456)];
      final bounds = CameraCalculationHelper.calculateBounds(singlePoint);

      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(-6.2088, 1e-5));
      expect(bounds.southwest.longitude, closeTo(106.8456, 1e-5));
      expect(bounds.northeast.latitude, closeTo(-6.2088, 1e-5));
      expect(bounds.northeast.longitude, closeTo(106.8456, 1e-5));
    });

    test(
      'TC-CAM-04: Multiple valid coordinates produce correct bounding box encompassing all points',
      () {
        final points = [
          const LatLng(-6.2088, 106.8456), // Jakarta: Lat -6.2088, Lng 106.8456
          const LatLng(-6.9175, 107.6191), // Bandung: Lat -6.9175, Lng 107.6191
          const LatLng(
            -7.2575,
            112.7521,
          ), // Surabaya: Lat -7.2575, Lng 112.7521
          const LatLng(-0.9471, 100.4172), // Padang: Lat -0.9471, Lng 100.4172
        ];

        final bounds = CameraCalculationHelper.calculateBounds(points);

        expect(bounds, isNotNull);
        // Min Lat = -7.2575 (Surabaya), Max Lat = -0.9471 (Padang)
        expect(bounds!.southwest.latitude, closeTo(-7.2575, 1e-5));
        expect(bounds.northeast.latitude, closeTo(-0.9471, 1e-5));
        // Min Lng = 100.4172 (Padang), Max Lng = 112.7521 (Surabaya)
        expect(bounds.southwest.longitude, closeTo(100.4172, 1e-5));
        expect(bounds.northeast.longitude, closeTo(112.7521, 1e-5));
      },
    );

    test(
      'TC-CAM-05: Invalid coordinates are excluded from bounds calculation',
      () {
        final points = [
          const LatLng(-6.2088, 106.8456), // Valid
          const LatLng(0.0, 0.0), // Invalid (should be ignored)
          LatLng(double.nan, double.nan), // Invalid (should be ignored)
          const LatLng(-6.9175, 107.6191), // Valid
        ];

        final bounds = CameraCalculationHelper.calculateBounds(points);
        expect(bounds, isNotNull);
        expect(bounds!.southwest.latitude, closeTo(-6.9175, 1e-5));
        expect(bounds.northeast.latitude, closeTo(-6.2088, 1e-5));
        expect(bounds.southwest.longitude, closeTo(106.8456, 1e-5));
        expect(bounds.northeast.longitude, closeTo(107.6191, 1e-5));
      },
    );

    test('TC-CAM-06: Viewport padding calculates 10% on large viewports', () {
      const largeViewport = Size(1000, 800);
      final padding = CameraCalculationHelper.calculateViewportPadding(
        viewportSize: largeViewport,
        paddingRatio: 0.10,
        minPadding: 48.0,
      );

      // min(1000, 800) * 0.10 = 80.0 > 48.0
      expect(padding.left, equals(80.0));
      expect(padding.top, equals(80.0));
      expect(padding.right, equals(80.0));
      expect(padding.bottom, equals(80.0));
    });

    test(
      'TC-CAM-07: Viewport padding clamps to minPadding on small viewports',
      () {
        const smallViewport = Size(360, 640);
        final padding = CameraCalculationHelper.calculateViewportPadding(
          viewportSize: smallViewport,
          paddingRatio: 0.10,
          minPadding: 48.0,
        );

        // min(360, 640) * 0.10 = 36.0 < 48.0 -> clamps to 48.0
        expect(padding.left, equals(48.0));
        expect(padding.top, equals(48.0));
        expect(padding.right, equals(48.0));
        expect(padding.bottom, equals(48.0));
      },
    );

    test('TC-CAM-08: Viewport padding handles invalid / zero sizes safely', () {
      const zeroViewport = Size(0, 0);
      final padding = CameraCalculationHelper.calculateViewportPadding(
        viewportSize: zeroViewport,
        minPadding: 48.0,
      );

      expect(padding.left, equals(48.0));
      expect(padding.right, equals(48.0));
    });

    test(
      'TC-CAM-09: Camera offset calculation shifts target southward for bottom sheet',
      () {
        const target = LatLng(-6.2088, 106.8456);
        const zoom = 10.0;
        const sheetHeight = 220.0;

        final offsetTarget = CameraCalculationHelper.calculateOffsetCenter(
          target: target,
          zoom: zoom,
          verticalOffsetPixels: sheetHeight,
        );

        // Shifting southward means latitude decreases (more negative in Southern hemisphere)
        expect(offsetTarget.latitude, lessThan(target.latitude));
        // Longitude remains identical
        expect(offsetTarget.longitude, equals(target.longitude));

        // Delta should be positive and realistic (~ 0.05 - 0.2 degrees)
        final delta = target.latitude - offsetTarget.latitude;
        expect(delta, greaterThan(0.0));
        expect(delta, lessThan(1.0));
      },
    );

    test(
      'TC-CAM-10: Camera offset with zero offset returns target unmodified',
      () {
        const target = LatLng(-6.2088, 106.8456);
        final offsetTarget = CameraCalculationHelper.calculateOffsetCenter(
          target: target,
          zoom: 10.0,
          verticalOffsetPixels: 0.0,
        );

        expect(offsetTarget.latitude, equals(target.latitude));
        expect(offsetTarget.longitude, equals(target.longitude));
      },
    );

    test(
      'TC-CAM-11: calculateTargetCamera returns fallback for empty fleet',
      () {
        final camera = CameraCalculationHelper.calculateTargetCamera(
          coordinates: [],
          fallbackCenter: FleetMapConstants.defaultFallbackCenter,
          fallbackZoom: FleetMapConstants.defaultEmptyFleetZoom,
        );

        expect(camera.target, equals(FleetMapConstants.defaultFallbackCenter));
        expect(camera.zoom, equals(FleetMapConstants.defaultEmptyFleetZoom));
      },
    );

    test(
      'TC-CAM-12: calculateTargetCamera returns target coordinate with selection zoom for 1 point',
      () {
        const point = LatLng(-6.2088, 106.8456);
        final camera = CameraCalculationHelper.calculateTargetCamera(
          coordinates: [point],
          defaultSelectionZoom: 10.0,
        );

        expect(camera.target, equals(point));
        expect(camera.zoom, equals(10.0));
      },
    );

    test(
      'TC-CAM-13: calculateTargetCamera calculates midpoint for multiple points',
      () {
        final points = [const LatLng(-6.0, 106.0), const LatLng(-8.0, 108.0)];
        final camera = CameraCalculationHelper.calculateTargetCamera(
          coordinates: points,
        );

        // Midpoint: Lat -7.0, Lng 107.0
        expect(camera.target.latitude, closeTo(-7.0, 1e-4));
        expect(camera.target.longitude, closeTo(107.0, 1e-4));
        expect(camera.zoom, equals(FleetMapConstants.defaultFleetOverviewZoom));
      },
    );

    test(
      'TC-CAM-14: Identical coordinates produce valid degenerate bounds',
      () {
        final points = [
          const LatLng(-6.2088, 106.8456),
          const LatLng(-6.2088, 106.8456),
        ];
        final bounds = CameraCalculationHelper.calculateBounds(points);

        expect(bounds, isNotNull);
        expect(bounds!.southwest.latitude, closeTo(-6.2088, 1e-5));
        expect(bounds.northeast.latitude, closeTo(-6.2088, 1e-5));
        expect(bounds.southwest.longitude, closeTo(106.8456, 1e-5));
        expect(bounds.northeast.longitude, closeTo(106.8456, 1e-5));
      },
    );

    test(
      'TC-CAM-15: Micro-separation coordinates (~1 meter apart) correctly bounded',
      () {
        final points = [
          const LatLng(-6.20880, 106.84560),
          const LatLng(-6.20881, 106.84561),
        ];
        final bounds = CameraCalculationHelper.calculateBounds(points);

        expect(bounds, isNotNull);
        expect(bounds!.southwest.latitude, closeTo(-6.20881, 1e-5));
        expect(bounds.northeast.latitude, closeTo(-6.20880, 1e-5));
        expect(bounds.southwest.longitude, closeTo(106.84560, 1e-5));
        expect(bounds.northeast.longitude, closeTo(106.84561, 1e-5));
      },
    );

    test(
      'TC-CAM-16: Coordinates near extreme North and South Poles bounded safely',
      () {
        final points = [
          const LatLng(-89.9, 0.0), // South pole vicinity
          const LatLng(89.9, 0.0), // North pole vicinity
        ];
        final bounds = CameraCalculationHelper.calculateBounds(points);

        expect(bounds, isNotNull);
        expect(bounds!.southwest.latitude, closeTo(-89.9, 1e-4));
        expect(bounds.northeast.latitude, closeTo(89.9, 1e-4));
        expect(bounds.southwest.longitude, closeTo(0.0, 1e-4));
        expect(bounds.northeast.longitude, closeTo(0.0, 1e-4));
      },
    );

    test(
      'TC-CAM-17: Intercontinental coordinates (Jakarta & London) bounded across continents',
      () {
        final points = [
          const LatLng(-6.2088, 106.8456), // Jakarta (SE Asia)
          const LatLng(51.5074, -0.1278), // London (Europe)
        ];
        final bounds = CameraCalculationHelper.calculateBounds(points);

        expect(bounds, isNotNull);
        expect(bounds!.southwest.latitude, closeTo(-6.2088, 1e-4));
        expect(bounds.northeast.latitude, closeTo(51.5074, 1e-4));
        expect(bounds.southwest.longitude, closeTo(-0.1278, 1e-4));
        expect(bounds.northeast.longitude, closeTo(106.8456, 1e-4));
      },
    );

    test(
      'TC-CAM-18: Points across International Date Line document standard Mercator span',
      () {
        // Point A in Fiji East (+179.0), Point B in Fiji West (-179.0)
        final points = [
          const LatLng(-16.0, 179.0),
          const LatLng(-16.0, -179.0),
        ];
        final bounds = CameraCalculationHelper.calculateBounds(points);

        // Standard Mercator bounds cut at +/- 180 degrees
        expect(bounds, isNotNull);
        expect(bounds!.southwest.longitude, closeTo(-179.0, 1e-4));
        expect(bounds.northeast.longitude, closeTo(179.0, 1e-4));
        // Total longitudinal span encompasses the Mercator projection plane
        final span = bounds.northeast.longitude - bounds.southwest.longitude;
        expect(span, closeTo(358.0, 1e-3));
      },
    );

    test(
      'TC-CAM-19: Southward offset accurately shifts camera target further South in Southern Hemisphere latitudes (Indonesia)',
      () {
        // Jakarta: lat -6.2088
        const jakarta = LatLng(-6.2088, 106.8456);
        final jakartaOffset = CameraCalculationHelper.calculateOffsetCenter(
          target: jakarta,
          zoom: 14.0,
          verticalOffsetPixels: 250.0,
        );
        // Target latitude must decrease (become more negative) so vehicle marker sits northward/higher on screen
        expect(jakartaOffset.latitude, lessThan(jakarta.latitude));
        expect(jakartaOffset.longitude, equals(jakarta.longitude));
        final jakartaDelta = jakarta.latitude - jakartaOffset.latitude;
        expect(jakartaDelta, greaterThan(0.005));
        expect(jakartaDelta, lessThan(0.02));

        // Surabaya: lat -7.2575
        const surabaya = LatLng(-7.2575, 112.7521);
        final surabayaOffset = CameraCalculationHelper.calculateOffsetCenter(
          target: surabaya,
          zoom: 14.0,
          verticalOffsetPixels: 250.0,
        );
        expect(surabayaOffset.latitude, lessThan(surabaya.latitude));
        expect(surabayaOffset.longitude, equals(surabaya.longitude));

        // Denpasar: lat -8.6705
        const denpasar = LatLng(-8.6705, 115.2126);
        final denpasarOffset = CameraCalculationHelper.calculateOffsetCenter(
          target: denpasar,
          zoom: 14.0,
          verticalOffsetPixels: 250.0,
        );
        expect(denpasarOffset.latitude, lessThan(denpasar.latitude));
        expect(denpasarOffset.longitude, equals(denpasar.longitude));
      },
    );

    test(
      'TC-CAM-20: Southward offset is strictly zero when verticalOffsetPixels <= 0',
      () {
        const target = LatLng(-6.2088, 106.8456);
        final zeroOffset = CameraCalculationHelper.calculateOffsetCenter(
          target: target,
          zoom: 14.0,
          verticalOffsetPixels: 0.0,
        );
        expect(zeroOffset.latitude, equals(target.latitude));
        expect(zeroOffset.longitude, equals(target.longitude));

        final negOffset = CameraCalculationHelper.calculateOffsetCenter(
          target: target,
          zoom: 14.0,
          verticalOffsetPixels: -50.0,
        );
        expect(negOffset.latitude, equals(target.latitude));
      },
    );
  });
}
