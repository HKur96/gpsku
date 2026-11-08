import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';
import 'package:gpsku/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notification_rule_form_modal.dart';
import '../providers/notification_settings_provider_test.dart';

Widget createTestScreen({required NotificationSettingsProvider provider}) {
  return ChangeNotifierProvider<NotificationSettingsProvider>.value(
    value: provider,
    child: const MaterialApp(home: NotificationSettingsScreen()),
  );
}

void main() {
  late MockNotificationsRepository repository;
  late NotificationSettingsProvider provider;

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
    ];
  });

  group('NotificationSettingsScreen Widget Tests', () {
    testWidgets(
      'TC-NSS-01: renders loading indicator while fetching settings',
      (tester) async {
        final completer = Completer<void>();
        repository.pendingGetNotificationsCompleter = completer;

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pump();

        expect(
          find.byKey(const Key('notification_settings_loading_indicator')),
          findsOneWidget,
        );

        completer.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-NSS-02: renders error message and retry button on fetch failure',
      (tester) async {
        repository.failureToReturn = const ServerFailure(
          'Koneksi server gagal 500',
        );

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        expect(find.text('Gagal Memuat Pengaturan Notifikasi'), findsOneWidget);
        expect(find.textContaining('Koneksi server gagal 500'), findsOneWidget);
        expect(
          find.byKey(const Key('notification_settings_retry_button')),
          findsOneWidget,
        );

        // Clear error and tap retry
        repository.failureToReturn = null;
        repository.mockNotifications = [
          const NotificationModel(id: 1, type: 'alarm', notificators: 'web'),
        ];
        await tester.tap(
          find.byKey(const Key('notification_settings_retry_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gagal Memuat Pengaturan Notifikasi'), findsNothing);
        expect(find.text('Alarm / Darurat'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-NSS-03: renders empty state when no notification rules exist',
      (tester) async {
        repository.mockNotifications = [];

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notification_settings_empty_state')),
          findsOneWidget,
        );
        expect(find.text('Belum Ada Aturan Notifikasi'), findsOneWidget);
        expect(
          find.byKey(const Key('notification_settings_create_first_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-NSS-04: renders list of notification rules with semantic titles and channel chips',
      (tester) async {
        repository.mockNotifications = [
          const NotificationModel(
            id: 101,
            type: 'alarm',
            description: 'Alarm Keamanan Armada',
            always: true,
            notificators: 'web,firebase',
            attributes: {'alarms': 'sos,overspeed'},
          ),
          const NotificationModel(
            id: 102,
            type: 'deviceOnline',
            description: 'Unit Aktif',
            always: false,
            notificators: 'mail',
          ),
        ];

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notification_rule_card_101')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('notification_rule_card_102')),
          findsOneWidget,
        );
        expect(find.text('Alarm / Darurat'), findsOneWidget);
        expect(find.text('Alarm Keamanan Armada'), findsOneWidget);
        expect(find.text('Semua Armada'), findsOneWidget);
        expect(find.text('SOS'), findsOneWidget);
        expect(find.text('OVERSPEED'), findsOneWidget);
        expect(find.text('Web / In-App'), findsOneWidget);
        expect(find.text('Push FCM'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      },
    );

    testWidgets('TC-NSS-05: tapping FAB opens NotificationRuleFormModal', (
      tester,
    ) async {
      repository.mockNotifications = [];

      await tester.pumpWidget(createTestScreen(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification_settings_add_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Aturan Notifikasi'), findsOneWidget);
    });

    testWidgets(
      'TC-NSS-06: tapping Ubah on rule card opens NotificationRuleFormModal in edit mode',
      (tester) async {
        repository.mockNotifications = [
          const NotificationModel(
            id: 105,
            type: 'deviceOnline',
            description: 'Status Aktif',
            notificators: 'web',
          ),
        ];

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        // Open popup menu
        await tester.tap(find.byKey(const Key('notification_rule_menu_105')));
        await tester.pumpAndSettle();

        // Tap Ubah
        await tester.tap(find.text('Ubah'));
        await tester.pumpAndSettle();

        expect(find.text('Ubah Aturan Notifikasi'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(NotificationRuleFormModal),
            matching: find.text('Status Aktif'),
          ),
          findsOneWidget,
        );
        expect(find.text('Perbarui'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-NSS-07: tapping Hapus on rule card shows confirmation dialog and deletes on confirm',
      (tester) async {
        repository.mockNotifications = [
          const NotificationModel(id: 106, type: 'alarm', notificators: 'web'),
        ];

        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        // Open popup menu
        await tester.tap(find.byKey(const Key('notification_rule_menu_106')));
        await tester.pumpAndSettle();

        // Tap Hapus
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Aturan Notifikasi'), findsOneWidget);

        // Tap Confirm Hapus
        await tester.tap(
          find.byKey(const Key('notification_delete_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(repository.deleteCount, 1);
        expect(repository.lastDeletedId, 106);
        expect(
          find.text('Aturan notifikasi berhasil dihapus.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-NSS-08: tapping test channels AppBar action opens channel test bottom sheet',
      (tester) async {
        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('notification_settings_test_channels_action')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Uji Coba Kanal Notifikasi'), findsOneWidget);
        expect(
          find.byKey(const Key('test_channel_button_web')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('test_channel_button_firebase')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-NSS-09: testing a channel from test bottom sheet displays feedback SnackBar',
      (tester) async {
        await tester.pumpWidget(createTestScreen(provider: provider));
        await tester.pumpAndSettle();

        // Open channel test sheet
        await tester.tap(
          find.byKey(const Key('notification_settings_test_channels_action')),
        );
        await tester.pumpAndSettle();

        // Tap Kirim Tes on web
        await tester.tap(find.byKey(const Key('test_channel_button_web')));
        await tester.pump();

        expect(repository.testChannelCount, 1);
        expect(repository.lastTestedChannel, 'web');
        expect(
          find.text('Pesan uji coba berhasil terkirim ke Web / In-App.'),
          findsOneWidget,
        );
      },
    );
  });
}
