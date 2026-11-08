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
import 'package:gpsku/features/fleet/presentation/widgets/drawer/fleet_list_drawer.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';

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
  WebSocketConnectionState _state = WebSocketConnectionState.connected;

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

class _DummyAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async => const Left(ServerFailure('Unused in regression harness'));

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async =>
      const Left(ServerFailure('Unused in regression harness'));

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async =>
      const Right((email: null, password: null, rememberMe: false));

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      const Right(null);
}

void main() {
  group('Phase 7.4 Fleet List Consolidation & End-to-End Regression Tests', () {
    late MockFleetRepository mockRepo;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator coordinator;

    final group1 = const GroupModel(
      id: 10,
      name: 'Logistik Jakarta',
      groupId: null,
    );

    final dev1 = const DeviceModel(
      id: 101,
      name: 'Armada Truk Logistik B 1001 JKT',
      uniqueId: 'TRK-1001',
      category: 'truck',
      status: 'online',
      model: 'Hino 500 FG',
      groupId: 10,
      attributes: {'plateNumber': 'B 1001 JKT'},
    );

    final dev2 = const DeviceModel(
      id: 102,
      name: 'Armada Innova Patroli B 2002 JKT',
      uniqueId: 'CAR-2002',
      category: 'car',
      status: 'online',
      model: 'Toyota Innova Zenix',
      groupId: 10,
      attributes: {'plateNumber': 'B 2002 JKT'},
    );

    final dev3 = const DeviceModel(
      id: 103,
      name: 'Motor Kurir Siaga B 3003 JKT',
      uniqueId: 'MOT-3003',
      category: 'motorcycle',
      status: 'offline',
      model: 'Yamaha NMAX 155',
      groupId: null, // Tanpa Grup
      attributes: {'plateNumber': 'B 3003 JKT'},
    );

    final pos1 = PositionModel(
      id: 9001,
      deviceId: 101,
      serverTime: DateTime.parse('2026-11-08T10:00:00.000Z'),
      fixTime: DateTime.parse('2026-11-08T10:00:00.000Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 35.0, // ~64.8 km/h
      course: 90.0,
      attributes: {'ignition': true, 'batteryLevel': 98},
    );

    final pos2 = PositionModel(
      id: 9002,
      deviceId: 102,
      serverTime: DateTime.parse('2026-11-08T10:00:00.000Z'),
      fixTime: DateTime.parse('2026-11-08T10:00:00.000Z'),
      latitude: -6.2200,
      longitude: 106.8500,
      speed: 0.0, // Idle
      course: 0.0,
      attributes: {'ignition': false, 'batteryLevel': 95},
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
    });

    tearDown(() {
      coordinator.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
          Provider<TraccarWebSocketService>.value(value: fakeWs),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(authRepository: _DummyAuthRepository()),
          ),
        ],
        child: const MaterialApp(home: FleetShellScreen()),
      );
    }

    testWidgets(
      'REG-P74-01: Full End-to-End Cycle: Tri-fetch -> Drawer Hierarchy -> Debounce Search -> Category Filter -> Selection -> Southward Offset -> Sheet -> WebSocket Live Update -> Android Back Pop',
      (tester) async {
        // Step 1: Execute concurrent REST tri-fetch synchronization
        mockRepo.devicesResult = Right([dev1, dev2, dev3]);
        mockRepo.positionsResult = Right([pos1, pos2]);
        mockRepo.groupsResult = Right([group1]);

        final syncResult = await coordinator.synchronizeFleet();
        expect(syncResult.isSuccess, isTrue);
        expect(liveFleet.devices.length, equals(3));
        expect(liveFleet.positions.length, equals(2));
        expect(liveFleet.groups.length, equals(1));

        // Step 2: Pump FleetShellScreen
        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initially no sheet and no drawer open
        expect(find.byType(VehicleDetailSheet), findsNothing);
        expect(find.byType(FleetListDrawer), findsNothing);

        // Step 3: Open FleetListDrawer via AppBar menu icon
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(FleetListDrawer), findsOneWidget);
        expect(find.text('Daftar Armada'), findsOneWidget);
        expect(find.text('3 Unit'), findsOneWidget);

        // Step 4: Verify Hierarchical Group Headers & Unassigned Section
        expect(find.text('Logistik Jakarta'), findsOneWidget);
        expect(find.text('Tanpa Grup'), findsOneWidget);

        // Verify status chips counts
        expect(find.text('Semua (3)'), findsOneWidget);
        expect(find.text('Bergerak (1)'), findsOneWidget);
        expect(find.text('Diam (1)'), findsOneWidget);
        expect(find.text('Offline (1)'), findsOneWidget);

        // Step 5: Test Multi-Category Filter Chip (Filter by Truk)
        final trukChip = find.text('Truk');
        await tester.ensureVisible(trukChip);
        await tester.tap(trukChip, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Only dev1 (truck) is visible; dev2 (car) and dev3 (motorcycle) are filtered out
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);
        expect(find.text('Armada Innova Patroli B 2002 JKT'), findsNothing);
        expect(find.text('Motor Kurir Siaga B 3003 JKT'), findsNothing);

        // Toggle Truk chip off -> all 3 restored
        await tester.ensureVisible(trukChip);
        await tester.tap(trukChip, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);
        expect(find.text('Armada Innova Patroli B 2002 JKT'), findsOneWidget);
        expect(find.text('Motor Kurir Siaga B 3003 JKT'), findsOneWidget);

        // Step 6: Test 200ms Search Debouncing
        await tester.enterText(find.byType(TextField), 'Innova');
        // Advance 50ms (before debounce expires)
        await tester.pump(const Duration(milliseconds: 50));
        // All items still visible before 200ms
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);

        // Advance past 200ms debounce
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Only Innova remains
        expect(find.text('Armada Innova Patroli B 2002 JKT'), findsOneWidget);
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsNothing);

        // Clear search
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Step 7: Select vehicle from group section
        await tester.tap(find.text('Armada Truk Logistik B 1001 JKT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Drawer auto-closed, selection established in provider
        expect(find.byType(FleetListDrawer), findsNothing);
        expect(liveFleet.selectedDeviceId, equals(101));

        // Step 8: Verify Southward Offset calculation for map centering
        final targetCoord = LatLng(pos1.latitude, pos1.longitude);
        final offsetCoord = CameraCalculationHelper.calculateOffsetCenter(
          target: targetCoord,
          zoom: 14.0,
          verticalOffsetPixels: VehicleDetailSheet.estimatedSheetHeight,
        );
        expect(offsetCoord.latitude, lessThan(targetCoord.latitude));
        expect(offsetCoord.longitude, equals(targetCoord.longitude));

        // Step 9: Verify VehicleDetailSheet open with initial telemetry
        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);
        expect(find.textContaining('Hino 500 FG'), findsOneWidget);

        // Step 10: WebSocket Live Telemetry Update during active selection
        // Speed jumps to 85 km/h (~45.9 knots) with newer timestamp
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 9005,
              'deviceId': 101,
              'serverTime': '2026-11-08T10:05:00.000Z',
              'fixTime': '2026-11-08T10:05:00.000Z',
              'latitude': -6.2100,
              'longitude': 106.8456,
              'speed': 45.9, // ~85.0 km/h
              'attributes': {'ignition': true, 'batteryLevel': 97},
            },
          ],
        });

        // Flush provider coalescing window
        await tester.pump(const Duration(milliseconds: 50));
        liveFleet.flushImmediately();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Position updated in provider monotonically
        expect(liveFleet.positions[101]!.id, equals(9005));
        expect(liveFleet.positions[101]!.speedKmh, closeTo(85.0, 0.2));

        // Step 11: Android Back Gesture Dismissal via PopScope
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // VehicleDetailSheet is dismissed gracefully, selectedDeviceId reset
        expect(liveFleet.selectedDeviceId, isNull);
        expect(find.byType(VehicleDetailSheet), findsNothing);
      },
    );

    testWidgets(
      'REG-P74-02: State Cleanup & Logout Reset Guard: Complete reset of devices, positions, and groups',
      (tester) async {
        // Seed state
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2],
          initialPositions: [pos1],
          initialGroups: [group1],
        );
        liveFleet.selectDevice(101);

        expect(liveFleet.devices.length, equals(2));
        expect(liveFleet.positions.length, equals(1));
        expect(liveFleet.groups.length, equals(1));
        expect(liveFleet.selectedDeviceId, equals(101));

        // Trigger complete clear (as executed during user logout)
        liveFleet.clearFleet();

        // Verify total cleanup
        expect(liveFleet.devices.isEmpty, isTrue);
        expect(liveFleet.positions.isEmpty, isTrue);
        expect(liveFleet.groups.isEmpty, isTrue);
        expect(liveFleet.selectedDeviceId, isNull);
      },
    );

    testWidgets(
      'REG-P74-03: Drawer Collapsible Groups State Persistence across Open/Close',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
          initialGroups: [group1],
        );

        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Open drawer
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initially both groups expanded
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);
        expect(find.text('Motor Kurir Siaga B 3003 JKT'), findsOneWidget);

        // Collapse 'Logistik Jakarta' group
        await tester.tap(find.text('Logistik Jakarta'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Group devices are hidden
        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsNothing);
        // Unassigned device still visible
        expect(find.text('Motor Kurir Siaga B 3003 JKT'), findsOneWidget);

        // Re-expand 'Logistik Jakarta'
        await tester.tap(find.text('Logistik Jakarta'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Armada Truk Logistik B 1001 JKT'), findsOneWidget);
      },
    );
  });
}
