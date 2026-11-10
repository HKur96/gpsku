import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/domain/repositories/auth_repository.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/emulator/data/datasources/telemetry_emulator_remote_data_source.dart';
import 'package:gpsku/features/emulator/data/models/osmand_transport_diagnostics.dart';
import 'package:gpsku/features/emulator/data/repositories/telemetry_emulator_repository_impl.dart';
import 'package:gpsku/features/emulator/domain/repositories/telemetry_emulator_repository.dart';
import 'package:gpsku/features/emulator/presentation/providers/telemetry_emulator_provider.dart';
import 'package:gpsku/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_map_widget.dart';
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';
import 'package:gpsku/features/settings/presentation/screens/app_settings_screen.dart';

class _MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Fleet Admin',
    email: 'admin@gpsku.id',
    administrator: true,
    readonly: false,
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

class _FakeTraccarWebSocketService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();
  bool disconnectCalled = false;

  _FakeTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => WebSocketConnectionState.connected;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  void emitPayload(Map<String, dynamic> payload) {
    _msgController.add(payload);
  }

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

class _RecordingMockDio extends DioMixin implements Dio {
  int mockPostStatusCode = 200;
  int mockGetStatusCode = 200;
  DioException? postExceptionToThrow;
  DioException? getExceptionToThrow;
  Duration responseDelay = Duration.zero;
  Completer<void>? pendingGate;

  final List<Uri> recordedPostUris = [];
  final List<dynamic> recordedPostData = [];
  final List<Options?> recordedPostOptions = [];
  final List<Uri> recordedGetUris = [];
  final List<CancelToken?> recordedCancelTokens = [];

  @override
  Future<Response<T>> postUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    recordedPostUris.add(uri);
    recordedPostData.add(data);
    recordedPostOptions.add(options);
    recordedCancelTokens.add(cancelToken);

    if (pendingGate != null) {
      await pendingGate!.future;
    } else if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: uri.toString()),
        type: DioExceptionType.cancel,
      );
    }

    if (postExceptionToThrow != null) {
      throw postExceptionToThrow!;
    }

    return Response<T>(
      requestOptions: RequestOptions(path: uri.toString()),
      statusCode: mockPostStatusCode,
    );
  }

  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    recordedGetUris.add(uri);
    recordedCancelTokens.add(cancelToken);

    if (pendingGate != null) {
      await pendingGate!.future;
    } else if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: uri.toString()),
        type: DioExceptionType.cancel,
      );
    }

    if (getExceptionToThrow != null) {
      throw getExceptionToThrow!;
    }

    return Response<T>(
      requestOptions: RequestOptions(path: uri.toString()),
      statusCode: mockGetStatusCode,
    );
  }
}

void main() {
  group('Phase 9.3 Telemetry Emulator - Consolidation Regression Suite', () {
    late _MockAuthRepository mockAuthRepo;
    late AuthProvider authProvider;
    late _FakeTraccarWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late _RecordingMockDio mockDio;
    late AppConfig httpsConfig;
    late TelemetryEmulatorRemoteDataSourceImpl dataSource;
    late TelemetryEmulatorRepositoryImpl repository;
    late TelemetryEmulatorProvider emulatorProvider;

    const tDevice1 = DeviceModel(
      id: 101,
      name: 'Truk Logistik Alpha',
      uniqueId: 'TRK-IMEI-001',
      status: 'online',
    );

    const tDeviceOutlier = DeviceModel(
      id: 102,
      name: 'Unit Outlier Speed',
      uniqueId: 'OUT-IMEI-002',
      status: 'online',
    );

    final tPosition1 = PositionModel(
      id: 501,
      deviceId: 101,
      protocol: 'osmand',
      serverTime: DateTime.utc(2026, 11, 10, 10, 0),
      deviceTime: DateTime.utc(2026, 11, 10, 10, 0),
      fixTime: DateTime.utc(2026, 11, 10, 10, 0),
      valid: true,
      latitude: -6.1754,
      longitude: 106.8272,
      altitude: 35.0,
      speed: 20.0,
      course: 90.0,
      attributes: const {'ignition': true, 'batteryLevel': 88.0},
    );

    final tPositionOutlier = PositionModel(
      id: 502,
      deviceId: 102,
      protocol: 'osmand',
      serverTime: DateTime.utc(2026, 11, 10, 10, 0),
      deviceTime: DateTime.utc(2026, 11, 10, 10, 0),
      fixTime: DateTime.utc(2026, 11, 10, 10, 0),
      valid: true,
      latitude: -6.2500,
      longitude: 106.9000,
      altitude: 10.0,
      speed: 100.0,
      course: 400.0,
      attributes: const {'ignition': false, 'batteryLevel': 150.0},
    );

    setUp(() async {
      mockAuthRepo = _MockAuthRepository();
      authProvider = AuthProvider(authRepository: mockAuthRepo);
      await authProvider.checkInitialAuth();

      fakeWs = _FakeTraccarWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 10),
      );
      liveFleet.setInitialFleetData(
        initialDevices: [tDevice1, tDeviceOutlier],
        initialPositions: [tPosition1, tPositionOutlier],
      );

      mockDio = _RecordingMockDio();
      httpsConfig = const AppConfig(baseUrl: 'https://gps.company.com:8443');
      dataSource = TelemetryEmulatorRemoteDataSourceImpl(
        appConfig: httpsConfig,
        dio: mockDio,
        timeout: const Duration(seconds: 2),
        defaultPort: 5055,
      );
      repository = TelemetryEmulatorRepositoryImpl(
        remoteDataSource: dataSource,
      );
      emulatorProvider = TelemetryEmulatorProvider(
        repository: repository,
        authProvider: authProvider,
      );
    });

    tearDown(() {
      emulatorProvider.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
      authProvider.dispose();
    });

    Widget buildShellApp() {
      return MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: httpsConfig),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
          Provider<TraccarWebSocketService>.value(value: fakeWs),
          Provider<TelemetryEmulatorRepository>.value(value: repository),
          ChangeNotifierProvider<TelemetryEmulatorProvider>.value(
            value: emulatorProvider,
          ),
        ],
        child: const MaterialApp(home: FleetShellScreen()),
      );
    }

    Future<void> pumpAndAdvance(
      WidgetTester tester, [
      int durationMs = 200,
    ]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: durationMs));
      await tester.pump();
    }

    Future<void> openEmulatorViaSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('app_settings_action_button')));
      await pumpAndAdvance(tester, 300);

      expect(find.byType(AppSettingsScreen), findsOneWidget);
      final openEmulatorTile = find.byKey(
        const Key('settings_open_emulator_button'),
      );
      expect(openEmulatorTile, findsOneWidget);
      await tester.tap(openEmulatorTile);
      await pumpAndAdvance(tester, 400);
    }

    testWidgets(
      'TC-EMU-REG-01: Operational AppBar hides direct emulator button; Settings > Mode Pengembang probes HTTPS proxy via POST /',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        expect(
          emulatorProvider.simulationStatus,
          EmulatorSimulationStatus.idle,
        );
        expect(emulatorProvider.portStatus, OsmandPortStatus.unknown);

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 100);

        // Must NOT expose emulator launcher directly on daily AppBar
        expect(
          find.byKey(const Key('telemetry_emulator_action_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('app_settings_action_button')),
          findsOneWidget,
        );

        await openEmulatorViaSettings(tester);

        expect(find.byType(TelemetryEmulatorSheet), findsOneWidget);
        // Auto-probe over HTTPS MUST use POST / (for WebServer.initClientProxy), NOT GET /
        expect(mockDio.recordedGetUris, isEmpty);
        expect(mockDio.recordedPostUris, isNotEmpty);
        final probeUri = mockDio.recordedPostUris.last;
        expect(probeUri.scheme, 'https');
        expect(probeUri.host, 'gps.company.com');
        expect(probeUri.port, 8443);
        expect(probeUri.path, '/');
        expect(mockDio.recordedPostData.last, 'id=probe_ping');
        expect(find.text('Proxy HTTPS Aktif'), findsOneWidget);

        // HTTP 400 from OsmAnd confirms proxy listener active
        mockDio.mockPostStatusCode = 400;
        final reachableOn400 = await emulatorProvider.probePort();
        await pumpAndAdvance(tester, 50);
        expect(reachableOn400, isTrue);
        expect(emulatorProvider.portStatus, OsmandPortStatus.reachable);
        expect(
          emulatorProvider.lastTransportDiagnostics?.mode,
          OsmandTransportMode.httpsWebProxy,
        );
      },
    );

    testWidgets(
      'TC-EMU-REG-02: Device uniqueId mapping, outlier clamping, HTTPS POST / Single Fix 200 OK, and WebSocket loop update',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        emulatorProvider.setTargetDevice(tDeviceOutlier, tPositionOutlier);
        expect(emulatorProvider.targetUniqueId, 'OUT-IMEI-002');
        expect(emulatorProvider.currentSpeed, lessThanOrEqualTo(160.0));
        expect(emulatorProvider.currentBearing, inInclusiveRange(0.0, 360.0));
        expect(emulatorProvider.currentBattery, 100.0);

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 100);

        liveFleet.selectDevice(tDevice1.id);
        await pumpAndAdvance(tester, 50);

        // Reset target so Settings launch auto-picks currently selectedDevice safely
        emulatorProvider.clearState();
        await openEmulatorViaSettings(tester);

        expect(find.text('Unique ID: TRK-IMEI-001'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('emulator_latitude_field')),
          '-6.9175',
        );
        await tester.enterText(
          find.byKey(const Key('emulator_longitude_field')),
          '107.6191',
        );
        await pumpAndAdvance(tester, 50);

        mockDio.recordedPostUris.clear();
        mockDio.recordedPostData.clear();

        final sendBtn = find.byKey(
          const Key('emulator_send_single_fix_button'),
        );
        await tester.ensureVisible(sendBtn);
        await tester.tap(sendBtn);
        await pumpAndAdvance(tester, 200);

        expect(mockDio.recordedPostUris.length, 1);
        final sentUri = mockDio.recordedPostUris.single;
        expect(sentUri.scheme, 'https');
        expect(sentUri.path, '/');
        expect(sentUri.queryParameters, isEmpty);
        final form = Uri.splitQueryString(
          mockDio.recordedPostData.single as String,
        );
        expect(form['id'], 'TRK-IMEI-001');
        expect(form['lat'], '-6.9175');
        expect(form['lon'], '107.6191');
        expect(form.containsKey('speed'), isTrue);
        expect(form.containsKey('batt'), isTrue);
        expect(form.containsKey('timestamp'), isTrue);
        expect(emulatorProvider.transmissionSuccessCount, 1);
        expect(find.textContaining('HTTP 200 OK'), findsOneWidget);

        await tester.tap(find.byKey(const Key('emulator_sheet_close_button')));
        await pumpAndAdvance(tester, 300);

        fakeWs.emitPayload({
          'positions': [
            {
              'id': 9001,
              'deviceId': 101,
              'protocol': 'osmand',
              'serverTime': '2026-11-10T10:05:00Z',
              'deviceTime': '2026-11-10T10:05:00Z',
              'fixTime': '2026-11-10T10:05:00Z',
              'valid': true,
              'latitude': -6.9175,
              'longitude': 107.6191,
              'speed': 20.0,
              'course': 90.0,
            },
          ],
        });
        await pumpAndAdvance(tester, 50);
        liveFleet.flushImmediately();
        await tester.pump();

        expect(liveFleet.positions[101]?.latitude, -6.9175);
        expect(liveFleet.positions[101]?.longitude, 107.6191);
      },
    );

    test(
      'TC-EMU-REG-03: Geodesic calculations (incl. antimeridian wrap) and Simulation pause/resume/stop lifecycle',
      () async {
        final wrappedEast = TelemetryEmulatorProvider.computeNextCoordinate(
          const LatLng(0.0, 179.9999),
          200.0,
          90.0,
        );
        expect(wrappedEast.longitude, inInclusiveRange(-180.0, 180.0));
        expect(wrappedEast.longitude, lessThan(0.0));

        emulatorProvider.pauseSimulation();
        expect(
          emulatorProvider.simulationStatus,
          EmulatorSimulationStatus.idle,
        );

        emulatorProvider.setTargetDevice(tDevice1, tPosition1);
        emulatorProvider.updateSpeed(72.0);
        emulatorProvider.updateBearing(90.0);
        emulatorProvider.setSimulationInterval(
          const Duration(milliseconds: 40),
        );

        final startLon = emulatorProvider.currentLon;
        expect(emulatorProvider.startSimulation(), isTrue);
        expect(emulatorProvider.isSimulating, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 110));
        emulatorProvider.pauseSimulation();

        expect(emulatorProvider.isPaused, isTrue);
        final pausedLon = emulatorProvider.currentLon;
        final countWhenPaused = emulatorProvider.transmissionSuccessCount;
        expect(pausedLon, greaterThan(startLon));
        expect(countWhenPaused, greaterThanOrEqualTo(1));

        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(emulatorProvider.transmissionSuccessCount, countWhenPaused);

        expect(emulatorProvider.startSimulation(), isTrue);
        expect(emulatorProvider.isSimulating, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 110));
        emulatorProvider.stopSimulation();

        expect(
          emulatorProvider.simulationStatus,
          EmulatorSimulationStatus.idle,
        );
        expect(emulatorProvider.currentLon, greaterThan(pausedLon));
        expect(
          emulatorProvider.transmissionSuccessCount,
          greaterThan(countWhenPaused),
        );
      },
    );

    test(
      'TC-EMU-REG-04: Waypoint progression and non-overlapping slow async step guard',
      () async {
        emulatorProvider.setTargetDevice(tDevice1);
        emulatorProvider.setWaypoints(const [
          LatLng(-6.2000, 106.8000),
          LatLng(-6.2005, 106.8005),
          LatLng(-6.2010, 106.8100),
        ]);
        emulatorProvider.updateSpeed(120.0);
        emulatorProvider.setSimulationInterval(
          const Duration(milliseconds: 25),
        );

        mockDio.responseDelay = const Duration(milliseconds: 80);

        emulatorProvider.startSimulation();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        emulatorProvider.stopSimulation();

        expect(mockDio.recordedPostUris.length, lessThanOrEqualTo(2));
        expect(emulatorProvider.currentLat, lessThan(-6.2000));
        expect(emulatorProvider.currentLon, greaterThan(106.8000));
      },
    );

    testWidgets(
      'TC-EMU-REG-05: Error handling across HTTP 400, timeouts, and network refusals on HTTPS proxy',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        emulatorProvider.setTargetDevice(tDevice1, tPosition1);

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 100);
        await openEmulatorViaSettings(tester);

        // 1. HTTP 400 (Unregistered uniqueId)
        mockDio.postExceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'https://gps.company.com:8443/'),
          response: Response(
            requestOptions: RequestOptions(
              path: 'https://gps.company.com:8443/',
            ),
            statusCode: 400,
          ),
        );

        final sendBtn = find.byKey(
          const Key('emulator_send_single_fix_button'),
        );
        await tester.ensureVisible(sendBtn);
        await tester.tap(sendBtn);
        await pumpAndAdvance(tester, 200);

        expect(emulatorProvider.transmissionFailureCount, 1);
        expect(emulatorProvider.lastStatusCode, 400);
        expect(find.textContaining('HTTP 400'), findsWidgets);

        // 2. ConnectionTimeout
        mockDio.postExceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'https://gps.company.com:8443/'),
          type: DioExceptionType.connectionTimeout,
        );
        final timeoutOk = await emulatorProvider.sendSingleFix();
        expect(timeoutOk, isFalse);
        expect(emulatorProvider.lastErrorMessage, contains('timeout'));

        // 3. Unknown SocketException / DNS block during probe
        mockDio.postExceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'https://gps.company.com:8443/'),
          type: DioExceptionType.unknown,
          message: 'SocketException: Failed host lookup',
        );
        final probeOk = await emulatorProvider.probePort();
        await pumpAndAdvance(tester, 50);
        expect(probeOk, isFalse);
        expect(emulatorProvider.portStatus, OsmandPortStatus.unreachable);
        expect(find.text('Port 5055 Tertutup'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-EMU-REG-06: Logout state wipe resets parameters, disables map-pick mode, cancels timers, and guards dispose',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        emulatorProvider.setTargetDevice(tDevice1, tPosition1);
        expect(emulatorProvider.setMapPickMode(true), isTrue);
        emulatorProvider.updateSpeed(95.0);
        emulatorProvider.updateBattery(33.0);
        emulatorProvider.setIgnition(false);
        emulatorProvider.setSimulationInterval(const Duration(seconds: 5));
        emulatorProvider.setWaypoints(const [
          LatLng(-6.1, 106.8),
          LatLng(-6.2, 106.9),
        ]);
        emulatorProvider.startSimulation();

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 100);
        expect(find.byKey(const Key('emulator_map_pick_hud')), findsOneWidget);

        await tester.tap(find.byKey(const Key('fleet_app_bar_logout_button')));
        await pumpAndAdvance(tester, 150);

        expect(mockAuthRepo.logoutCalled, isTrue);
        expect(fakeWs.disconnectCalled, isTrue);
        expect(emulatorProvider.isMapPickMode, isFalse);
        expect(emulatorProvider.isSimulating, isFalse);
        expect(
          emulatorProvider.simulationStatus,
          EmulatorSimulationStatus.idle,
        );
        expect(emulatorProvider.portStatus, OsmandPortStatus.unknown);
        expect(emulatorProvider.targetUniqueId, isEmpty);
        expect(emulatorProvider.targetDeviceName, isNull);
        expect(emulatorProvider.currentLat, -6.2088);
        expect(emulatorProvider.currentLon, 106.8456);
        expect(emulatorProvider.currentSpeed, 20.0);
        expect(emulatorProvider.currentBearing, 90.0);
        expect(emulatorProvider.currentBattery, 85.0);
        expect(emulatorProvider.isIgnitionOn, isTrue);
        expect(emulatorProvider.simulationInterval, const Duration(seconds: 2));
        expect(emulatorProvider.simulationWaypoints, isEmpty);
        expect(emulatorProvider.transmissionSuccessCount, 0);
        expect(emulatorProvider.transmissionFailureCount, 0);

        final standaloneDio = _RecordingMockDio();
        final gate = Completer<void>();
        standaloneDio.pendingGate = gate;
        final standaloneProvider = TelemetryEmulatorProvider(
          repository: TelemetryEmulatorRepositoryImpl(
            remoteDataSource: TelemetryEmulatorRemoteDataSourceImpl(
              appConfig: const AppConfig(),
              dio: standaloneDio,
            ),
          ),
        );
        standaloneProvider.setTargetDevice(tDevice1);
        final inFlight = standaloneProvider.sendSingleFix();
        standaloneProvider.dispose();
        gate.complete();
        expect(await inFlight, isFalse);
      },
    );

    testWidgets(
      'TC-EMU-REG-07: Operational UI cleanliness (no emulator button in VehicleDetailSheet) & strict non-admin/readonly block',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Switch active user to non-readonly normal user
        mockAuthRepo.mockUser = const UserModel(
          id: 2,
          name: 'Regular Fleet User',
          email: 'user@gpsku.id',
          administrator: false,
          readonly: false,
        );
        await authProvider.checkInitialAuth();
        liveFleet.selectDevice(tDevice1.id);

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 150);

        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(
          find.byKey(const Key('vehicle_sheet_emulator_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('telemetry_emulator_action_button')),
          findsNothing,
        );

        // Open Settings as non-admin -> Developer section hidden
        await tester.tap(find.byKey(const Key('app_settings_action_button')));
        await pumpAndAdvance(tester, 200);
        expect(find.byType(AppSettingsScreen), findsOneWidget);
        expect(
          find.byKey(const Key('settings_developer_section')),
          findsNothing,
        );

        // Unauthorized user cannot activate map-pick or transmit telemetry
        expect(emulatorProvider.setMapPickMode(true), isFalse);
        expect(await emulatorProvider.sendSingleFix(), isFalse);
        expect(mockDio.recordedPostUris, isEmpty);
      },
    );

    testWidgets(
      'TC-EMU-REG-08: Map-tap coordinate injection (zero auto-transmit, accepts 0,0, explicit HUD send, preserves marker compat)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildShellApp());
        await pumpAndAdvance(tester, 100);

        // 1. When map-pick mode is OFF, tapping map leaves emulator untouched & zero HTTP calls
        final mapWidgetOff = tester.widget<FleetMapWidget>(
          find.byType(FleetMapWidget),
        );
        mapWidgetOff.onMapClick?.call(
          const Point<double>(120, 140),
          const LatLng(-7.7956, 110.3695),
        );
        await tester.pump();
        expect(emulatorProvider.currentLat, -6.2088);
        expect(emulatorProvider.currentLon, 106.8456);
        expect(mockDio.recordedPostUris, isEmpty);

        // Marker / vehicle selection still works normally
        liveFleet.selectDevice(tDevice1.id);
        await pumpAndAdvance(tester, 100);
        expect(find.byType(VehicleDetailSheet), findsOneWidget);

        // 2. Activate Map-Pick via Settings > Simulator Telemetri > Pilih di Peta
        await openEmulatorViaSettings(tester);
        mockDio.recordedPostUris.clear();
        mockDio.recordedPostData.clear();
        mockDio.recordedPostOptions.clear();

        final pickBtn = find.byKey(const Key('emulator_pick_on_map_button'));
        await tester.ensureVisible(pickBtn);
        await tester.tap(pickBtn);
        await pumpAndAdvance(tester, 300);

        expect(emulatorProvider.isMapPickMode, isTrue);
        expect(find.byKey(const Key('emulator_map_pick_hud')), findsOneWidget);

        // 3. Tap map with (0.0, 0.0) -> accepted cleanly, zero auto-transmit!
        final mapWidgetOn = tester.widget<FleetMapWidget>(
          find.byType(FleetMapWidget),
        );
        mapWidgetOn.onMapClick?.call(
          const Point<double>(50, 50),
          const LatLng(0.0, 0.0),
        );
        await tester.pump();
        expect(emulatorProvider.currentLat, 0.0);
        expect(emulatorProvider.currentLon, 0.0);
        expect(mockDio.recordedPostUris, isEmpty);

        // 4. Tap map with Bandung coordinate -> updates HUD preview, still ZERO HTTP calls!
        mapWidgetOn.onMapClick?.call(
          const Point<double>(90, 90),
          const LatLng(-6.9175, 107.6191),
        );
        await tester.pump();
        expect(emulatorProvider.currentLat, -6.9175);
        expect(emulatorProvider.currentLon, 107.6191);
        expect(
          find.textContaining('-6.917500, Lon: 107.619100'),
          findsOneWidget,
        );
        expect(mockDio.recordedPostUris, isEmpty);

        // 5. Reject invalid coordinate (NaN) safely
        mapWidgetOn.onMapClick?.call(
          const Point<double>(90, 90),
          const LatLng(double.nan, 107.6191),
        );
        await pumpAndAdvance(tester, 50);
        expect(emulatorProvider.currentLat, -6.9175);
        expect(mockDio.recordedPostUris, isEmpty);

        // 6. Explicitly tap 'Kirim Titik Ini' -> sends exactly 1 POST!
        final hudSendBtn = find.byKey(
          const Key('emulator_hud_send_fix_button'),
        );
        await tester.tap(hudSendBtn);
        await pumpAndAdvance(tester, 200);
        expect(mockDio.recordedPostUris.length, 1);
        final sentForm = Uri.splitQueryString(
          mockDio.recordedPostData.single as String,
        );
        expect(sentForm['id'], 'TRK-IMEI-001');
        expect(sentForm['lat'], '-6.9175');
        expect(sentForm['lon'], '107.6191');

        // 7. Tap 'Panel Lengkap' -> opens TelemetryEmulatorSheet keeping picked coordinates!
        await tester.tap(
          find.byKey(const Key('emulator_hud_open_sheet_button')),
        );
        await pumpAndAdvance(tester, 300);
        expect(find.byType(TelemetryEmulatorSheet), findsOneWidget);
        expect(find.text('-6.917500'), findsOneWidget);
        expect(find.text('107.619100'), findsOneWidget);

        await tester.tap(find.byKey(const Key('emulator_sheet_close_button')));
        await pumpAndAdvance(tester, 300);

        // 8. Tap 'Selesai' on HUD closes Map-Pick Mode cleanly & restores VehicleDetailSheet
        await tester.tap(find.byKey(const Key('emulator_hud_done_button')));
        await pumpAndAdvance(tester, 100);
        expect(emulatorProvider.isMapPickMode, isFalse);
        expect(find.byKey(const Key('emulator_map_pick_hud')), findsNothing);
        expect(find.byType(VehicleDetailSheet), findsOneWidget);
      },
    );
  });
}
