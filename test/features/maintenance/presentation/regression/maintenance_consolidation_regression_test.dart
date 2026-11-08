import 'dart:async';
import 'package:dio/dio.dart';
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
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_device_assignment_dialog.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_form_modal.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_list_drawer.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_list_item.dart';

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
  void disconnect() {}

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
    super.dispose();
  }
}

class MockMaintenanceRepository implements MaintenanceRepository {
  final List<MaintenanceModel> mockMaintenances = [];
  final Map<int, List<MaintenanceModel>> deviceMaintenancesMap = {};
  final List<int> linkedDeviceCalls = [];
  final List<int> unlinkedDeviceCalls = [];
  int? lastDeletedId;
  MaintenanceModel? lastCreated;
  MaintenanceModel? lastUpdated;

  @override
  Future<Either<Failure, List<MaintenanceModel>>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (deviceId != null) {
      return Right(deviceMaintenancesMap[deviceId] ?? []);
    }
    return Right(List.from(mockMaintenances));
  }

  @override
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    final created = maintenance.copyWith(id: 100 + mockMaintenances.length + 1);
    lastCreated = created;
    mockMaintenances.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    lastUpdated = maintenance;
    final idx = mockMaintenances.indexWhere((m) => m.id == maintenance.id);
    if (idx >= 0) {
      mockMaintenances[idx] = maintenance;
    }
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    mockMaintenances.removeWhere((m) => m.id == id);
    deviceMaintenancesMap.forEach((_, list) {
      list.removeWhere((m) => m.id == id);
    });
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceCalls.add(deviceId);
    final current = deviceMaintenancesMap[deviceId] ?? [];
    final toAdd = mockMaintenances.firstWhere(
      (m) => m.id == maintenanceId,
      orElse: () => MaintenanceModel(
        id: maintenanceId,
        name: 'Target Maintenance',
        type: 'totalDistance',
        start: 0,
        period: 1000,
      ),
    );
    deviceMaintenancesMap[deviceId] = [...current, toAdd];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    unlinkedDeviceCalls.add(deviceId);
    final current = deviceMaintenancesMap[deviceId] ?? [];
    current.removeWhere((m) => m.id == maintenanceId);
    deviceMaintenancesMap[deviceId] = current;
    return const Right(null);
  }
}

void main() {
  group('Phase 7.8 Maintenance Scheduling - Consolidation Regression Tests', () {
    late MockAuthRepository mockAuthRepo;
    late AuthProvider authProvider;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late MockMaintenanceRepository mockMaintenanceRepo;
    late MaintenanceProvider maintenanceProvider;

    // Item 1: Overdue distance-based maintenance (period 10,000 km, device 11 at 15,000 km -> 150%)
    const tDistanceOverdue = MaintenanceModel(
      id: 1,
      name: 'Ganti Oli Mesin',
      type: 'totalDistance',
      start: 0.0,
      period: 10000000.0,
    );

    // Item 2: Warning hours-based maintenance (period 100 hours, device 12 at 95 hours -> 95%)
    const tHoursWarning = MaintenanceModel(
      id: 2,
      name: 'Servis Filter Oli 100 Jam',
      type: 'hours',
      start: 0.0,
      period: 360000000.0,
    );

    // Item 3: Normal distance-based maintenance (period 50,000 km, device 13 at 1,000 km -> 2%)
    const tNormalSchedule = MaintenanceModel(
      id: 3,
      name: 'Pemeriksaan Rutin Bulanan',
      type: 'totalDistance',
      start: 0.0,
      period: 50000000.0,
    );

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
      const DeviceModel(
        id: 13,
        name: 'Grand Max Blind Van B 3333 CC',
        uniqueId: 'VAN-03',
        category: 'van',
        status: 'offline',
      ),
    ];

    final tPos11 = PositionModel(
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
      speed: 0.0,
      course: 0.0,
      attributes: const {'totalDistance': 15000000.0},
    );

    final tPos12 = PositionModel(
      id: 102,
      deviceId: 12,
      protocol: 'osmand',
      serverTime: DateTime.now(),
      deviceTime: DateTime.now(),
      fixTime: DateTime.now(),
      valid: true,
      latitude: -6.2100,
      longitude: 106.8200,
      altitude: 10.0,
      speed: 0.0,
      course: 0.0,
      attributes: const {'hours': 342000000.0},
    );

    final tPos13 = PositionModel(
      id: 103,
      deviceId: 13,
      protocol: 'osmand',
      serverTime: DateTime.now(),
      deviceTime: DateTime.now(),
      fixTime: DateTime.now(),
      valid: true,
      latitude: -6.2200,
      longitude: 106.8300,
      altitude: 10.0,
      speed: 0.0,
      course: 0.0,
      attributes: const {'totalDistance': 1000000.0},
    );

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
        initialPositions: [tPos11, tPos12, tPos13],
      );

      mockMaintenanceRepo = MockMaintenanceRepository();
      mockMaintenanceRepo.mockMaintenances.addAll([
        tDistanceOverdue,
        tHoursWarning,
        tNormalSchedule,
      ]);

      mockMaintenanceRepo.deviceMaintenancesMap[11] = [tDistanceOverdue];
      mockMaintenanceRepo.deviceMaintenancesMap[12] = [tHoursWarning];
      mockMaintenanceRepo.deviceMaintenancesMap[13] = [tNormalSchedule];

      maintenanceProvider = MaintenanceProvider(
        repository: mockMaintenanceRepo,
      );
      await maintenanceProvider.fetchMaintenances();
      maintenanceProvider.setDeviceMaintenanceLinks(11, [1]);
      maintenanceProvider.setDeviceMaintenanceLinks(12, [2]);
      maintenanceProvider.setDeviceMaintenanceLinks(13, [3]);
      maintenanceProvider.updateDevicePositions({
        11: tPos11,
        12: tPos12,
        13: tPos13,
      });
    });

    tearDown(() {
      liveFleet.dispose();
      fakeWs.dispose();
    });

    Widget buildTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
          Provider<TraccarWebSocketService>.value(value: fakeWs),
          ChangeNotifierProvider<MaintenanceProvider>.value(
            value: maintenanceProvider,
          ),
          Provider<MaintenanceRepository>.value(value: mockMaintenanceRepo),
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
      'TC-MAINT-REG-01: Full End-to-End Cycle: Shell -> Drawer -> Filter Chips -> Debounce Search -> Item Selection',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // 1. Mount FleetShellScreen
        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 2. Open MaintenanceListDrawer via AppBar action button
        expect(
          find.byKey(const Key('maintenance_drawer_action_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('maintenance_drawer_action_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 3. Verify MaintenanceListDrawer header and initial 3 items
        expect(find.text('Jadwal Pemeliharaan'), findsOneWidget);
        expect(find.text('3 dari 3 jadwal'), findsOneWidget);
        expect(find.byType(MaintenanceListItem), findsNWidgets(3));

        // 4. Test Filter Chip: 'Jatuh Tempo' (Overdue)
        await tester.ensureVisible(
          find.widgetWithText(FilterChip, 'Jatuh Tempo'),
        );
        await tester.tap(find.widgetWithText(FilterChip, 'Jatuh Tempo'));
        await pumpAndAdvance(tester, 300);

        expect(find.byType(MaintenanceListItem), findsOneWidget);
        expect(find.text('Ganti Oli Mesin'), findsOneWidget);
        expect(find.text('Servis Filter Oli 100 Jam'), findsNothing);
        expect(find.text('Pemeriksaan Rutin Bulanan'), findsNothing);

        // 5. Test Filter Chip: 'Mendekati' (Warning)
        await tester.ensureVisible(
          find.widgetWithText(FilterChip, 'Mendekati'),
        );
        await tester.tap(find.widgetWithText(FilterChip, 'Mendekati'));
        await pumpAndAdvance(tester, 300);

        expect(find.byType(MaintenanceListItem), findsOneWidget);
        expect(find.text('Servis Filter Oli 100 Jam'), findsOneWidget);
        expect(find.text('Ganti Oli Mesin'), findsNothing);

        // 6. Test Filter Chip: 'Normal'
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Normal'));
        await tester.tap(find.widgetWithText(FilterChip, 'Normal'));
        await pumpAndAdvance(tester, 300);

        expect(find.byType(MaintenanceListItem), findsOneWidget);
        expect(find.text('Pemeriksaan Rutin Bulanan'), findsOneWidget);

        // 7. Restore to 'Semua'
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Semua'));
        await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
        await pumpAndAdvance(tester, 300);
        expect(find.byType(MaintenanceListItem), findsNWidgets(3));

        // 8. Test Debounced Search
        final searchField = find.byKey(
          const Key('maintenance_drawer_search_field'),
        );
        await tester.enterText(searchField, 'oli');
        await tester.pump(const Duration(milliseconds: 50));
        // Before 200ms debounce:
        expect(find.byType(MaintenanceListItem), findsNWidgets(3));

        // After 200ms debounce:
        await pumpAndAdvance(tester, 300);
        // Both "Ganti Oli Mesin" and "Servis Filter Oli 100 Jam" contain "oli"
        expect(find.byType(MaintenanceListItem), findsNWidgets(2));
        expect(find.text('Ganti Oli Mesin'), findsOneWidget);
        expect(find.text('Servis Filter Oli 100 Jam'), findsOneWidget);
        expect(find.text('Pemeriksaan Rutin Bulanan'), findsNothing);

        // 9. Tap item to select
        await tester.tap(find.text('Ganti Oli Mesin'));
        await pumpAndAdvance(tester, 200);
        expect(maintenanceProvider.selectedMaintenance?.id, equals(1));
      },
    );

    testWidgets(
      'TC-MAINT-REG-02: Maintenance Creation Lifecycle: Form Modal -> Unit Conversion -> Add & Reflect',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open Maintenance Drawer
        await tester.tap(
          find.byKey(const Key('maintenance_drawer_action_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 2. Tap Add (+) button
        await tester.tap(
          find.byKey(const Key('maintenance_drawer_add_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 3. Verify MaintenanceFormModal opened
        expect(find.byType(MaintenanceFormModal), findsOneWidget);
        expect(find.text('Tambah Jadwal Pemeliharaan'), findsOneWidget);

        // 4. Fill required form inputs
        final nameField = find.byKey(const Key('maintenance_form_name_field'));
        await tester.enterText(nameField, 'Ganti Minyak Rem');

        final startField = find.byKey(
          const Key('maintenance_form_start_field'),
        );
        await tester.enterText(startField, '5000');

        final periodField = find.byKey(
          const Key('maintenance_form_period_field'),
        );
        await tester.enterText(periodField, '20000');

        // 5. Submit form
        await tester.ensureVisible(
          find.byKey(const Key('maintenance_form_submit_button')),
        );
        await tester.tap(
          find.byKey(const Key('maintenance_form_submit_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 6. Verify schedule was created and added to repository with unit conversions
        expect(mockMaintenanceRepo.mockMaintenances.length, equals(4));
        final created = mockMaintenanceRepo.lastCreated;
        expect(created, isNotNull);
        expect(created?.name, equals('Ganti Minyak Rem'));
        expect(created?.type, equals('totalDistance'));
        // 5,000 km * 1000 = 5,000,000 meters
        expect(created?.start, equals(5000000.0));
        // 20,000 km * 1000 = 20,000,000 meters
        expect(created?.period, equals(20000000.0));

        // Drawer list updated to 4 / 4
        expect(find.text('4 dari 4 jadwal'), findsOneWidget);
        expect(find.text('Ganti Minyak Rem'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAINT-REG-03: Multi-Vehicle Assignment & Permissions Reconciliation Diffing',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open Maintenance Drawer
        await tester.tap(
          find.byKey(const Key('maintenance_drawer_action_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 2. Open context menu on first maintenance (Ganti Oli Mesin)
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Tautkan Kendaraan'
        await tester.tap(find.text('Tautkan Kendaraan'));
        await pumpAndAdvance(tester, 400);

        // 4. Verify MaintenanceDeviceAssignmentDialog is shown
        expect(find.byType(MaintenanceDeviceAssignmentDialog), findsOneWidget);
        expect(find.text('Tautkan Armada'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MaintenanceDeviceAssignmentDialog),
            matching: find.text('Ganti Oli Mesin'),
          ),
          findsOneWidget,
        );
        expect(find.text('1 dari 3 terpilih'), findsOneWidget);

        // 5. Select Device 12 (Truk Isuzu Giga) -> new link
        await tester.tap(find.byKey(const Key('maintenance_device_tile_12')));
        await pumpAndAdvance(tester, 100);

        // 6. Unselect Device 11 (Truk Hino Dutro) -> unlink
        await tester.tap(find.byKey(const Key('maintenance_device_tile_11')));
        await pumpAndAdvance(tester, 100);

        // 7. Save assignment
        await tester.tap(
          find.byKey(const Key('maintenance_save_assignments_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 8. Verify REST permissions diffing endpoints invoked
        expect(mockMaintenanceRepo.linkedDeviceCalls, contains(12));
        expect(mockMaintenanceRepo.unlinkedDeviceCalls, contains(11));
      },
    );

    testWidgets(
      'TC-MAINT-REG-04: Telemetry & Due Badges Integration on VehicleDetailSheet',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Select Device 11 (linked to overdue schedule: Ganti Oli Mesin)
        liveFleet.selectDevice(11);
        await pumpAndAdvance(tester, 300);

        // Verify VehicleDetailSheet is displayed
        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(VehicleDetailSheet),
            matching: find.text('Truk Hino Dutro B 1111 AA'),
          ),
          findsOneWidget,
        );

        // Verify Overdue badge is displayed with "Servis Jatuh Tempo"
        expect(
          find.byKey(const Key('vehicle_sheet_maintenance_badge')),
          findsOneWidget,
        );
        expect(find.text('Servis Jatuh Tempo'), findsOneWidget);

        // 2. Select Device 12 (linked to warning schedule: Servis Filter Oli 100 Jam)
        liveFleet.selectDevice(12);
        await pumpAndAdvance(tester, 300);

        expect(
          find.descendant(
            of: find.byType(VehicleDetailSheet),
            matching: find.text('Truk Isuzu Giga B 2222 BB'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('vehicle_sheet_maintenance_badge')),
          findsOneWidget,
        );
        expect(find.text('Jadwal Servis Mendekati'), findsOneWidget);

        // 3. Select Device 13 (linked to normal schedule: Pemeriksaan Rutin Bulanan)
        liveFleet.selectDevice(13);
        await pumpAndAdvance(tester, 300);

        expect(
          find.descendant(
            of: find.byType(VehicleDetailSheet),
            matching: find.text('Grand Max Blind Van B 3333 CC'),
          ),
          findsOneWidget,
        );
        // Normal schedule should NOT show a due badge
        expect(
          find.byKey(const Key('vehicle_sheet_maintenance_badge')),
          findsNothing,
        );
        expect(find.text('Servis Jatuh Tempo'), findsNothing);
        expect(find.text('Jadwal Servis Mendekati'), findsNothing);

        // 4. PopScope verification: back gesture dismisses sheet without popping route
        liveFleet.selectDevice(null);
        await pumpAndAdvance(tester, 200);
        expect(find.byType(VehicleDetailSheet), findsNothing);
      },
    );

    testWidgets('TC-MAINT-REG-05: Quick Service Reset Action via Popup Menu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await pumpAndAdvance(tester, 100);

      // 1. Open Maintenance Drawer
      await tester.tap(
        find.byKey(const Key('maintenance_drawer_action_button')),
      );
      await pumpAndAdvance(tester, 400);

      // 2. Tap options on first item (Ganti Oli Mesin)
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await pumpAndAdvance(tester, 300);

      // 3. Tap 'Reset Servis'
      await tester.tap(find.text('Reset Servis'));
      await pumpAndAdvance(tester, 300);

      // 4. Verify Reset Confirmation dialog
      expect(find.text('Reset Siklus Servis'), findsOneWidget);
      expect(
        find.textContaining('Perbarui nilai awal jadwal "Ganti Oli Mesin"'),
        findsOneWidget,
      );

      // 5. Confirm reset
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Servis'));
      await pumpAndAdvance(tester, 400);

      // 6. Verify repository update called with new start value from telemetry
      expect(mockMaintenanceRepo.lastUpdated, isNotNull);
      expect(mockMaintenanceRepo.lastUpdated?.id, equals(1));
      // Telemetry totalDistance for device 11 is 15,000,000.0 meters
      expect(mockMaintenanceRepo.lastUpdated?.start, equals(15000000.0));
    });

    testWidgets(
      'TC-MAINT-REG-06: Maintenance Deletion with Confirmation & State Cleanup on Logout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open Drawer
        await tester.tap(
          find.byKey(const Key('maintenance_drawer_action_button')),
        );
        await pumpAndAdvance(tester, 400);

        expect(find.text('3 dari 3 jadwal'), findsOneWidget);

        // 2. Tap options on third maintenance (Pemeriksaan Rutin Bulanan)
        await tester.tap(find.byType(PopupMenuButton<String>).last);
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Hapus'
        await tester.tap(find.text('Hapus'));
        await pumpAndAdvance(tester, 300);

        // 4. Confirmation dialog shown
        expect(find.text('Hapus Jadwal Pemeliharaan'), findsOneWidget);
        expect(
          find.textContaining('Apakah Anda yakin ingin menghapus jadwal'),
          findsOneWidget,
        );

        // 5. Confirm deletion
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await pumpAndAdvance(tester, 400);

        // 6. Verify deleted
        expect(mockMaintenanceRepo.lastDeletedId, equals(3));
        expect(mockMaintenanceRepo.mockMaintenances.length, equals(2));
        expect(find.text('2 dari 2 jadwal'), findsOneWidget);
        expect(find.text('Pemeriksaan Rutin Bulanan'), findsNothing);

        // 7. Close drawer by tapping close icon
        await tester.tap(find.byTooltip('Tutup'));
        await pumpAndAdvance(tester, 400);
        expect(find.byType(MaintenanceListDrawer), findsNothing);

        // 8. Tap Logout in Shell AppBar
        expect(find.byIcon(Icons.logout), findsOneWidget);
        await tester.tap(find.byIcon(Icons.logout));
        await pumpAndAdvance(tester, 300);

        // 9. Verify session cleanup: logout executed and provider state cleared
        expect(mockAuthRepo.logoutCalled, isTrue);
        expect(maintenanceProvider.maintenances, isEmpty);
        expect(maintenanceProvider.selectedMaintenance, isNull);
        expect(maintenanceProvider.searchQuery, isEmpty);
        expect(maintenanceProvider.selectedAlertFilter, equals('all'));
      },
    );
  });
}
