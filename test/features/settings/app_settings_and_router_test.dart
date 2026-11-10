import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/routing/app_router.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/domain/repositories/auth_repository.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/auth/presentation/screens/login_screen.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';
import 'package:gpsku/features/emulator/domain/repositories/telemetry_emulator_repository.dart';
import 'package:gpsku/features/emulator/presentation/providers/telemetry_emulator_provider.dart';
import 'package:gpsku/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';
import 'package:gpsku/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:gpsku/features/settings/presentation/screens/app_settings_screen.dart';

class _SettingsMockAuthRepository implements AuthRepository {
  UserModel? mockUser;

  _SettingsMockAuthRepository(this.mockUser);

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async {
    if (mockUser != null) return Right(mockUser!);
    return const Left(AuthFailure('Unauthenticated'));
  }

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async =>
      const Right((email: null, password: null, rememberMe: false));

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async {
    if (mockUser != null) return Right(mockUser!);
    return const Left(AuthFailure('Invalid'));
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);
}

class _SettingsMockEmulatorRepo implements TelemetryEmulatorRepository {
  @override
  Future<Either<Failure, bool>> probePort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async => const Right(true);

  @override
  Future<Either<Failure, bool>> sendTelemetry({
    required TelemetryPacketModel packet,
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async => const Right(true);
}

class _SettingsMockNotificationsRepo implements NotificationsRepository {
  @override
  Future<Either<Failure, NotificationModel>> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async => Right(notification);

  @override
  Future<Either<Failure, void>> deleteNotification(
    int id, {
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  }) async => const Right([]);

  @override
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificationTypes({
    CancelToken? cancelToken,
  }) async => const Right([]);

  @override
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  }) async => const Right([]);

  @override
  Future<Either<Failure, UserModel>> registerNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  }) async => Right(currentUser);

  @override
  Future<Either<Failure, void>> testAllNotificationChannels({
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, UserModel>> unregisterNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  }) async => Right(currentUser);

  @override
  Future<Either<Failure, NotificationModel>> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async => Right(notification);
}

class _FakeWsService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();

  _FakeWsService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => WebSocketConnectionState.connected;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
    super.dispose();
  }
}

void main() {
  group('AppSettingsScreen & AppRouter Developer Authorization Tests', () {
    testWidgets(
      'TC-SET-01: Developer Options section is visible for authenticated active administrator (!readonly)',
      (tester) async {
        final auth = AuthProvider(
          authRepository: _SettingsMockAuthRepository(
            const UserModel(
              id: 1,
              name: 'Super Admin',
              email: 'admin@gpsku.id',
              administrator: true,
              readonly: false,
            ),
          ),
        );
        await auth.checkInitialAuth();
        final emulator = TelemetryEmulatorProvider(
          repository: _SettingsMockEmulatorRepo(),
          authProvider: auth,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppConfig>.value(
                value: const AppConfig(baseUrl: 'https://gps.domainanda.com'),
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: emulator,
              ),
            ],
            child: const MaterialApp(home: AppSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings_notifications_tile')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings_developer_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings_open_emulator_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings_activate_map_pick_button')),
          findsOneWidget,
        );
        expect(
          find.textContaining('HTTPS Proxy: POST https://gps.domainanda.com/'),
          findsOneWidget,
        );

        emulator.dispose();
        auth.dispose();
      },
    );

    testWidgets(
      'TC-SET-02: Developer Options section is strictly HIDDEN for non-admin, readonly admin, disabled admin, and unauthenticated',
      (tester) async {
        for (final blockedUser in const [
          null,
          UserModel(
            id: 2,
            name: 'Operator Biasa',
            email: 'operator@gpsku.id',
            administrator: false,
          ),
          UserModel(
            id: 3,
            name: 'Admin ReadOnly',
            email: 'ro@gpsku.id',
            administrator: true,
            readonly: true,
          ),
          UserModel(
            id: 4,
            name: 'Admin Disabled',
            email: 'disabled@gpsku.id',
            administrator: true,
            disabled: true,
          ),
        ]) {
          final auth = AuthProvider(
            authRepository: _SettingsMockAuthRepository(blockedUser),
          );
          await auth.checkInitialAuth();
          final emulator = TelemetryEmulatorProvider(
            repository: _SettingsMockEmulatorRepo(),
            authProvider: auth,
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                  value: emulator,
                ),
              ],
              child: const MaterialApp(home: AppSettingsScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('settings_developer_section')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('settings_open_emulator_button')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('settings_activate_map_pick_button')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('settings_notifications_tile')),
            findsOneWidget,
          );

          emulator.dispose();
          auth.dispose();
        }
      },
    );

    testWidgets(
      'TC-SET-03: AppSettingsScreen reuses NotificationSettingsScreen via existing navigation',
      (tester) async {
        final auth = AuthProvider(
          authRepository: _SettingsMockAuthRepository(
            const UserModel(
              id: 2,
              name: 'Regular User',
              email: 'user@gpsku.id',
              administrator: false,
            ),
          ),
        );
        await auth.checkInitialAuth();
        final notifSettings = NotificationSettingsProvider(
          repository: _SettingsMockNotificationsRepo(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<NotificationSettingsProvider>.value(
                value: notifSettings,
              ),
            ],
            child: const MaterialApp(home: AppSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_notifications_tile')));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationSettingsScreen), findsOneWidget);

        notifSettings.dispose();
        auth.dispose();
      },
    );

    testWidgets(
      'TC-SET-04: AppRouter blocks unauthenticated /settings & /emulator -> /login, and blocks non-admin/readonly on developer routes',
      (tester) async {
        final authRepo = _SettingsMockAuthRepository(null);
        final auth = AuthProvider(authRepository: authRepo);
        await auth.checkInitialAuth(); // unauthenticated

        final ws = _FakeWsService();
        final liveFleet = LiveFleetProvider(webSocketService: ws);
        final emulator = TelemetryEmulatorProvider(
          repository: _SettingsMockEmulatorRepo(),
          authProvider: auth,
        );
        final router = AppRouter(authProvider: auth);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppConfig>.value(value: const AppConfig()),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
              Provider<TraccarWebSocketService>.value(value: ws),
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: emulator,
              ),
            ],
            child: MaterialApp.router(routerConfig: router.router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Unauthenticated navigating to /settings or /emulator -> /login
        router.router.go('/settings');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(LoginScreen), findsOneWidget);

        router.router.go('/emulator');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(LoginScreen), findsOneWidget);

        // Log in as readonly administrator -> /settings works without dev section, /emulator blocked to /settings
        authRepo.mockUser = const UserModel(
          id: 3,
          name: 'Readonly Admin',
          email: 'ro@gpsku.id',
          administrator: true,
          readonly: true,
        );
        await auth.checkInitialAuth();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        router.router.go('/emulator');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(TelemetryEmulatorSheet), findsNothing);
        expect(find.byType(AppSettingsScreen), findsOneWidget);
        expect(
          find.byKey(const Key('settings_developer_section')),
          findsNothing,
        );

        router.router.go('/settings/developer');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.byKey(const Key('settings_developer_section')),
          findsNothing,
        );

        // Upgrade session to active non-readonly administrator -> /settings/emulator succeeds
        authRepo.mockUser = const UserModel(
          id: 1,
          name: 'Active Admin',
          email: 'admin@gpsku.id',
          administrator: true,
          readonly: false,
        );
        await auth.checkInitialAuth();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        router.router.go('/settings/emulator');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(TelemetryEmulatorSheet), findsOneWidget);
        expect(
          find.byKey(const Key('emulator_send_single_fix_button')),
          findsOneWidget,
        );

        emulator.dispose();
        liveFleet.dispose();
        ws.dispose();
        auth.dispose();
      },
    );
  });
}
