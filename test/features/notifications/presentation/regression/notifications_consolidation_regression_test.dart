import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/domain/repositories/auth_repository.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';
import 'package:gpsku/features/notifications/data/models/event_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/domain/helpers/fcm_token_merger.dart';
import 'package:gpsku/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:gpsku/features/notifications/domain/services/event_stream_service.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';
import 'package:gpsku/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:gpsku/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:gpsku/features/notifications/presentation/services/alarm_audio_service.dart';
import 'package:gpsku/features/notifications/presentation/widgets/emergency_alert_banner.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notification_list_item.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notification_rule_form_modal.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notifications_drawer.dart';
import '../providers/notification_settings_provider_test.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Fleet Manager',
    email: 'manager@gpsku.id',
    administrator: true,
  );
  bool logoutCalled = false;

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async => Right(mockUser!);

  @override
  Future<Either<Failure, void>> logout() async {
    logoutCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async =>
      Right(mockUser!);

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async =>
      const Right((email: null, password: null, rememberMe: false));

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);
}

class FakeWebSocketService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();
  bool disconnectCalled = false;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => WebSocketConnectionState.connected;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  void sendMessage(Map<String, dynamic> msg) => _msgController.add(msg);

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {
    disconnectCalled = true;
  }

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
    super.dispose();
  }
}

void main() {
  group(
    'Phase 8 Notifications, Alerts & Incident Management - Consolidation Regression Tests',
    () {
      late MockAuthRepository mockAuthRepo;
      late AuthProvider authProvider;
      late FakeWebSocketService fakeWs;
      late LiveFleetProvider liveFleet;
      late EventStreamService eventStreamService;
      late MockAudioPlayerAdapter mockAudioPlayer;
      late AlarmAudioService alarmAudioService;
      late NotificationsProvider notificationsProvider;
      late MockNotificationsRepository mockNotificationsRepo;
      late NotificationSettingsProvider settingsProvider;

      final tDevices = [
        const DeviceModel(
          id: 11,
          name: 'Truk Hino Dutro B 1111 AA',
          uniqueId: 'HINO-01',
          category: 'truck',
          status: 'online',
        ),
        const DeviceModel(
          id: 12,
          name: 'Truk Isuzu Giga B 2222 BB',
          uniqueId: 'ISUZU-02',
          category: 'truck',
          status: 'online',
        ),
      ];

      final tPositions = [
        PositionModel(
          id: 101,
          deviceId: 11,
          protocol: 'osmand',
          serverTime: DateTime.now(),
          deviceTime: DateTime.now(),
          fixTime: DateTime.now(),
          valid: true,
          latitude: -6.2000,
          longitude: 106.8166,
          altitude: 10.0,
          speed: 45.0,
          course: 90.0,
          attributes: const {},
        ),
      ];

      setUp(() async {
        mockAuthRepo = MockAuthRepository();
        authProvider = AuthProvider(authRepository: mockAuthRepo);
        authProvider.checkInitialAuth();

        fakeWs = FakeWebSocketService();
        liveFleet = LiveFleetProvider(
          webSocketService: fakeWs,
          coalescingWindow: const Duration(milliseconds: 10),
        );
        liveFleet.setInitialFleetData(
          initialDevices: tDevices,
          initialPositions: tPositions,
        );

        eventStreamService = EventStreamService(webSocketService: fakeWs);
        mockAudioPlayer = MockAudioPlayerAdapter();
        alarmAudioService = AlarmAudioService(adapter: mockAudioPlayer);
        notificationsProvider = NotificationsProvider(
          eventStreamService: eventStreamService,
          alarmAudioService: alarmAudioService,
        );

        mockNotificationsRepo = MockNotificationsRepository();
        mockNotificationsRepo.mockTypes = [
          const NotificationTypeModel(type: 'alarm', name: 'Alarm / Darurat'),
          const NotificationTypeModel(
            type: 'overspeed',
            name: 'Batas Kecepatan',
          ),
          const NotificationTypeModel(
            type: 'deviceOnline',
            name: 'Unit Online',
          ),
          const NotificationTypeModel(
            type: 'deviceOffline',
            name: 'Unit Offline',
          ),
        ];
        mockNotificationsRepo.mockNotificators = [
          const NotificationTypeModel(type: 'web', name: 'Web / In-App'),
          const NotificationTypeModel(type: 'firebase', name: 'Push FCM'),
          const NotificationTypeModel(type: 'mail', name: 'Email'),
          const NotificationTypeModel(type: 'sms', name: 'SMS'),
          const NotificationTypeModel(type: 'telegram', name: 'Telegram'),
        ];
        settingsProvider = NotificationSettingsProvider(
          repository: mockNotificationsRepo,
        );
      });

      tearDown(() {
        notificationsProvider.dispose();
        alarmAudioService.dispose();
        eventStreamService.dispose();
        liveFleet.dispose();
        fakeWs.dispose();
      });

      Widget buildTestApp() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            Provider<TraccarWebSocketService>.value(value: fakeWs),
            Provider<EventStreamService>.value(value: eventStreamService),
            ChangeNotifierProvider<AlarmAudioService>.value(
              value: alarmAudioService,
            ),
            ChangeNotifierProvider<NotificationsProvider>.value(
              value: notificationsProvider,
            ),
            ChangeNotifierProvider<NotificationSettingsProvider>.value(
              value: settingsProvider,
            ),
            Provider<NotificationsRepository>.value(
              value: mockNotificationsRepo,
            ),
          ],
          child: const MaterialApp(home: FleetShellScreen()),
        );
      }

      Future<void> pumpAndAdvance(
        WidgetTester tester, [
        int durationMs = 300,
      ]) async {
        await tester.pump();
        await tester.pump(Duration(milliseconds: durationMs));
      }

      testWidgets(
        'TC-NOTIF-REG-01: Full End-to-End Emergency SOS: Ingest WS -> EmergencyAlertBanner -> Loop Siren -> Mute',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          // 1. Ingest Emergency SOS Event
          eventStreamService.ingestEvents([
            const EventModel(
              id: 501,
              deviceId: 11,
              type: 'alarm',
              attributes: {'alarm': 'sos'},
            ),
          ]);
          await pumpAndAdvance(tester, 300);

          // 2. Verify EmergencyAlertBanner appears
          expect(find.byType(EmergencyAlertBanner), findsOneWidget);
          expect(
            find.byKey(const Key('emergency_alert_banner')),
            findsOneWidget,
          );
          expect(find.text('Truk Hino Dutro B 1111 AA'), findsOneWidget);
          expect(find.text('SOS DARURAT'), findsOneWidget);

          // 3. Verify Audio siren is playing in loop mode
          expect(alarmAudioService.isPlaying, isTrue);
          expect(mockAudioPlayer.isPlaying, isTrue);
          expect(mockAudioPlayer.lastPlayedAsset, 'audio/alarm.mp3');
          expect(mockAudioPlayer.lastLoop, isTrue);

          // 4. Tap "Senyapkan" button
          final muteBtnFinder = find.byKey(
            const Key('emergency_banner_mute_button'),
          );
          expect(muteBtnFinder, findsOneWidget);
          expect(find.text('Senyapkan'), findsOneWidget);
          await tester.tap(muteBtnFinder);
          await pumpAndAdvance(tester, 300);

          // 5. Verify Audio siren is muted and button reflects muted state
          expect(alarmAudioService.isPlaying, isFalse);
          expect(alarmAudioService.isMuted, isTrue);
          expect(mockAudioPlayer.isPlaying, isFalse);
          expect(find.text('Tersennyap'), findsOneWidget);
        },
      );

      testWidgets(
        'TC-NOTIF-REG-02: NotificationsDrawer Integration: Bell Badge -> Category Filters -> Mark All Read -> Clear All',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          // 1. Ingest 3 distinct telematics events across categories
          eventStreamService.ingestEvents([
            const EventModel(
              id: 601,
              deviceId: 11,
              type: 'alarm',
              attributes: {'alarm': 'overspeed'},
            ),
            const EventModel(id: 602, deviceId: 11, type: 'deviceOnline'),
            const EventModel(
              id: 603,
              deviceId: 12,
              type: 'geofenceEnter',
              attributes: {'geofenceId': 5},
            ),
          ]);
          await pumpAndAdvance(tester, 300);

          // 2. Verify bell icon has unread counter badge '3'
          expect(
            find.descendant(
              of: find.byKey(const Key('notifications_drawer_action_button')),
              matching: find.text('3'),
            ),
            findsOneWidget,
          );

          // 3. Open NotificationsDrawer via bell icon
          await tester.tap(
            find.byKey(const Key('notifications_drawer_action_button')),
          );
          await pumpAndAdvance(tester, 400);

          expect(find.byType(NotificationsDrawer), findsOneWidget);
          expect(find.text('Riwayat Notifikasi'), findsOneWidget);
          expect(find.text('3 Event • 3 Belum Dibaca'), findsOneWidget);
          expect(find.byType(NotificationListItem), findsNWidgets(3));

          // 4. Test Category Filter Chips
          // Tap 'Alarm / Darurat'
          await tester.tap(find.text('Alarm / Darurat'));
          await pumpAndAdvance(tester, 300);
          expect(find.byType(NotificationListItem), findsOneWidget);

          // Tap 'Status Unit'
          await tester.tap(find.text('Status Unit'));
          await pumpAndAdvance(tester, 300);
          expect(find.byType(NotificationListItem), findsOneWidget);

          // Tap 'Semua'
          await tester.tap(find.text('Semua'));
          await pumpAndAdvance(tester, 300);
          expect(find.byType(NotificationListItem), findsNWidgets(3));

          // 5. Tap "Tandai Sudah Dibaca"
          await tester.tap(
            find.byKey(const Key('notifications_mark_all_read_button')),
          );
          await pumpAndAdvance(tester, 300);
          expect(find.text('3 Event • 0 Belum Dibaca'), findsOneWidget);
          expect(notificationsProvider.unreadCount, 0);

          // 6. Tap "Hapus Riwayat"
          await tester.tap(
            find.byKey(const Key('notifications_clear_all_button')),
          );
          await pumpAndAdvance(tester, 300);
          expect(find.text('Tidak ada notifikasi saat ini'), findsOneWidget);
          expect(notificationsProvider.events.isEmpty, isTrue);
        },
      );

      testWidgets(
        'TC-NOTIF-REG-03: Rule Management & Delivery Channel Testing: Drawer -> Settings Screen -> Create Rule -> Channel Test',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          // 1. Open NotificationsDrawer
          await tester.tap(
            find.byKey(const Key('notifications_drawer_action_button')),
          );
          await pumpAndAdvance(tester, 400);

          // 2. Tap settings button in drawer header
          await tester.tap(
            find.byKey(const Key('notifications_drawer_settings_button')),
          );
          await pumpAndAdvance(tester, 400);

          // 3. Verify NotificationSettingsScreen opened
          expect(find.byType(NotificationSettingsScreen), findsOneWidget);
          expect(find.text('Pengaturan Notifikasi'), findsOneWidget);

          // 4. Open NotificationRuleFormModal via FAB
          await tester.tap(
            find.byKey(const Key('notification_settings_add_fab')),
          );
          await pumpAndAdvance(tester, 400);

          expect(find.byType(NotificationRuleFormModal), findsOneWidget);
          expect(find.text('Tambah Aturan Notifikasi'), findsOneWidget);

          // 5. Enter Description
          await tester.enterText(
            find.byKey(const Key('notification_form_description_input')),
            'Aturan Batas Kecepatan Tol',
          );

          // 6. Test selected delivery channels directly from modal
          await tester.tap(
            find.byKey(const Key('notification_form_test_channels_button')),
          );
          await pumpAndAdvance(tester, 300);
          expect(
            mockNotificationsRepo.testChannelCount,
            greaterThanOrEqualTo(1),
          );

          // 7. Save rule
          await tester.tap(
            find.byKey(const Key('notification_form_save_button')),
          );
          await pumpAndAdvance(tester, 400);

          // Verify rule persisted into provider and repository
          expect(mockNotificationsRepo.createCount, 1);
          expect(settingsProvider.notifications.length, 1);
          expect(find.text('Aturan Batas Kecepatan Tol'), findsOneWidget);

          // 8. Open Channel Test Bottom Sheet from screen AppBar
          await tester.tap(
            find.byKey(const Key('notification_settings_test_channels_action')),
          );
          await pumpAndAdvance(tester, 400);

          expect(find.text('Uji Coba Kanal Notifikasi'), findsOneWidget);

          // Tap Kirim Tes on web
          await tester.tap(find.byKey(const Key('test_channel_button_web')));
          await pumpAndAdvance(tester, 300);

          expect(mockNotificationsRepo.lastTestedChannel, 'web');
          expect(
            find.text('Pesan uji coba berhasil terkirim ke Web / In-App.'),
            findsOneWidget,
          );
        },
      );

      test(
        'TC-NOTIF-REG-04: Safe FCM Token Registration & Sliding Window Attribute Merging (Pure Dart)',
        () {
          // 1. Initial user attributes with custom telematics metadata
          final initialAttributes = <String, dynamic>{
            'speedLimit': 90.0,
            'driverId': 42,
            'company': 'PT Antigravity Logistics',
            'notificationTokens': 'token_alpha,token_beta',
          };

          // 2. Merge new token non-destructively
          final merged1 = FcmTokenMerger.mergeTokenIntoAttributes(
            initialAttributes,
            'token_gamma',
          );
          expect(merged1['speedLimit'], 90.0);
          expect(merged1['driverId'], 42);
          expect(merged1['company'], 'PT Antigravity Logistics');
          expect(
            merged1['notificationTokens'],
            'token_alpha,token_beta,token_gamma',
          );

          // 3. Re-registering existing token produces no duplicate
          final mergedDuplicate = FcmTokenMerger.mergeTokenIntoAttributes(
            merged1,
            'token_beta',
          );
          expect(
            mergedDuplicate['notificationTokens'],
            'token_alpha,token_beta,token_gamma',
          );

          // 4. Fill up to 10 tokens (exceeding window)
          var current = merged1;
          for (int i = 1; i <= 10; i++) {
            current = FcmTokenMerger.mergeTokenIntoAttributes(
              current,
              'device_token_$i',
              maxTokens: 10,
            );
          }

          final tokensList = FcmTokenMerger.parseTokens(
            current['notificationTokens'],
          );
          expect(tokensList.length, 10);
          // Newest token is present
          expect(tokensList.last, 'device_token_10');
          // Oldest tokens are evicted
          expect(tokensList.contains('token_alpha'), isFalse);

          // 5. Remove a token cleanly
          final afterRemoval = FcmTokenMerger.removeTokenFromAttributes(
            current,
            'device_token_10',
          );
          final remainingTokens = FcmTokenMerger.parseTokens(
            afterRemoval['notificationTokens'],
          );
          expect(remainingTokens.length, 9);
          expect(remainingTokens.contains('device_token_10'), isFalse);
          expect(afterRemoval['company'], 'PT Antigravity Logistics');
        },
      );

      test(
        'TC-NOTIF-REG-05: Flapping WebSocket Ingestion Deduplication: In-memory Ring-buffer Prevents Double Alerts',
        () async {
          final receivedEvents = <EventModel>[];
          final sub = eventStreamService.eventsBatchStream.listen((batch) {
            receivedEvents.addAll(batch);
          });
          addTearDown(() => sub.cancel());

          // 1. Send first event #777
          fakeWs.sendMessage({
            'events': [
              {
                'id': 777,
                'deviceId': 11,
                'type': 'alarm',
                'eventTime': '2026-11-09T08:30:00.000Z',
                'attributes': {'alarm': 'sos'},
              },
            ],
          });
          await Future.delayed(const Duration(milliseconds: 20));

          expect(eventStreamService.bufferedEvents.length, 1);
          expect(receivedEvents.length, 1);
          expect(receivedEvents.first.id, 777);

          // 2. Flapping network simulates rapid duplicate payloads of #777
          for (int i = 0; i < 5; i++) {
            fakeWs.sendMessage({
              'events': [
                {
                  'id': 777,
                  'deviceId': 11,
                  'type': 'alarm',
                  'eventTime': '2026-11-09T08:30:00.000Z',
                  'attributes': {'alarm': 'sos'},
                },
              ],
            });
          }
          await Future.delayed(const Duration(milliseconds: 20));

          // 3. Ring buffer and stream MUST NOT have duplicated event #777
          expect(eventStreamService.bufferedEvents.length, 1);
          expect(receivedEvents.length, 1);

          // 4. Distinct event #778 arrives
          fakeWs.sendMessage({
            'events': [
              {
                'id': 778,
                'deviceId': 11,
                'type': 'deviceOnline',
                'eventTime': '2026-11-09T08:31:00.000Z',
                'attributes': {},
              },
            ],
          });
          await Future.delayed(const Duration(milliseconds: 20));

          expect(eventStreamService.bufferedEvents.length, 2);
          expect(receivedEvents.length, 2);
          expect(receivedEvents.last.id, 778);
        },
      );

      testWidgets(
        'TC-NOTIF-REG-06: User Session Logout Cleanup: Disconnect WS, Clear Event Buffer, Stop Audio, Purge Settings Cache',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // Pre-populate state
          eventStreamService.ingestEvents([
            const EventModel(
              id: 888,
              deviceId: 11,
              type: 'alarm',
              attributes: {'alarm': 'sos'},
            ),
          ]);
          mockNotificationsRepo.mockNotifications = [
            const NotificationModel(
              id: 99,
              type: 'alarm',
              notificators: 'web,firebase',
            ),
          ];
          await settingsProvider.fetchSettings();

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 300);

          // Verify active state before logout
          expect(eventStreamService.bufferedEvents.isNotEmpty, isTrue);
          expect(notificationsProvider.activeEmergencyEvent, isNotNull);
          expect(alarmAudioService.isPlaying, isTrue);
          expect(settingsProvider.notifications.isNotEmpty, isTrue);

          // Tap Logout button on AppBar
          final logoutBtnFinder = find.byKey(
            const Key('fleet_app_bar_logout_button'),
          );
          expect(logoutBtnFinder, findsOneWidget);
          await tester.tap(logoutBtnFinder);
          await pumpAndAdvance(tester, 300);

          // Verify comprehensive state purge on logout
          expect(mockAuthRepo.logoutCalled, isTrue);
          expect(fakeWs.disconnectCalled, isTrue);
          expect(eventStreamService.bufferedEvents.isEmpty, isTrue);
          expect(notificationsProvider.events.isEmpty, isTrue);
          expect(notificationsProvider.activeEmergencyEvent, isNull);
          expect(alarmAudioService.isPlaying, isFalse);
          expect(settingsProvider.notifications.isEmpty, isTrue);
        },
      );
    },
  );
}
