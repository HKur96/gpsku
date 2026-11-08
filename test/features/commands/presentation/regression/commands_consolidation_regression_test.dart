import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/domain/repositories/auth_repository.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/commands/data/models/command_payload_model.dart';
import 'package:gpsku/features/commands/data/models/command_type_model.dart';
import 'package:gpsku/features/commands/domain/repositories/commands_repository.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';
import 'package:provider/provider.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Admin Telematics',
    email: 'admin@gpsku.id',
    administrator: true,
  );

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async => Right(mockUser!);

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

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

class MockFleetRepository implements FleetRepository {
  Either<Failure, List<DeviceModel>> devicesResult = const Right([]);
  Either<Failure, List<PositionModel>> positionsResult = const Right([]);
  Either<Failure, List<GroupModel>> groupsResult = const Right([]);

  @override
  Future<Either<Failure, List<DeviceModel>>> getDevices({
    CancelToken? cancelToken,
  }) async => devicesResult;

  @override
  Future<Either<Failure, List<PositionModel>>> getPositions({
    CancelToken? cancelToken,
  }) async => positionsResult;

  @override
  Future<Either<Failure, List<GroupModel>>> getGroups({
    CancelToken? cancelToken,
  }) async => groupsResult;
}

class FakeWebSocketService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();
  final WebSocketConnectionState _state = WebSocketConnectionState.connected;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => _state;

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

class MockCommandsRepository implements CommandsRepository {
  List<CommandTypeModel> mockTypes = [
    const CommandTypeModel(type: 'engineStop'),
    const CommandTypeModel(type: 'engineResume'),
    const CommandTypeModel(type: 'custom'),
    const CommandTypeModel(type: 'positionPeriodic'),
  ];
  CommandPayloadModel? mockSendResult;
  Failure? getTypesFailure;
  Failure? sendFailure;
  CommandPayloadModel? lastSentPayload;

  @override
  Future<Either<Failure, List<CommandTypeModel>>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  }) async {
    if (getTypesFailure != null) return Left(getTypesFailure!);
    return Right(mockTypes);
  }

  @override
  Future<Either<Failure, CommandPayloadModel>> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  }) async {
    lastSentPayload = payload;
    if (sendFailure != null) return Left(sendFailure!);
    return Right(mockSendResult ?? payload);
  }
}

void main() {
  group('Phase 7.6 Remote Commands Final Consolidation & Regression Tests', () {
    late MockAuthRepository mockAuthRepo;
    late MockFleetRepository mockFleetRepo;
    late FakeWebSocketService fakeWs;
    late MockCommandsRepository mockCommandsRepo;
    late AuthProvider authProvider;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator syncCoordinator;

    final tDevice = DeviceModel(
      id: 77,
      name: 'Truck Logistik #77',
      uniqueId: 'B 9977 XYZ',
      status: 'online',
      model: 'Hino Dutro Cargo',
    );

    final tFastPosition = PositionModel(
      id: 100,
      deviceId: 77,
      serverTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      fixTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      latitude: -6.2000,
      longitude: 106.8166,
      speed: 25.0, // 25 knots * 1.852 = 46.3 km/h (> 20 km/h)
      attributes: const {'ignition': true},
    );

    final tSlowPosition = PositionModel(
      id: 101,
      deviceId: 77,
      serverTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      fixTime: DateTime.utc(2026, 11, 8, 14, 0, 0),
      latitude: -6.2000,
      longitude: 106.8166,
      speed: 5.0, // 5 knots * 1.852 = 9.26 km/h (<= 20 km/h)
      attributes: const {'ignition': true},
    );

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockFleetRepo = MockFleetRepository();
      fakeWs = FakeWebSocketService();
      mockCommandsRepo = MockCommandsRepository();

      authProvider = AuthProvider(authRepository: mockAuthRepo);
      authProvider.checkInitialAuth();

      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 10),
      );

      syncCoordinator = InitialFleetSyncCoordinator(
        fleetRepository: mockFleetRepo,
        liveFleetProvider: liveFleet,
        webSocketService: fakeWs,
      );
    });

    tearDown(() {
      liveFleet.dispose();
      syncCoordinator.dispose();
      fakeWs.dispose();
    });

    Widget buildTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
          ChangeNotifierProvider<InitialFleetSyncCoordinator>.value(
            value: syncCoordinator,
          ),
          Provider<TraccarWebSocketService>.value(value: fakeWs),
          Provider<FleetRepository>.value(value: mockFleetRepo),
          Provider<CommandsRepository>.value(value: mockCommandsRepo),
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
      'REG-CMD-01: End-to-End Cycle: Select Vehicle -> Open Sheet -> Speed Interlock -> Checkbox -> Slide-To-Confirm -> Send 200 OK',
      (tester) async {
        // 1. Seed moving vehicle
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice],
          initialPositions: [tFastPosition],
        );
        liveFleet.selectDevice(77);

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 2. VehicleDetailSheet must be visible with vehicle details
        expect(find.text('Truck Logistik #77'), findsOneWidget);
        expect(find.text('B 9977 XYZ • Hino Dutro Cargo'), findsOneWidget);

        // 3. Tap "Perintah" button on VehicleDetailSheet
        final cmdButton = find.byKey(
          const Key('vehicle_sheet_commands_button'),
        );
        expect(cmdButton, findsOneWidget);
        await tester.tap(cmdButton);
        await pumpAndAdvance(tester, 400);

        // 4. CommandBottomSheet opens, validates supported types dropdown
        expect(find.byKey(const Key('command_type_dropdown')), findsOneWidget);

        // 5. Speed Safety Interlock check: vehicle speed is 46.3 km/h
        expect(
          find.byKey(const Key('speed_interlock_warning')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Kendaraan Melaju: 46.3 km/h'),
          findsOneWidget,
        );

        // Slide-to-confirm is locked initially
        expect(find.text('Terkunci / Nonaktif'), findsOneWidget);

        // 6. Check the safety acknowledgement checkbox
        await tester.tap(find.byKey(const Key('speed_interlock_checkbox')));
        await pumpAndAdvance(tester, 100);

        // Slider unlocked
        expect(find.text('Geser untuk Matikan Mesin'), findsOneWidget);

        // 7. Drag Slide-to-Confirm >= 90%
        mockCommandsRepo.mockSendResult = CommandPayloadModel(
          deviceId: 77,
          type: 'engineStop',
          isQueued: false,
        );

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(500, 0));
        await pumpAndAdvance(tester, 400);

        // 8. Verify payload dispatch & success snackbar
        expect(mockCommandsRepo.lastSentPayload?.deviceId, equals(77));
        expect(mockCommandsRepo.lastSentPayload?.type, equals('engineStop'));
        expect(
          find.byKey(const Key('command_success_snackbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'REG-CMD-02: Custom command protocol parameter execution & validation',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice],
          initialPositions: [tSlowPosition],
        );
        liveFleet.selectDevice(77);

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        await tester.tap(
          find.byKey(const Key('vehicle_sheet_commands_button')),
        );
        await pumpAndAdvance(tester, 400);

        // Switch to custom command
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Perintah Kustom (Protokol)').last);
        await pumpAndAdvance(tester, 300);

        // Input protocol payload
        await tester.enterText(
          find.byKey(const Key('custom_command_input')),
          'STATUS,123#',
        );
        await pumpAndAdvance(tester, 100);

        // Submit via send button
        await tester.tap(find.byKey(const Key('command_send_button')));
        await pumpAndAdvance(tester, 400);

        expect(mockCommandsRepo.lastSentPayload?.deviceId, equals(77));
        expect(mockCommandsRepo.lastSentPayload?.type, equals('custom'));
        expect(
          mockCommandsRepo.lastSentPayload?.attributes['data'],
          equals('STATUS,123#'),
        );
        expect(
          find.byKey(const Key('command_success_snackbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'REG-CMD-03: Offline device queued execution displays server queue snackbar (HTTP 202 isQueued=true)',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice.copyWith(status: 'offline')],
          initialPositions: [tSlowPosition],
        );
        liveFleet.selectDevice(77);

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        await tester.tap(
          find.byKey(const Key('vehicle_sheet_commands_button')),
        );
        await pumpAndAdvance(tester, 400);

        // Switch to custom
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Perintah Kustom (Protokol)').last);
        await pumpAndAdvance(tester, 300);

        await tester.enterText(
          find.byKey(const Key('custom_command_input')),
          'REBOOT#',
        );
        await pumpAndAdvance(tester, 100);

        // Server responds with 202 isQueued=true
        mockCommandsRepo.mockSendResult = CommandPayloadModel(
          deviceId: 77,
          type: 'custom',
          isQueued: true,
        );

        await tester.tap(find.byKey(const Key('command_send_button')));
        await pumpAndAdvance(tester, 400);

        expect(
          find.byKey(const Key('command_queued_snackbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'REG-CMD-04: Forbidden error (HTTP 403 ForbiddenFailure) renders error alert banner in sheet',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice],
          initialPositions: [tSlowPosition],
        );
        liveFleet.selectDevice(77);

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        await tester.tap(
          find.byKey(const Key('vehicle_sheet_commands_button')),
        );
        await pumpAndAdvance(tester, 400);

        mockCommandsRepo.sendFailure = const ForbiddenFailure(
          'Akses ditolak: User dibatasi',
          statusCode: 403,
        );

        // Slider drag
        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(500, 0));
        await pumpAndAdvance(tester, 400);

        expect(find.byKey(const Key('command_error_banner')), findsOneWidget);
        expect(find.textContaining('Akses ditolak'), findsOneWidget);
      },
    );

    testWidgets(
      'REG-CMD-05: FocusNode & Controller lifecycle: Switching command types clears input and unfocuses safely',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [tDevice],
          initialPositions: [tSlowPosition],
        );
        liveFleet.selectDevice(77);

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        await tester.tap(
          find.byKey(const Key('vehicle_sheet_commands_button')),
        );
        await pumpAndAdvance(tester, 400);

        // Switch to custom
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Perintah Kustom (Protokol)').last);
        await pumpAndAdvance(tester, 300);

        await tester.enterText(
          find.byKey(const Key('custom_command_input')),
          'TEMP_INPUT',
        );
        expect(find.text('TEMP_INPUT'), findsOneWidget);

        // Switch to positionPeriodic
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Set Periode Pelaporan').last);
        await pumpAndAdvance(tester, 300);

        expect(
          find.byKey(const Key('frequency_command_input')),
          findsOneWidget,
        );

        // Switch back to custom: old text must be cleared cleanly
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Perintah Kustom (Protokol)').last);
        await pumpAndAdvance(tester, 300);

        expect(find.text('TEMP_INPUT'), findsNothing);
      },
    );
  });
}
