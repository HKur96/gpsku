import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_list_drawer.dart';
import '../providers/drivers_provider_test.dart';

void main() {
  late MockDriversRepository mockRepo;
  late DriversProvider provider;

  const tDriver1 = DriverModel(
    id: 1,
    name: 'Budi Santoso',
    uniqueId: 'RFID-1001',
    attributes: {'phone': '08123456789'},
  );
  const tDriver2 = DriverModel(
    id: 2,
    name: 'Agus Wijaya',
    uniqueId: 'IBUTTON-2002',
    attributes: {'phone': '08987654321'},
  );

  setUp(() {
    mockRepo = MockDriversRepository();
    provider = DriversProvider(repository: mockRepo);
  });

  Widget buildTestWidget({void Function(DriverModel)? onSelect}) {
    return MaterialApp(
      home: ChangeNotifierProvider<DriversProvider>.value(
        value: provider,
        child: Scaffold(body: DriverListDrawer(onDriverSelected: onSelect)),
      ),
    );
  }

  group('DriverListDrawer Widget Tests', () {
    testWidgets('TC-DLD-01: Renders header, count badge, and actions', (
      tester,
    ) async {
      mockRepo.mockDrivers = [tDriver1, tDriver2];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Daftar Pengemudi'), findsOneWidget);
      expect(find.text('2 Supir'), findsOneWidget);
      expect(find.byKey(const Key('driver_drawer_add_button')), findsOneWidget);
      expect(
        find.byKey(const Key('driver_drawer_close_button')),
        findsOneWidget,
      );
    });

    testWidgets('TC-DLD-02: Search text field filters drivers with debounce', (
      tester,
    ) async {
      mockRepo.mockDrivers = [tDriver1, tDriver2];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Agus Wijaya'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('driver_drawer_search_field')),
        'Agus',
      );
      await tester.pump(const Duration(milliseconds: 100)); // Still debouncing
      expect(find.text('Budi Santoso'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150)); // Debounce expired
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsNothing);
      expect(find.text('Agus Wijaya'), findsOneWidget);
    });

    testWidgets('TC-DLD-03: Displays empty state when no drivers found', (
      tester,
    ) async {
      mockRepo.mockDrivers = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('driver_drawer_empty')), findsOneWidget);
      expect(find.text('Belum ada supir terdaftar'), findsOneWidget);
    });

    testWidgets(
      'TC-DLD-04: Displays error message and retry button when fetch fails',
      (tester) async {
        mockRepo.failureToReturn = const ServerFailure(
          'Server driver error 500',
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('driver_drawer_error')), findsOneWidget);
        expect(find.text('Server driver error 500'), findsOneWidget);
        expect(
          find.byKey(const Key('driver_drawer_retry_button')),
          findsOneWidget,
        );

        // Click retry
        mockRepo.failureToReturn = null;
        mockRepo.mockDrivers = [tDriver1];
        await tester.tap(find.byKey(const Key('driver_drawer_retry_button')));
        await tester.pumpAndSettle();

        expect(find.text('Budi Santoso'), findsOneWidget);
      },
    );

    testWidgets('TC-DLD-05: Tapping driver card triggers onDriverSelected', (
      tester,
    ) async {
      mockRepo.mockDrivers = [tDriver1];
      DriverModel? selected;

      await tester.pumpWidget(
        buildTestWidget(onSelect: (driver) => selected = driver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Budi Santoso'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, equals(1));
    });

    testWidgets(
      'TC-DLD-06: Delete confirmation dialog cancels on Batal pressed',
      (tester) async {
        mockRepo.mockDrivers = [tDriver1];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Open menu
        await tester.tap(find.byKey(const Key('driver_item_menu_button_1')));
        await tester.pumpAndSettle();

        // Tap Hapus
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Dialog should be visible
        expect(find.text('Hapus Pengemudi'), findsOneWidget);
        expect(
          find.text(
            'Apakah Anda yakin ingin menghapus supir "Budi Santoso"? Tindakan ini tidak dapat dibatalkan.',
          ),
          findsOneWidget,
        );

        // Tap Batal
        await tester.tap(find.byKey(const Key('driver_delete_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Pengemudi'), findsNothing);
        expect(provider.drivers.length, equals(1));
      },
    );

    testWidgets(
      'TC-DLD-07: Delete confirmation dialog confirms and deletes driver',
      (tester) async {
        mockRepo.mockDrivers = [tDriver1];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('driver_item_menu_button_1')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('driver_delete_confirm_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Pengemudi "Budi Santoso" berhasil dihapus'),
          findsOneWidget,
        );
        expect(provider.drivers, isEmpty);
      },
    );
  });
}
