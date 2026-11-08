import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_list_item.dart';

void main() {
  group('DriverListItem Widget Tests', () {
    const tDriver = DriverModel(
      id: 42,
      name: 'Budi Santoso',
      uniqueId: 'RFID-987654',
      attributes: {'phone': '081234567890', 'license': 'SIM-B2-UMUM'},
    );

    testWidgets('TC-DLI-01: Displays driver profile details and badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DriverListItem(driver: tDriver)),
        ),
      );

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // Initial avatar
      expect(find.text('RFID-987654'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('SIM-B2-UMUM'), findsOneWidget);
    });

    testWidgets('TC-DLI-02: Tapping card fires onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverListItem(driver: tDriver, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('driver_list_item_42')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('TC-DLI-03: Selecting Ubah from menu fires onEdit', (
      tester,
    ) async {
      bool editFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverListItem(
              driver: tDriver,
              onEdit: () => editFired = true,
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byKey(const Key('driver_item_menu_button_42')));
      await tester.pumpAndSettle();

      // Tap Ubah
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      expect(editFired, isTrue);
    });

    testWidgets('TC-DLI-04: Selecting Tautkan Armada fires onAssignDevices', (
      tester,
    ) async {
      bool assignFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverListItem(
              driver: tDriver,
              onAssignDevices: () => assignFired = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('driver_item_menu_button_42')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tautkan Armada'));
      await tester.pumpAndSettle();

      expect(assignFired, isTrue);
    });

    testWidgets('TC-DLI-05: Selecting Hapus fires onDelete', (tester) async {
      bool deleteFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverListItem(
              driver: tDriver,
              onDelete: () => deleteFired = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('driver_item_menu_button_42')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(deleteFired, isTrue);
    });
  });
}
