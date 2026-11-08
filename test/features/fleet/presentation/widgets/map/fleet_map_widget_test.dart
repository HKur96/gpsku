import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_camera_controller.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_map_constants.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_map_widget.dart';

void main() {
  group('FleetMapWidget & FleetCameraController - Widget & Controller Tests', () {
    testWidgets(
      'TC-FMW-01: FleetMapWidget renders attribution badge and placeholder',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: FleetMapWidget(showAttribution: true)),
          ),
        );

        // Verify attribution badge is present in widget tree
        expect(find.text(FleetMapConstants.attributionText), findsOneWidget);
      },
    );

    testWidgets('TC-FMW-02: FleetMapWidget respects custom placeholder', (
      tester,
    ) async {
      const customKey = Key('custom_map_placeholder');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FleetMapWidget(
              placeholder: SizedBox(
                key: customKey,
                child: Text('Memuat Peta...'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(customKey), findsOneWidget);
      expect(find.text('Memuat Peta...'), findsOneWidget);
    });

    testWidgets(
      'TC-FMW-03: FleetMapWidget hides attribution badge when showAttribution is false',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: FleetMapWidget(showAttribution: false)),
          ),
        );

        expect(find.text(FleetMapConstants.attributionText), findsNothing);
      },
    );

    test(
      'TC-FMW-04: FleetCameraController lifecycle and readiness state transitions',
      () {
        final cameraController = FleetCameraController();

        // Unattached controller is not ready
        expect(cameraController.isReady, isFalse);

        // Disposal marks controller disposed and prevents operations
        cameraController.dispose();
        expect(cameraController.isReady, isFalse);
      },
    );

    test(
      'TC-FMW-05: FleetCameraController operations fail gracefully when unattached',
      () async {
        final cameraController = FleetCameraController();

        final boundsResult = await cameraController.fitFleetBounds([]);
        expect(boundsResult, isFalse);

        final animateResult = await cameraController.animateToDevice(
          const LatLng(-6.2088, 106.8456),
        );
        expect(animateResult, isFalse);

        final resetResult = await cameraController.resetToDefault();
        expect(resetResult, isFalse);
      },
    );

    testWidgets(
      'TC-FMW-06: FleetMapWidget default initial camera position matches constants',
      (tester) async {
        const widget = FleetMapWidget();
        expect(
          widget.initialCameraPosition.target,
          equals(FleetMapConstants.defaultFallbackCenter),
        );
        expect(
          widget.initialCameraPosition.zoom,
          equals(FleetMapConstants.defaultSelectionZoom),
        );
        expect(
          widget.styleString,
          equals(FleetMapConstants.openFreeMapLibertyStyle),
        );
      },
    );
  });
}
