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
import 'package:gpsku/features/notifications/presentation/widgets/emergency_alert_banner.dart';
import 'package:provider/provider.dart';

class MockTraccarWebSocketService extends TraccarWebSocketService {
  MockTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());
}

Widget createTestWidget({
  required NotificationsProvider notifProvider,
  LiveFleetProvider? fleetProvider,
  void Function(int deviceId)? onCenterDevice,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationsProvider>.value(value: notifProvider),
      if (fleetProvider != null)
        ChangeNotifierProvider<LiveFleetProvider>.value(value: fleetProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: EmergencyAlertBanner(onCenterDevice: onCenterDevice),
      ),
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

  group('EmergencyAlertBanner Widget Tests', () {
    testWidgets(
      'TC-EAB-01: renders nothing when activeEmergencyEvent is null',
      (tester) async {
        await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));

        expect(find.byKey(const Key('emergency_alert_banner')), findsNothing);
        expect(find.text('SOS DARURAT'), findsNothing);
      },
    );

    testWidgets(
      'TC-EAB-02: renders red banner with SOS details and vehicle name',
      (tester) async {
        final fleetProvider = LiveFleetProvider(webSocketService: mockWs);
        fleetProvider.setInitialFleetData(
          initialDevices: [
            const DeviceModel(
              id: 42,
              uniqueId: 'TRK-42',
              name: 'Truk Tronton B 9999 XYZ',
            ),
          ],
          initialPositions: const [],
        );

        // Ingest critical SOS event
        eventStreamService.ingestEvents([
          EventModel(
            id: 101,
            type: 'alarm',
            deviceId: 42,
            eventTime: DateTime(2026, 11, 8, 14, 30, 0),
            attributes: const {
              'alarm': 'sos',
              'message': 'Driver pressed panic button',
            },
          ),
        ]);

        await tester.pumpWidget(
          createTestWidget(
            notifProvider: notifProvider,
            fleetProvider: fleetProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('emergency_alert_banner')), findsOneWidget);
        expect(find.text('SOS DARURAT'), findsOneWidget);
        expect(find.textContaining('Truk Tronton B 9999 XYZ'), findsOneWidget);
        expect(find.text('Driver pressed panic button'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(
          find.byKey(const Key('emergency_banner_mute_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('emergency_banner_center_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-EAB-03: tapping Senyapkan mutes siren and updates button text',
      (tester) async {
        eventStreamService.ingestEvents([
          const EventModel(
            id: 102,
            type: 'alarm',
            deviceId: 10,
            attributes: {'alarm': 'sos'},
          ),
        ]);

        await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
        await tester.pumpAndSettle();

        expect(alarmAudioService.isPlaying, isTrue);
        expect(find.text('Senyapkan'), findsOneWidget);

        await tester.tap(find.byKey(const Key('emergency_banner_mute_button')));
        await tester.pumpAndSettle();

        expect(alarmAudioService.isPlaying, isFalse);
        expect(alarmAudioService.isMuted, isTrue);
        expect(find.text('Tersennyap'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-EAB-04: tapping Pusatkan triggers onCenterDevice callback',
      (tester) async {
        int? centeredDeviceId;

        eventStreamService.ingestEvents([
          const EventModel(
            id: 103,
            type: 'alarm',
            deviceId: 77,
            attributes: {'alarm': 'tamper'},
          ),
        ]);

        await tester.pumpWidget(
          createTestWidget(
            notifProvider: notifProvider,
            onCenterDevice: (id) => centeredDeviceId = id,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('emergency_banner_center_button')),
        );
        await tester.pump();

        expect(centeredDeviceId, 77);
      },
    );

    testWidgets('TC-EAB-05: tapping X dismisses banner and mutes audio siren', (
      tester,
    ) async {
      eventStreamService.ingestEvents([
        const EventModel(
          id: 104,
          type: 'alarm',
          deviceId: 15,
          attributes: {'alarm': 'sos'},
        ),
      ]);

      await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency_alert_banner')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('emergency_banner_dismiss_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency_alert_banner')), findsNothing);
      expect(notifProvider.activeEmergencyEvent, isNull);
      expect(alarmAudioService.isPlaying, isFalse);
    });

    testWidgets(
      'TC-EAB-06: maintains responsiveness without RenderFlex overflow on small screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        eventStreamService.ingestEvents([
          const EventModel(
            id: 105,
            type: 'alarm',
            deviceId: 12,
            attributes: {
              'alarm': 'overspeed',
              'message': 'Kendaraan melaju 135 km/jam di Tol Cipali',
            },
          ),
        ]);

        await tester.pumpWidget(createTestWidget(notifProvider: notifProvider));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('emergency_alert_banner')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
