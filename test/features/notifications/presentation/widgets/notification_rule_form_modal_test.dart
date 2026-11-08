import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notification_rule_form_modal.dart';
import '../providers/notification_settings_provider_test.dart';

Widget createTestModal({
  required NotificationSettingsProvider provider,
  NotificationModel? initialNotification,
}) {
  return ChangeNotifierProvider<NotificationSettingsProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(
        body: NotificationRuleFormModal(
          initialNotification: initialNotification,
        ),
      ),
    ),
  );
}

void main() {
  late MockNotificationsRepository repository;
  late NotificationSettingsProvider provider;

  Future<void> pumpModal(
    WidgetTester tester, {
    NotificationModel? initialNotification,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      createTestModal(
        provider: provider,
        initialNotification: initialNotification,
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = MockNotificationsRepository();
    provider = NotificationSettingsProvider(repository: repository);
    repository.mockTypes = [
      const NotificationTypeModel(type: 'alarm', name: 'Alarm / Darurat'),
      const NotificationTypeModel(type: 'deviceOnline', name: 'Unit Online'),
      const NotificationTypeModel(type: 'overspeed', name: 'Batas Kecepatan'),
    ];
    repository.mockNotificators = [
      const NotificationTypeModel(type: 'web', name: 'Web / In-App'),
      const NotificationTypeModel(type: 'firebase', name: 'Push FCM'),
      const NotificationTypeModel(type: 'mail', name: 'Email'),
      const NotificationTypeModel(type: 'sms', name: 'SMS'),
      const NotificationTypeModel(type: 'telegram', name: 'Telegram'),
    ];
  });

  group('NotificationRuleFormModal Widget Tests', () {
    testWidgets(
      'TC-NRF-01: renders form with default initial fields (alarm, web, firebase)',
      (tester) async {
        await provider.fetchSettings();

        await pumpModal(tester);

        expect(find.text('Tambah Aturan Notifikasi'), findsOneWidget);
        expect(find.text('Alarm / Darurat'), findsOneWidget);
        expect(find.byKey(const Key('channel_chip_web')), findsOneWidget);
        expect(find.byKey(const Key('channel_chip_firebase')), findsOneWidget);
        expect(find.text('Simpan'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-NRF-02: populates form with initialNotification data in edit mode',
      (tester) async {
        await provider.fetchSettings();

        const existing = NotificationModel(
          id: 42,
          type: 'deviceOnline',
          description: 'Notifikasi Armada Online',
          always: true,
          notificators: 'mail,sms',
        );

        await pumpModal(tester, initialNotification: existing);

        expect(find.text('Ubah Aturan Notifikasi'), findsOneWidget);
        expect(find.text('Notifikasi Armada Online'), findsOneWidget);
        expect(find.text('Perbarui'), findsOneWidget);

        final switchFinder = find.byKey(
          const Key('notification_form_always_switch'),
        );
        expect(switchFinder, findsOneWidget);
        final switchWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(switchWidget.value, isTrue);
      },
    );

    testWidgets('TC-NRF-03: selecting alarm type displays alarm chip filters', (
      tester,
    ) async {
      await provider.fetchSettings();

      await pumpModal(tester);

      expect(find.text('Pilihan Jenis Alarm'), findsOneWidget);
      expect(find.byKey(const Key('alarm_chip_sos')), findsOneWidget);
      expect(find.byKey(const Key('alarm_chip_overspeed')), findsOneWidget);
      expect(find.byKey(const Key('alarm_chip_tamper')), findsOneWidget);

      // Tap SOS chip
      await tester.tap(find.byKey(const Key('alarm_chip_sos')));
      await tester.pump();

      final filterChip = tester.widget<FilterChip>(
        find.byKey(const Key('alarm_chip_sos')),
      );
      expect(filterChip.selected, isTrue);
    });

    testWidgets(
      'TC-NRF-04: deselecting all channels displays validation error on submit',
      (tester) async {
        await provider.fetchSettings();

        await pumpModal(tester);

        // Deselect default 'web' and 'firebase'
        await tester.tap(find.byKey(const Key('channel_chip_web')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('channel_chip_firebase')));
        await tester.pump();

        // Tap Simpan
        await tester.tap(
          find.byKey(const Key('notification_form_save_button')),
        );
        await tester.pump();

        expect(
          find.text('Wajib memilih minimal satu kanal pengiriman.'),
          findsOneWidget,
        );
        expect(repository.createCount, 0);
      },
    );

    testWidgets(
      'TC-NRF-05: submitting valid form invokes createNotification and saves',
      (tester) async {
        await provider.fetchSettings();

        await pumpModal(tester);

        // Enter description
        await tester.enterText(
          find.byKey(const Key('notification_form_description_input')),
          'Aturan Darurat VIP',
        );

        // Tap Simpan
        await tester.tap(
          find.byKey(const Key('notification_form_save_button')),
        );
        await tester.pump();

        expect(repository.createCount, 1);
        expect(provider.notifications.length, 1);
      },
    );

    testWidgets(
      'TC-NRF-06: tapping Uji Kanal Terpilih triggers testNotificator for selected channels',
      (tester) async {
        await provider.fetchSettings();

        await pumpModal(tester);

        // Default has web and firebase selected
        await tester.tap(
          find.byKey(const Key('notification_form_test_channels_button')),
        );
        await tester.pump();

        // Should test channels
        expect(repository.testChannelCount, 2);
        expect(
          find.textContaining('Uji coba berhasil terkirim'),
          findsOneWidget,
        );
      },
    );
  });
}
