import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';
import 'package:gpsku/features/share/data/models/share_link_model.dart';
import 'package:gpsku/features/share/domain/repositories/share_repository.dart';
import 'package:gpsku/features/share/presentation/providers/share_provider.dart';
import 'package:gpsku/features/share/presentation/widgets/share_link_bottom_sheet.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Fleet Supervisor',
    email: 'supervisor@gpsku.id',
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

class MockShareRepository implements ShareRepository {
  ShareLinkModel? mockLinkToReturn;
  Failure? failureToReturn;

  int? lastDeviceId;
  int? lastGroupId;
  Duration? lastDuration;
  CancelToken? lastCancelToken;

  @override
  Future<Either<Failure, ShareLinkModel>> generateShareLink(
    int deviceId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastDuration = duration;
    lastCancelToken = cancelToken;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(
      mockLinkToReturn ??
          ShareLinkModel(
            deviceId: deviceId,
            token: 'mock_token_reg_123',
            expiration: DateTime.now().add(duration),
            shareUrl: 'https://demo.traccar.org/?token=mock_token_reg_123',
          ),
    );
  }

  @override
  Future<Either<Failure, ShareLinkModel>> generateGroupShareLink(
    int groupId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    lastGroupId = groupId;
    lastDuration = duration;
    lastCancelToken = cancelToken;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(
      mockLinkToReturn ??
          ShareLinkModel(
            deviceId: 0,
            groupId: groupId,
            token: 'mock_group_token_reg_456',
            expiration: DateTime.now().add(duration),
            shareUrl:
                'https://demo.traccar.org/?token=mock_group_token_reg_456',
          ),
    );
  }
}

void main() {
  group(
    'Phase 9.1 Public Share Link (Feature F-37) - Consolidation Regression Tests',
    () {
      late MockAuthRepository mockAuthRepo;
      late AuthProvider authProvider;
      late FakeWebSocketService fakeWs;
      late LiveFleetProvider liveFleet;
      late MockShareRepository mockShareRepo;
      late ShareProvider shareProvider;

      final tDevice = const DeviceModel(
        id: 77,
        name: 'Truk Tronton Logistik B 9999 XYZ',
        uniqueId: 'TRONTON-77',
        category: 'truck',
        status: 'online',
        model: 'Hino 500 Heavy Duty',
      );

      final tPosition = PositionModel(
        id: 7001,
        deviceId: 77,
        protocol: 'gt06',
        serverTime: DateTime.now(),
        deviceTime: DateTime.now(),
        fixTime: DateTime.now(),
        valid: true,
        latitude: -6.2088,
        longitude: 106.8456,
        altitude: 15.0,
        speed: 55.0,
        course: 90.0,
        address: 'Tol Jakarta-Cikampek KM 28',
        attributes: const {'ignition': true, 'odometer': 12500000.0},
      );

      setUp(() {
        mockAuthRepo = MockAuthRepository();
        authProvider = AuthProvider(authRepository: mockAuthRepo);
        authProvider.checkInitialAuth();

        fakeWs = FakeWebSocketService();
        liveFleet = LiveFleetProvider(
          webSocketService: fakeWs,
          coalescingWindow: const Duration(milliseconds: 10),
        );
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice],
          initialPositions: [tPosition],
        );

        mockShareRepo = MockShareRepository();
        shareProvider = ShareProvider(repository: mockShareRepo);
      });

      tearDown(() {
        shareProvider.dispose();
        liveFleet.dispose();
        fakeWs.dispose();
      });

      Widget buildTestApp() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            Provider<TraccarWebSocketService>.value(value: fakeWs),
            ChangeNotifierProvider<ShareProvider>.value(value: shareProvider),
            Provider<ShareRepository>.value(value: mockShareRepo),
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
        'TC-SHARE-REG-01: Full End-to-End Cycle: Shell -> Vehicle Sheet -> Share Sheet -> Preset 24h -> Generate Link -> Copy Clipboard & SnackBar',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // 1. Setup mock clipboard listener
          String? capturedClipboardText;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (methodCall) async {
              if (methodCall.method == 'Clipboard.setData') {
                capturedClipboardText =
                    (methodCall.arguments as Map)['text'] as String?;
              }
              return null;
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
          });

          // 2. Render FleetShellScreen
          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          // 3. User selects device -> VehicleDetailSheet appears
          liveFleet.selectDevice(tDevice.id);
          await pumpAndAdvance(tester, 300);

          expect(find.byType(VehicleDetailSheet), findsOneWidget);
          expect(
            find.text('Truk Tronton Logistik B 9999 XYZ'),
            findsAtLeastNWidgets(1),
          );

          // 4. Tap Quick Action button "Bagikan"
          final shareButtonFinder = find.byKey(
            const Key('vehicle_sheet_share_button'),
          );
          expect(shareButtonFinder, findsOneWidget);
          await tester.tap(shareButtonFinder);
          await pumpAndAdvance(tester, 300);

          // 5. ShareLinkBottomSheet opens
          expect(find.byType(ShareLinkBottomSheet), findsOneWidget);
          expect(find.text('Bagikan Pelacakan Publik'), findsOneWidget);
          expect(
            find.text('Truk Tronton Logistik B 9999 XYZ • TRONTON-77'),
            findsOneWidget,
          );

          // 6. Select preset 24 Jam
          final preset24hFinder = find.byKey(const Key('share_preset_24h'));
          expect(preset24hFinder, findsOneWidget);
          await tester.tap(preset24hFinder);
          await pumpAndAdvance(tester, 100);
          expect(shareProvider.selectedDuration, const Duration(hours: 24));

          // 7. Tap "Buat Tautan Berbagi"
          final generateButtonFinder = find.byKey(
            const Key('share_sheet_generate_button'),
          );
          expect(generateButtonFinder, findsOneWidget);
          await tester.tap(generateButtonFinder);
          await pumpAndAdvance(tester, 300);

          // 8. Verify Link Card is rendered with active share URL
          expect(
            find.byKey(const Key('share_sheet_link_card')),
            findsOneWidget,
          );
          expect(find.text('Tautan Publik Aktif'), findsOneWidget);
          expect(find.byKey(const Key('share_sheet_url_text')), findsOneWidget);

          // 9. Tap "Salin" button to copy URL to system clipboard
          final copyButtonFinder = find.byKey(
            const Key('share_sheet_copy_button'),
          );
          expect(copyButtonFinder, findsOneWidget);
          await tester.tap(copyButtonFinder);
          await pumpAndAdvance(tester, 300);

          // 10. Verify clipboard content & SnackBar feedback
          expect(
            capturedClipboardText,
            equals('https://demo.traccar.org/?token=mock_token_reg_123'),
          );
          expect(
            find.text('Tautan berhasil disalin ke clipboard'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'TC-SHARE-REG-02: HTTP 409 Conflict Handling: Active Share Link Detected -> Amber Warning Banner Rendered Without Crash',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // Configure repository to simulate 409 Conflict from backend
          mockShareRepo.failureToReturn = const ConflictFailure(
            'Tautan aktif sudah terdaftar untuk unit ini (409 Conflict)',
            statusCode: 409,
          );

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          liveFleet.selectDevice(tDevice.id);
          await pumpAndAdvance(tester, 300);

          // Open share bottom sheet
          await tester.tap(find.byKey(const Key('vehicle_sheet_share_button')));
          await pumpAndAdvance(tester, 300);
          expect(find.byType(ShareLinkBottomSheet), findsOneWidget);

          // Trigger generation on conflicted device
          await tester.tap(
            find.byKey(const Key('share_sheet_generate_button')),
          );
          await pumpAndAdvance(tester, 300);

          // Verify state evaluation
          expect(shareProvider.isConflict, isTrue);
          expect(shareProvider.shareLink, isNull);

          // Verify amber conflict banner is displayed and no crash occurs
          expect(
            find.byKey(const Key('share_sheet_conflict_banner')),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Tautan berbagi aktif untuk armada ini sudah terdaftar',
            ),
            findsOneWidget,
          );
          expect(find.byKey(const Key('share_sheet_link_card')), findsNothing);
        },
      );

      testWidgets(
        'TC-SHARE-REG-03: Preset Duration Switching & Dynamic Expiration Timestamp Calculation: 1h -> 6h -> 24h -> 7d',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          liveFleet.selectDevice(tDevice.id);
          await pumpAndAdvance(tester, 300);

          await tester.tap(find.byKey(const Key('vehicle_sheet_share_button')));
          await pumpAndAdvance(tester, 300);

          // 1. Switch to 1 Hour
          await tester.tap(find.byKey(const Key('share_preset_1h')));
          await pumpAndAdvance(tester, 50);
          expect(shareProvider.selectedDuration, const Duration(hours: 1));

          // 2. Switch to 6 Hours
          await tester.tap(find.byKey(const Key('share_preset_6h')));
          await pumpAndAdvance(tester, 50);
          expect(shareProvider.selectedDuration, const Duration(hours: 6));

          // 3. Switch to 24 Hours
          await tester.tap(find.byKey(const Key('share_preset_24h')));
          await pumpAndAdvance(tester, 50);
          expect(shareProvider.selectedDuration, const Duration(hours: 24));

          // 4. Switch to 7 Days
          await tester.tap(find.byKey(const Key('share_preset_7d')));
          await pumpAndAdvance(tester, 50);
          expect(shareProvider.selectedDuration, const Duration(days: 7));

          // 5. Generate with 7 Days preset
          await tester.tap(
            find.byKey(const Key('share_sheet_generate_button')),
          );
          await pumpAndAdvance(tester, 300);

          expect(mockShareRepo.lastDuration, equals(const Duration(days: 7)));
          expect(shareProvider.hasLink, isTrue);
          expect(shareProvider.shareLink!.isExpired, isFalse);
          // Remaining duration must be approximately 7 days (> 6 days 23 hours)
          expect(
            shareProvider.shareLink!.remainingDuration.inHours,
            greaterThanOrEqualTo(167),
          );
        },
      );

      testWidgets(
        'TC-SHARE-REG-04: Deterministic Base URL Sanitization: Strips /api, /api/, and Trailing Slashes from Generated Share URL',
        (tester) async {
          // Verify helper algorithm determinism across edge cases
          expect(
            ShareLinkModel.buildShareUrl(
              'https://demo.traccar.org/api',
              'tok_abc',
            ),
            equals('https://demo.traccar.org/?token=tok_abc'),
          );
          expect(
            ShareLinkModel.buildShareUrl(
              'https://demo.traccar.org/api/',
              'tok_abc',
            ),
            equals('https://demo.traccar.org/?token=tok_abc'),
          );
          expect(
            ShareLinkModel.buildShareUrl(
              'https://demo.traccar.org/',
              'tok_abc',
            ),
            equals('https://demo.traccar.org/?token=tok_abc'),
          );
          expect(
            ShareLinkModel.buildShareUrl('https://demo.traccar.org', 'tok_abc'),
            equals('https://demo.traccar.org/?token=tok_abc'),
          );
          expect(
            ShareLinkModel.buildShareUrl(
              'http://192.168.1.100:8082/api',
              'tok_xyz',
            ),
            equals('http://192.168.1.100:8082/?token=tok_xyz'),
          );

          // Verify UI representation when custom model with sanitized URL is set
          mockShareRepo.mockLinkToReturn = ShareLinkModel(
            deviceId: 77,
            token: 'clean_token_888',
            expiration: DateTime.now().add(const Duration(hours: 6)),
            shareUrl: ShareLinkModel.buildShareUrl(
              'https://gps.company.co.id/api',
              'clean_token_888',
            ),
          );

          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          liveFleet.selectDevice(tDevice.id);
          await pumpAndAdvance(tester, 300);

          await tester.tap(find.byKey(const Key('vehicle_sheet_share_button')));
          await pumpAndAdvance(tester, 300);

          await tester.tap(
            find.byKey(const Key('share_sheet_generate_button')),
          );
          await pumpAndAdvance(tester, 300);

          final urlTextWidget = tester.widget<Text>(
            find.byKey(const Key('share_sheet_url_text')),
          );
          expect(urlTextWidget.data, isNot(contains('/api')));
          expect(
            urlTextWidget.data,
            equals('https://gps.company.co.id/?token=clean_token_888'),
          );
        },
      );

      testWidgets(
        'TC-SHARE-REG-05: Session Reset on Logout: FleetShellScreen Logout Deterministically Purges ShareProvider State',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // 1. Pre-generate active link in ShareProvider
          await shareProvider.generateLink(77);
          expect(shareProvider.hasLink, isTrue);
          expect(shareProvider.shareLink, isNotNull);

          // 2. Render FleetShellScreen
          await tester.pumpWidget(buildTestApp());
          await pumpAndAdvance(tester, 100);

          // 3. Trigger Logout from AppBar action button
          final logoutButtonFinder = find.byKey(
            const Key('fleet_app_bar_logout_button'),
          );
          expect(logoutButtonFinder, findsOneWidget);
          await tester.tap(logoutButtonFinder);
          await pumpAndAdvance(tester, 300);

          // 4. Verify system session logout & WebSocket disconnection
          expect(fakeWs.disconnectCalled, isTrue);
          expect(mockAuthRepo.logoutCalled, isTrue);

          // 5. Verify ShareProvider state is completely purged
          expect(shareProvider.shareLink, isNull);
          expect(shareProvider.hasLink, isFalse);
          expect(shareProvider.isConflict, isFalse);
          expect(shareProvider.errorMessage, isNull);
          expect(shareProvider.selectedDuration, const Duration(hours: 24));
        },
      );
    },
  );
}
