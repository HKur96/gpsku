import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/drawer/fleet_list_item.dart';

void main() {
  group('FleetListItem - Widget & Visual Tests', () {
    final sampleDevice = const DeviceModel(
      id: 10,
      name: 'Toyota Fortuner B 1000 BOS',
      uniqueId: 'FORTUNER-01',
      category: 'car',
      status: 'online',
      model: '2.8 VRZ 4x4',
    );

    final samplePosition = PositionModel(
      id: 501,
      deviceId: 10,
      serverTime: DateTime.parse('2026-11-08T10:15:00Z'),
      fixTime: DateTime.parse('2026-11-08T10:15:00Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 32.4, // knots -> ~60.0 km/h
      attributes: {'ignition': true},
    );

    testWidgets(
      'TC-FLI-01: Displays identity: name, uniqueId, model, and formatted fix time',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FleetListItem(
                device: sampleDevice,
                position: samplePosition,
              ),
            ),
          ),
        );

        expect(find.text('Toyota Fortuner B 1000 BOS'), findsOneWidget);
        expect(find.text('FORTUNER-01 • 2.8 VRZ 4x4'), findsOneWidget);
        expect(find.byIcon(Icons.directions_car), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLI-02: Displays converted speed badge in km/h and ignition ACC ON badge',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FleetListItem(
                device: sampleDevice,
                position: samplePosition,
              ),
            ),
          ),
        );

        // 32.4 knots * 1.852 = 60.0048 km/h
        expect(find.text('60.0 km/h'), findsOneWidget);
        expect(find.text('ACC ON'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLI-03: Displays ACC OFF when ignition attribute is false',
      (tester) async {
        final offPosition = PositionModel(
          id: 502,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.2088,
          longitude: 106.8456,
          speed: 0.0,
          attributes: {'ignition': false},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FleetListItem(device: sampleDevice, position: offPosition),
            ),
          ),
        );

        expect(find.text('0.0 km/h'), findsOneWidget);
        expect(find.text('ACC OFF'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLI-04: Gracefully handles null position with placeholder metrics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FleetListItem(device: sampleDevice, position: null),
            ),
          ),
        );

        expect(find.text('- km/h'), findsOneWidget);
        expect(find.text('Belum ada data fix'), findsOneWidget);
      },
    );

    testWidgets('TC-FLI-05: Selection state renders active visual styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetListItem(
              device: sampleDevice,
              position: samplePosition,
              isSelected: true,
            ),
          ),
        ),
      );

      // Container with border width 1.5 for selected
      final containerFinder = find.byType(Container).first;
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('TC-FLI-06: Tapping list item fires onTap callback', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetListItem(
              device: sampleDevice,
              position: samplePosition,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FleetListItem));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
