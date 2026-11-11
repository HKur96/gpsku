import 'dart:async';
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
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_marker_manager.dart';
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';

class MockFleetRepository implements FleetRepository {
  Either<Failure, List<DeviceModel>> devicesResult = const Right([]);
  Either<Failure, List<PositionModel>> positionsResult = const Right([]);
  Either<Failure, List<GroupModel>> groupsResult = const Right([]);
  int getDevicesCallCount = 0;

  @override
  Future<Either<Failure, List<DeviceModel>>> getDevices({
    CancelToken? cancelToken,
  }) async {
    getDevicesCallCount++;
    return devicesResult;
  }

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
  WebSocketConnectionState _state = WebSocketConnectionState.connected;
  int connectCallCount = 0;
  int disconnectCallCount = 0;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => _state;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  bool get isConnected => _state == WebSocketConnectionState.connected;

  void emitMessage(Map<String, dynamic> msg) => _msgController.add(msg);
  void emitState(WebSocketConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  void disconnect() {
    disconnectCallCount++;
  }

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
    super.dispose();
  }
}

class FakeMapSymbolController implements MapSymbolController {
  final List<Symbol> addedSymbols = [];
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Symbol> removedSymbols = [];
  final List<void Function(Symbol)> tappedListeners = [];
  int _nextSymbolId = 1;

  @override
  bool get isDisposed => false;

  @override
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) async {
    final sym = Symbol('sym_${_nextSymbolId++}', options, data);
    addedSymbols.add(sym);
    return sym;
  }

  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {
    updateCalls.add({'symbol': symbol, 'changes': changes});
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    removedSymbols.add(symbol);
    addedSymbols.remove(symbol);
  }

  @override
  Future<void> removeSymbols(Iterable<Symbol> symbols) async {}

  @override
  Future<void> clearSymbols() async {}

  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {
    tappedListeners.add(listener);
  }

  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {
    tappedListeners.remove(listener);
  }

  void simulateTap(Symbol symbol) {
    for (final l in List.of(tappedListeners)) {
      l(symbol);
    }
  }
}

void main() {
  group('Phase 7.3 Consolidation & End-to-End Regression Tests', () {
    late MockFleetRepository mockRepo;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator coordinator;
    late FleetMarkerManager markerManager;
    late FakeMapSymbolController fakeMap;

    final initialDevice = const DeviceModel(
      id: 77,
      name: 'Armada Tanggap Darurat B 9999 SOS',
      uniqueId: 'EMERGENCY-01',
      category: 'truck',
      status: 'online',
      model: 'Isuzu Elf 4x4',
    );

    final initialPosition = PositionModel(
      id: 7001,
      deviceId: 77,
      serverTime: DateTime.parse('2026-11-08T09:00:00.000Z'),
      fixTime: DateTime.parse('2026-11-08T09:00:00.000Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 21.6, // ~40.0 km/h
      course: 180.0,
      address: 'Jl. MH Thamrin No. 1, Jakarta Pusat',
      attributes: {'ignition': true, 'batteryLevel': 95},
    );

    setUp(() {
      mockRepo = MockFleetRepository();
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 10),
      );
      coordinator = InitialFleetSyncCoordinator(
        fleetRepository: mockRepo,
        liveFleetProvider: liveFleet,
        webSocketService: fakeWs,
        autoListenReconnection: false,
      );
      markerManager = FleetMarkerManager();
      fakeMap = FakeMapSymbolController();
    });

    tearDown(() {
      coordinator.dispose();
      markerManager.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    test(
      'REG-01: End-to-End Lifecycle: Sync -> Render Symbols -> Tap Marker -> Southward Offset -> Realtime WS Update -> Dismiss',
      () async {
        // 1. Initial REST Dual-Fetch Synchronization
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);

        final syncResult = await coordinator.synchronizeFleet();
        expect(syncResult.isSuccess, isTrue);
        expect(liveFleet.devices.containsKey(77), isTrue);

        // 2. Attach Marker Manager and verify symbol rendered on MapLibre
        markerManager.attachController(fakeMap, fleetProvider: liveFleet);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.symbolCount, equals(1));
        expect(fakeMap.addedSymbols.length, equals(1));
        final initialSymbol = fakeMap.addedSymbols.first;
        expect(initialSymbol.options.iconImage, equals('truck-success'));
        expect(initialSymbol.options.zIndex, equals(1));
        expect(markerManager.getRenderedRotation(77), equals(180.0));

        // 3. User taps marker on map canvas -> triggers selection & southward offset
        fakeMap.simulateTap(initialSymbol);
        await Future.delayed(const Duration(milliseconds: 20));

        // Selection reflected
        expect(liveFleet.selectedDeviceId, equals(77));
        // Selected marker elevated to z-index 100 with info styling
        expect(markerManager.getRenderedIconId(77), equals('truck-info'));

        // 4. Verify southward camera offset for Indonesia coordinates (-6.2088)
        const target = LatLng(-6.2088, 106.8456);
        final offsetCenter = CameraCalculationHelper.calculateOffsetCenter(
          target: target,
          zoom: 14.0,
          verticalOffsetPixels: VehicleDetailSheet.estimatedSheetHeight,
        );
        expect(offsetCenter.latitude, lessThan(target.latitude));
        expect(offsetCenter.longitude, equals(target.longitude));

        // 5. Real-time Telemetry arrives over WebSocket while vehicle is selected
        // Vehicle speeds up to 80 km/h (43.2 knots), changes course to North (0°), ignition remains true
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 7002,
              'deviceId': 77,
              'fixTime': DateTime.parse(
                '2026-11-08T09:00:05.000Z',
              ).toIso8601String(),
              'serverTime': DateTime.parse(
                '2026-11-08T09:00:05.000Z',
              ).toIso8601String(),
              'latitude': -6.2000,
              'longitude': 106.8456,
              'speed': 43.2,
              'course': 0.0,
              'attributes': {'ignition': true, 'batteryLevel': 94},
            },
          ],
        });

        // Allow 10ms coalescing buffer + microtask to flush
        await Future.delayed(const Duration(milliseconds: 25));

        // Verified in provider
        expect(liveFleet.positions[77]!.id, equals(7002));
        expect(liveFleet.positions[77]!.speedKmh, closeTo(80.0, 0.1));

        // Marker updated in-place (no new additions)
        expect(fakeMap.addedSymbols.length, equals(1));
        expect(fakeMap.updateCalls.length, greaterThanOrEqualTo(1));
        expect(
          markerManager.getRenderedCoordinate(77),
          equals(const LatLng(-6.2000, 106.8456)),
        );
        expect(markerManager.getRenderedRotation(77), equals(0.0));

        // 6. User dismisses sheet -> resets selection
        liveFleet.selectDevice(null);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(liveFleet.selectedDeviceId, isNull);
        // Marker reverts to normal truck-success status and z-index 1
        expect(markerManager.getRenderedIconId(77), equals('truck-success'));
      },
    );

    testWidgets(
      'REG-02: PopScope intercepts Android Back gesture to dismiss sheet when open',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [initialDevice],
          initialPositions: [initialPosition],
        );

        // Mount FleetShellScreen with AuthProvider & LiveFleetProvider
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
              Provider<TraccarWebSocketService>.value(value: fakeWs),
              ChangeNotifierProvider<AuthProvider>(
                create: (_) =>
                    AuthProvider(authRepository: _DummyAuthRepository()),
              ),
            ],
            child: const MaterialApp(home: FleetShellScreen()),
          ),
        );

        // Initial: No sheet open
        expect(find.byType(VehicleDetailSheet), findsNothing);

        // Select Device 77 -> VehicleDetailSheet opens
        liveFleet.selectDevice(77);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(find.text('Armada Tanggap Darurat B 9999 SOS'), findsOneWidget);

        // Simulate Android Back Gesture / System Pop
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));

        // Sheet is dismissed, selectedDeviceId is reset to null!
        expect(liveFleet.selectedDeviceId, isNull);
        expect(find.byType(VehicleDetailSheet), findsNothing);
      },
    );

    test(
      'REG-03: Lifecycle Clean-up: No lingering listeners or memory leaks on dispose',
      () {
        final localWs = FakeWebSocketService();
        final localFleet = LiveFleetProvider(
          webSocketService: localWs,
          coalescingWindow: const Duration(milliseconds: 10),
        );
        final localMarkerManager = FleetMarkerManager();
        final localFakeMap = FakeMapSymbolController();

        localMarkerManager.attachController(
          localFakeMap,
          fleetProvider: localFleet,
        );
        expect(localFakeMap.tappedListeners.length, equals(1));

        // Detach and verify complete cleanup
        localMarkerManager.dispose();
        expect(localMarkerManager.isReady, isFalse);
        expect(localMarkerManager.symbolCount, equals(0));
        expect(localFakeMap.tappedListeners.isEmpty, isTrue);

        // Provider dispose cleans flush timer and socket subscriptions
        localFleet.dispose();
        expect(localFleet.devices.isEmpty, isTrue);

        localWs.dispose();
      },
    );

    testWidgets(
      'REG-04: AUD-01: FleetShellScreen defers initial sync until authenticated, avoids duplicate ws.connect(), and resets coordinator on logout cleanly',
      (tester) async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);

        final authRepo = _ControllableAuthRepository();
        final authProvider = AuthProvider(authRepository: authRepo);

        Widget buildShellApp() => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
            Provider<TraccarWebSocketService>.value(value: fakeWs),
            ChangeNotifierProvider<InitialFleetSyncCoordinator>.value(
              value: coordinator,
            ),
          ],
          child: const MaterialApp(home: FleetShellScreen()),
        );

        // 1. Mount before authentication completes -> ZERO premature sync or WS connect
        await tester.pumpWidget(buildShellApp());
        await tester.pump(const Duration(milliseconds: 50));

        expect(authProvider.isAuthenticated, isFalse);
        expect(mockRepo.getDevicesCallCount, equals(0));
        expect(fakeWs.connectCallCount, equals(0));
        expect(liveFleet.devices, isEmpty);

        // 2. Complete authentication -> triggers InitialFleetSyncCoordinator once
        final loggedIn = await authProvider.login(
          email: 'admin@gps.local',
          password: 'secret',
        );
        expect(loggedIn, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(mockRepo.getDevicesCallCount, equals(1));
        expect(fakeWs.connectCallCount, equals(1));
        expect(coordinator.isReady, isTrue);
        expect(liveFleet.devices[77]?.uniqueId, equals('EMERGENCY-01'));
        expect(liveFleet.positions[77]?.id, equals(7001));

        // 3. Logout resets coordinator & clears fleet without breaking singleton lifecycle
        await tester.tap(find.byKey(const Key('fleet_app_bar_logout_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeWs.disconnectCallCount, equals(1));
        expect(liveFleet.devices, isEmpty);
        expect(coordinator.syncState, equals(FleetSyncState.notInitialized));
        expect(authProvider.isAuthenticated, isFalse);

        // 4. Re-login -> coordinator synchronizes cleanly again once
        await authProvider.login(email: 'admin@gps.local', password: 'secret');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(mockRepo.getDevicesCallCount, equals(2));
        expect(fakeWs.connectCallCount, equals(2));
        expect(liveFleet.devices[77]?.uniqueId, equals('EMERGENCY-01'));

        authProvider.dispose();
      },
    );

    testWidgets(
      'REG-05: AUD-01 Fallback: FleetShellScreen connects WebSocket directly only when InitialFleetSyncCoordinator is unavailable',
      (tester) async {
        final authProvider = AuthProvider(
          authRepository: _DummyAuthRepository(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
              Provider<TraccarWebSocketService>.value(value: fakeWs),
            ],
            child: const MaterialApp(home: FleetShellScreen()),
          ),
        );
        await tester.pump();

        expect(fakeWs.connectCallCount, equals(1));
        authProvider.dispose();
      },
    );
  });
}

class _ControllableAuthRepository implements AuthRepository {
  static const _adminUser = UserModel(
    id: 1,
    name: 'Admin',
    email: 'admin@gps.local',
    administrator: true,
    readonly: false,
  );

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async => const Right(_adminUser);

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async =>
      const Right(_adminUser);

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async =>
      const Right((email: null, password: null, rememberMe: false));

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);
}

class _DummyAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async => const Left(ServerFailure('Unused dummy'));

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async =>
      const Left(ServerFailure('Unused dummy'));

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async =>
      const Right((email: null, password: null, rememberMe: false));

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);
}
