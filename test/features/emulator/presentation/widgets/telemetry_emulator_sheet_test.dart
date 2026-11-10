import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/domain/repositories/auth_repository.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/emulator/data/models/osmand_transport_diagnostics.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';
import 'package:gpsku/features/emulator/domain/repositories/telemetry_emulator_repository.dart';
import 'package:gpsku/features/emulator/presentation/providers/telemetry_emulator_provider.dart';
import 'package:gpsku/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';

class _SheetMockAuthRepository implements AuthRepository {
  UserModel? userToReturn;

  _SheetMockAuthRepository(this.userToReturn);

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async {
    if (userToReturn != null) return Right(userToReturn!);
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
    if (userToReturn != null) return Right(userToReturn!);
    return const Left(AuthFailure('Invalid'));
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);
}

class MockTelemetryEmulatorRepo
    implements TelemetryEmulatorRepository, OsmandTransportDiagnosticsProvider {
  bool sendTelemetrySuccess = true;
  bool probePortSuccess = true;
  Failure? failureToReturn;
  OsmandTransportDiagnostics? diagnosticsToReturn;

  @override
  OsmandTransportDiagnostics? get lastTransportDiagnostics =>
      diagnosticsToReturn;

  int sendCount = 0;
  int probeCount = 0;
  TelemetryPacketModel? lastPacket;

  @override
  Future<Either<Failure, bool>> sendTelemetry({
    required TelemetryPacketModel packet,
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async {
    sendCount++;
    lastPacket = packet;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(sendTelemetrySuccess);
  }

  @override
  Future<Either<Failure, bool>> probePort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async {
    probeCount++;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(probePortSuccess);
  }
}

class FakeTraccarWebSocketService extends TraccarWebSocketService {
  final _mockStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _mockMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  FakeTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  Stream<WebSocketConnectionState> get stateStream =>
      _mockStateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream =>
      _mockMessageController.stream;

  @override
  void dispose() {
    _mockStateController.close();
    _mockMessageController.close();
    super.dispose();
  }
}

void main() {
  group('TelemetryEmulatorSheet Widget Tests', () {
    late MockTelemetryEmulatorRepo mockRepo;
    late TelemetryEmulatorProvider emulatorProvider;
    late FakeTraccarWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;

    const tDevice1 = DeviceModel(
      id: 101,
      name: 'Truk Logistik B 1234 ABC',
      uniqueId: 'TRONTON-99',
      status: 'online',
    );

    const tDevice2 = DeviceModel(
      id: 102,
      name: 'Pickup Box B 5678 DEF',
      uniqueId: 'PICKUP-12',
      status: 'online',
    );

    final tPosition1 = PositionModel(
      id: 501,
      deviceId: 101,
      protocol: 'osmand',
      serverTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      fixTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      valid: true,
      latitude: -6.1754,
      longitude: 106.8272,
      altitude: 40.0,
      speed: 15.0,
      course: 180.0,
      attributes: const {'ignition': true, 'batteryLevel': 95.0},
    );

    setUp(() {
      mockRepo = MockTelemetryEmulatorRepo();
      emulatorProvider = TelemetryEmulatorProvider(repository: mockRepo);
      fakeWs = FakeTraccarWebSocketService();
      liveFleet = LiveFleetProvider(webSocketService: fakeWs);
      liveFleet.setInitialFleetData(
        initialDevices: [tDevice1, tDevice2],
        initialPositions: [tPosition1],
      );
    });

    tearDown(() {
      emulatorProvider.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    Widget buildTestWidget({DeviceModel? initialDevice}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
            value: emulatorProvider,
          ),
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TelemetryEmulatorSheet(initialDevice: initialDevice),
          ),
        ),
      );
    }

    testWidgets(
      'TC-TES-01: Renders sheet title, close button, and port probe badge',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Simulator Telemetri (Port 5055)'), findsOneWidget);
        expect(
          find.byKey(const Key('emulator_sheet_close_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('emulator_port_probe_badge')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-TES-02: Target fleet selection displays uniqueId badge strictly',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(initialDevice: tDevice1));
        await tester.pumpAndSettle();

        // Verify strict Condition 2 resolution in UI: displays 'Unique ID: TRONTON-99'
        expect(
          find.byKey(const Key('emulator_target_unique_id_badge')),
          findsOneWidget,
        );
        expect(find.text('Unique ID: TRONTON-99'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-TES-03: Latitude and Longitude fields update provider coordinates on change',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final latField = find.byKey(const Key('emulator_latitude_field'));
        final lonField = find.byKey(const Key('emulator_longitude_field'));

        expect(latField, findsOneWidget);
        expect(lonField, findsOneWidget);

        await tester.enterText(latField, '-7.2504');
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentLat, -7.2504);

        await tester.enterText(lonField, '112.7688');
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentLon, 112.7688);
      },
    );

    testWidgets(
      'TC-TES-04: Sliders for Speed, Bearing, and Battery update provider state',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final speedSlider = find.byKey(const Key('emulator_speed_slider'));
        final bearingSlider = find.byKey(const Key('emulator_bearing_slider'));
        final batterySlider = find.byKey(const Key('emulator_battery_slider'));

        expect(speedSlider, findsOneWidget);
        expect(bearingSlider, findsOneWidget);
        expect(batterySlider, findsOneWidget);

        // Drag speed slider
        await tester.ensureVisible(speedSlider);
        await tester.pumpAndSettle();
        await tester.drag(speedSlider, const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentSpeed, greaterThan(20.0));

        // Drag bearing slider
        await tester.ensureVisible(bearingSlider);
        await tester.pumpAndSettle();
        await tester.drag(bearingSlider, const Offset(60, 0));
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentBearing, greaterThan(90.0));

        // Drag battery slider
        await tester.ensureVisible(batterySlider);
        await tester.pumpAndSettle();
        await tester.drag(batterySlider, const Offset(-60, 0));
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentBattery, lessThan(85.0));
      },
    );

    testWidgets('TC-TES-05: Ignition switch toggles engine contact state', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(emulatorProvider.isIgnitionOn, isTrue);

      final switchFinder = find.byKey(const Key('emulator_ignition_switch'));
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(emulatorProvider.isIgnitionOn, isFalse);
    });

    testWidgets(
      'TC-TES-06: Tapping Kirim Titik Tunggal sends packet and displays SnackBar feedback',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(initialDevice: tDevice1));
        await tester.pumpAndSettle();

        final sendButton = find.byKey(
          const Key('emulator_send_single_fix_button'),
        );
        expect(sendButton, findsOneWidget);

        await tester.ensureVisible(sendButton);
        await tester.pumpAndSettle();
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        expect(mockRepo.sendCount, 1);
        expect(mockRepo.lastPacket?.id, 'TRONTON-99');
        expect(find.textContaining('HTTP 200 OK'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-TES-07: Simulation interval chips update provider interval',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final chip1s = find.byKey(const Key('emulator_interval_1s'));
        final chip5s = find.byKey(const Key('emulator_interval_5s'));

        expect(chip1s, findsOneWidget);
        expect(chip5s, findsOneWidget);

        await tester.ensureVisible(chip1s);
        await tester.pumpAndSettle();
        await tester.tap(chip1s);
        await tester.pumpAndSettle();
        expect(emulatorProvider.simulationInterval.inSeconds, 1);

        await tester.ensureVisible(chip5s);
        await tester.pumpAndSettle();
        await tester.tap(chip5s);
        await tester.pumpAndSettle();
        expect(emulatorProvider.simulationInterval.inSeconds, 5);
      },
    );

    testWidgets(
      'TC-TES-08: Path simulation controls: Mulai, Jeda, and Berhenti trigger state changes',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(initialDevice: tDevice1));
        await tester.pumpAndSettle();

        final startBtn = find.byKey(
          const Key('emulator_start_simulation_button'),
        );
        final pauseBtn = find.byKey(
          const Key('emulator_pause_simulation_button'),
        );
        final stopBtn = find.byKey(
          const Key('emulator_stop_simulation_button'),
        );

        expect(startBtn, findsOneWidget);
        expect(pauseBtn, findsOneWidget);
        expect(stopBtn, findsOneWidget);

        await tester.ensureVisible(startBtn);
        await tester.pumpAndSettle();

        // Start
        await tester.tap(startBtn);
        await tester.pump();
        expect(emulatorProvider.isSimulating, isTrue);
        expect(find.text('BERGERAK'), findsOneWidget);

        // Pause
        await tester.tap(pauseBtn);
        await tester.pump();
        expect(emulatorProvider.isPaused, isTrue);
        expect(find.text('DIJEDA'), findsOneWidget);

        // Stop
        await tester.tap(stopBtn);
        await tester.pump();
        expect(emulatorProvider.isSimulating, isFalse);
        expect(find.text('IDLE'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-TES-09: Gunakan Posisi Terakhir Unit button updates coordinates from LiveFleetProvider',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(initialDevice: tDevice1));
        await tester.pumpAndSettle();

        // Change coordinates to arbitrary value
        emulatorProvider.updateCoordinates(lat: 0.0, lon: 0.0);
        await tester.pumpAndSettle();
        expect(emulatorProvider.currentLat, 0.0);

        // Tap button to restore last known position
        final restoreBtn = find.byKey(
          const Key('emulator_use_last_known_position_button'),
        );
        expect(restoreBtn, findsOneWidget);

        await tester.ensureVisible(restoreBtn);
        await tester.pumpAndSettle();
        await tester.tap(restoreBtn);
        await tester.pumpAndSettle();

        expect(emulatorProvider.currentLat, -6.1754);
        expect(emulatorProvider.currentLon, 106.8272);
      },
    );

    testWidgets(
      'TC-TES-10: TelemetryEmulatorSheet.show opens bottom sheet modally',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: emulatorProvider,
              ),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open_emulator_sheet_button'),
                    onPressed: () => TelemetryEmulatorSheet.show(
                      ctx,
                      initialDevice: tDevice1,
                    ),
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open_emulator_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.byType(TelemetryEmulatorSheet), findsOneWidget);
        expect(find.text('Simulator Telemetri (Port 5055)'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-TES-11: Renders Fallback :8082 badge and preserved direct error instead of masking as Port 5055 Aktif',
      (tester) async {
        mockRepo.diagnosticsToReturn = OsmandTransportDiagnostics(
          mode: OsmandTransportMode.httpWebProxyFallback,
          endpointUri: Uri.parse('http://10.0.2.2:8082/'),
          httpMethod: 'POST',
          statusCode: 400,
          initialDirectFailureReason: 'Connection refused on port 5055',
          timestamp: DateTime.utc(2026, 11, 10),
        );

        await tester.pumpWidget(buildTestWidget(initialDevice: tDevice1));
        await tester.pumpAndSettle();

        expect(find.text('Port 5055 Aktif'), findsNothing);
        expect(find.text('Fallback :8082 Aktif'), findsOneWidget);
        expect(
          find.byKey(const Key('emulator_transport_diagnostics_card')),
          findsOneWidget,
        );
        expect(find.textContaining('http://10.0.2.2:8082/'), findsOneWidget);
        expect(
          find.textContaining('Connection refused on port 5055'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-TES-12: Clicking Pilih di Peta enables isMapPickMode and closes bottom sheet',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: emulatorProvider,
              ),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open_emulator_sheet_button'),
                    onPressed: () => TelemetryEmulatorSheet.show(
                      ctx,
                      initialDevice: tDevice1,
                    ),
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open_emulator_sheet_button')));
        await tester.pumpAndSettle();

        final pickBtn = find.byKey(const Key('emulator_pick_on_map_button'));
        expect(pickBtn, findsOneWidget);
        await tester.ensureVisible(pickBtn);
        await tester.tap(pickBtn);
        await tester.pumpAndSettle();

        expect(emulatorProvider.isMapPickMode, isTrue);
        expect(find.byType(TelemetryEmulatorSheet), findsNothing);
      },
    );

    testWidgets(
      'TC-TES-13: TelemetryEmulatorSheet.show and widget render deny non-admin and readonly users',
      (tester) async {
        final roAuth = AuthProvider(
          authRepository: _SheetMockAuthRepository(
            const UserModel(
              id: 2,
              name: 'ReadOnlyAdmin',
              email: 'ro@gpsku.id',
              administrator: true,
              readonly: true,
            ),
          ),
        );
        await roAuth.checkInitialAuth();

        final guardedEmulator = TelemetryEmulatorProvider(
          repository: mockRepo,
          authProvider: roAuth,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: roAuth),
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: guardedEmulator,
              ),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open_emulator_sheet_button'),
                    onPressed: () => TelemetryEmulatorSheet.show(
                      ctx,
                      initialDevice: tDevice1,
                    ),
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open_emulator_sheet_button')));
        await tester.pumpAndSettle();

        // Modal sheet must NOT open for readonly user
        expect(find.byType(TelemetryEmulatorSheet), findsNothing);
        expect(find.textContaining('Akses ditolak'), findsOneWidget);

        // Even if directly mounted, widget renders Access Denied card with 0 send buttons
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: roAuth),
              ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
                value: guardedEmulator,
              ),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            ],
            child: const MaterialApp(
              home: TelemetryEmulatorSheet(isFullScreen: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('emulator_sheet_access_denied')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('emulator_send_single_fix_button')),
          findsNothing,
        );

        guardedEmulator.dispose();
        roAuth.dispose();
      },
    );
  });
}
