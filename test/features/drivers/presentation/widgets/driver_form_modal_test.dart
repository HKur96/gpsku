import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_form_modal.dart';
import '../providers/drivers_provider_test.dart';

void main() {
  late MockDriversRepository mockRepo;
  late DriversProvider provider;

  const tExistingDriver = DriverModel(
    id: 10,
    name: 'Budi Santoso',
    uniqueId: 'RFID-1001',
    attributes: {'phone': '08123456789', 'license': 'SIM-B2'},
  );

  setUp(() {
    mockRepo = MockDriversRepository();
    provider = DriversProvider(repository: mockRepo);
  });

  Widget buildTestWidget({DriverModel? initialDriver}) {
    return MaterialApp(
      home: ChangeNotifierProvider<DriversProvider>.value(
        value: provider,
        child: Scaffold(body: DriverFormModal(initialDriver: initialDriver)),
      ),
    );
  }

  group('DriverFormModal Widget Tests', () {
    testWidgets('TC-DFM-01: Renders form input fields and buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tambah Pengemudi Baru'), findsOneWidget);
      expect(find.byKey(const Key('driver_form_name_field')), findsOneWidget);
      expect(
        find.byKey(const Key('driver_form_unique_id_field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('driver_form_phone_field')), findsOneWidget);
      expect(
        find.byKey(const Key('driver_form_license_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('driver_form_cancel_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('driver_form_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('TC-DFM-02: Validates required name and uniqueId fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Submit empty form
      await tester.tap(find.byKey(const Key('driver_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Nama pengemudi wajib diisi'), findsOneWidget);
      expect(find.text('Nomor kartu/RFID unik wajib diisi'), findsOneWidget);
      expect(provider.drivers, isEmpty);
    });

    testWidgets('TC-DFM-03: Submitting valid new driver creates record', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('driver_form_name_field')),
        'Dedi Kusnandar',
      );
      await tester.enterText(
        find.byKey(const Key('driver_form_unique_id_field')),
        'TAG-4455',
      );
      await tester.enterText(
        find.byKey(const Key('driver_form_phone_field')),
        '0811223344',
      );
      await tester.enterText(
        find.byKey(const Key('driver_form_license_field')),
        'SIM-A-UMUM',
      );

      await tester.tap(find.byKey(const Key('driver_form_submit_button')));
      await tester.pumpAndSettle();

      expect(provider.drivers.length, equals(1));
      expect(provider.drivers.first.name, equals('Dedi Kusnandar'));
      expect(provider.drivers.first.uniqueId, equals('TAG-4455'));
      expect(provider.drivers.first.phone, equals('0811223344'));
      expect(provider.drivers.first.license, equals('SIM-A-UMUM'));
    });

    testWidgets('TC-DFM-04: Prepopulates fields when editing existing driver', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialDriver: tExistingDriver));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Pengemudi'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('RFID-1001'), findsOneWidget);
      expect(find.text('08123456789'), findsOneWidget);
      expect(find.text('SIM-B2'), findsOneWidget);
    });

    testWidgets('TC-DFM-05: Submitting edited driver updates repository', (
      tester,
    ) async {
      mockRepo.mockDrivers = [tExistingDriver];
      await provider.fetchDrivers();

      await tester.pumpWidget(buildTestWidget(initialDriver: tExistingDriver));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('driver_form_name_field')),
        'Budi Santoso S.T.',
      );

      await tester.tap(find.byKey(const Key('driver_form_submit_button')));
      await tester.pumpAndSettle();

      expect(provider.drivers.first.name, equals('Budi Santoso S.T.'));
    });

    testWidgets('TC-DFM-06: Cancel button closes modal without submitting', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('driver_form_name_field')),
        'Draft Name',
      );
      await tester.tap(find.byKey(const Key('driver_form_cancel_button')));
      await tester.pumpAndSettle();

      expect(provider.drivers, isEmpty);
    });
  });
}
