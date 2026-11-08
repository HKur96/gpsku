import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/notifications/data/models/event_model.dart';
import 'package:gpsku/features/notifications/domain/services/event_stream_service.dart';
import 'package:gpsku/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:gpsku/features/notifications/presentation/services/alarm_audio_service.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notifications_drawer.dart';
import 'package:provider/provider.dart';

class MockTraccarWebSocketService extends TraccarWebSocketService {
  MockTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());
}

Widget createTestWidget({
  required NotificationsProvider notifProvider,
  LiveFleetProvider? fleetProvider,
  void Function(int deviceId)? onSelectDevice,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationsProvider>.value(value: notifProvider),
      if (fleetProvider != null)
        ChangeNotifierProvider<LiveFleetProvider>.value(value: fleetProvider),
    ],
    child: MaterialApp(
      home: Scaffold(body: NotificationsDrawer(onSelectDevice: onSelectDevice)),
    ),
  );
}

void main() {
  late MockTraccarWebSocketService mockWs;
  late EventStreamService eventStreamService;
  late MockAudioPlayerAdapter mockAudioAdapter;
  late AlarmAudioService alarmAudioService;
  late NotificationsProvider notifProvider;

  setUp(() {
    mockWs = MockTraccarWebSocketService();
    eventStreamService = EventStreamService(webSocketService: mockWs);
    mockAudioAdapter = MockAudioPlayerAdapter();
    alarmAudioService = AlarmAudioService(adapter: mockAudioAdapter);
    notifProvider = NotificationsProvider(
      eventStreamService: eventStreamService,
      alarmAudioService: alarmAudioService,
    );
  });

  tearDown(() {
    notifProvider.dispose();
    alarmAudioService.dispose();
    eventStreamService.dispose();
    mockWs.dispose();
  });

  group('NotificationsDrawer Widget Tests', () {
    testWidgets('TC-NDW-01: displays empty state when buffer has no events', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));

      expect(find.text('Riwayat Notifikasi'), findsOneWidget);
      expect(find.text('0 Event • 0 Belum Dibaca'), findsOneWidget);
      expect(find.text('Tidak ada notifikasi saat ini'), findsOneWidget);
    });

    testWidgets(
      'TC-NDW-02: renders list of events with unread count and badges',
      (tester) async {
        final fleetProvider = LiveFleetProvider(webSocketService: mockWs);
        fleetProvider.setInitialFleetData(
          initialDevices: [
            const DeviceModel(
              id: 10,
              uniqueId: 'AVZ-10',
              name: 'Toyota Avanza B 1234 CD',
            ),
            const DeviceModel(
              id: 20,
              uniqueId: 'HINO-20',
              name: 'Hino Dutro B 5678 EF',
            ),
          ],
          initialPositions: const [],
        );

        eventStreamService.ingestEvents([
          const EventModel(
            id: 1,
            type: 'alarm',
            deviceId: 10,
            attributes: {'alarm': 'sos'},
          ),
          const EventModel(id: 2, type: 'deviceMoving', deviceId: 20),
        ]);

        await tester.pumpWidget(
          createTestWidget(
            notifProvider: notifProvider,
            fleetProvider: fleetProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 Event • 2 Belum Dibaca'), findsOneWidget);
        expect(find.text('Peringatan Darurat SOS'), findsOneWidget);
        expect(find.text('Kendaraan Bergerak'), findsOneWidget);
        expect(find.text('Toyota Avanza B 1234 CD'), findsOneWidget);
        expect(find.text('Hino Dutro B 5678 EF'), findsOneWidget);
      },
    );

    testWidgets('TC-NDW-03: filter chips filter events by category', (
      tester,
    ) async {
      eventStreamService.ingestEvents([
        const EventModel(id: 1, type: 'alarm', deviceId: 10),
        const EventModel(id: 2, type: 'deviceMoving', deviceId: 10),
        const EventModel(id: 3, type: 'geofenceEnter', deviceId: 10),
      ]);

      await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_item_1')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_2')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_3')), findsOneWidget);

      // Filter by Alarm
      await tester.tap(find.text('Alarm / Darurat'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_item_1')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_2')), findsNothing);
      expect(find.byKey(const Key('notification_item_3')), findsNothing);

      // Filter by Geofence
      await tester.tap(find.text('Geofence'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_item_1')), findsNothing);
      expect(find.byKey(const Key('notification_item_3')), findsOneWidget);

      // Restore All
      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_item_1')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_2')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_3')), findsOneWidget);
    });

    testWidgets(
      'TC-NDW-04: markAllAsRead updates unread badge counter to zero',
      (tester) async {
        eventStreamService.ingestEvents([
          const EventModel(id: 1, type: 'deviceOnline', deviceId: 1),
          const EventModel(id: 2, type: 'deviceOffline', deviceId: 1),
        ]);

        await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
        await tester.pumpAndSettle();

        expect(notifProvider.unreadCount, 2);

        await tester.tap(
          find.byKey(const Key('notifications_mark_all_read_button')),
        );
        await tester.pumpAndSettle();

        expect(notifProvider.unreadCount, 0);
        expect(find.text('2 Event • 0 Belum Dibaca'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-NDW-05: clearAll empties the buffer and updates UI to empty state',
      (tester) async {
        eventStreamService.ingestEvents([
          const EventModel(id: 1, type: 'alarm', deviceId: 1),
        ]);

        await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('notification_item_1')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('notifications_clear_all_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('notification_item_1')), findsNothing);
        expect(find.text('Tidak ada notifikasi saat ini'), findsOneWidget);
        expect(notifProvider.events, isEmpty);
      },
    );

    testWidgets(
      'TC-NDW-06: tapping notification item selects device and marks item as read',
      (tester) async {
        int? selectedDevice;

        eventStreamService.ingestEvents([
          const EventModel(id: 10, type: 'deviceStopped', deviceId: 44),
        ]);

        await tester.pumpWidget(
          createTestWidget(
            notifProvider: notifProvider,
            onSelectDevice: (id) => selectedDevice = id,
          ),
        );
        await tester.pumpAndSettle();

        expect(notifProvider.unreadCount, 1);

        await tester.tap(find.byKey(const Key('notification_item_10')));
        await tester.pump();

        expect(selectedDevice, 44);
        expect(notifProvider.unreadCount, 0);
      },
    );

    testWidgets(
      'TC-NDW-07: NotificationsDrawer.show modal bottom sheet integration',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<NotificationsProvider>.value(
                value: notifProvider,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => NotificationsDrawer.show(ctx),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsDrawer), findsOneWidget);

        // Close modal
        await tester.tap(
          find.byKey(const Key('notifications_drawer_close_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsDrawer), findsNothing);
      },
    );
  });
}
