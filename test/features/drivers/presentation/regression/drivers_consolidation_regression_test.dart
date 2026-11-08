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
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/domain/repositories/drivers_repository.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_device_assignment_dialog.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_form_modal.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_list_drawer.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_list_item.dart';

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

class MockDriversRegressionRepository implements DriversRepository {
  final List<DriverModel> mockDrivers = [];
  final Map<int, List<DriverModel>> deviceDriversMap = {};
  final List<({int deviceId, int driverId})> linkedDeviceCalls = [];
  final List<({int deviceId, int driverId})> unlinkedDeviceCalls = [];
  int? lastDeletedId;

  @override
  Future<Either<Failure, List<DriverModel>>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (deviceId != null) {
      return Right(deviceDriversMap[deviceId] ?? []);
    }
    return Right(List.unmodifiable(mockDrivers));
  }

  @override
  Future<Either<Failure, DriverModel>> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    final created = driver.copyWith(
      id: driver.id == 0 ? mockDrivers.length + 100 : driver.id,
    );
    mockDrivers.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, DriverModel>> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    final idx = mockDrivers.indexWhere((d) => d.id == driver.id);
    if (idx != -1) {
      mockDrivers[idx] = driver;
    }
    return Right(driver);
  }

  @override
  Future<Either<Failure, void>> deleteDriver(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    mockDrivers.removeWhere((d) => d.id == id);
    deviceDriversMap.forEach((_, list) {
      list.removeWhere((d) => d.id == id);
    });
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceCalls.add((deviceId: deviceId, driverId: driverId));
    final current = deviceDriversMap[deviceId] ?? [];
    final driver = mockDrivers.firstWhere(
      (d) => d.id == driverId,
      orElse: () => DriverModel(
        id: driverId,
        name: 'Target Driver',
        uniqueId: 'TAG-$driverId',
      ),
    );
    if (!current.any((d) => d.id == driverId)) {
      deviceDriversMap[deviceId] = [...current, driver];
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    unlinkedDeviceCalls.add((deviceId: deviceId, driverId: driverId));
    final current = deviceDriversMap[deviceId] ?? [];
    deviceDriversMap[deviceId] = current
        .where((d) => d.id != driverId)
        .toList();
    return const Right(null);
  }
}

void main() {
  group('Phase 7.9 Driver Management & RFID - Consolidation Regression Tests', () {
    late MockAuthRepository mockAuthRepo;
    late AuthProvider authProvider;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late MockDriversRegressionRepository mockDriversRepo;
    late DriversProvider driversProvider;

    // Test Driver 1
    const tDriver1 = DriverModel(
      id: 1,
      name: 'Budi Santoso',
      uniqueId: 'RFID-1001',
      attributes: {'phone': '08123456789', 'license': 'B1-123456'},
    );

    // Test Driver 2
    const tDriver2 = DriverModel(
      id: 2,
      name: 'Agus Setiawan',
      uniqueId: 'RFID-1002',
      attributes: {'phone': '08198765432', 'license': 'B2-654321'},
    );

    // Test Driver 3
    const tDriver3 = DriverModel(
      id: 3,
      name: 'Doni Pratama',
      uniqueId: 'IBUTTON-3003',
      attributes: {'phone': '0855112233', 'license': 'A-987654'},
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

    // Position for Device 11: plain position without RFID
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
      attributes: const {},
    );

    // Position for Device 12: telemetry contains RFID-1002 (matching tDriver2)
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
      attributes: const {'driverUniqueId': 'RFID-1002'},
    );

    // Position for Device 13: plain position without RFID
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
      attributes: const {},
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

      mockDriversRepo = MockDriversRegressionRepository();
      mockDriversRepo.mockDrivers.addAll([tDriver1, tDriver2, tDriver3]);

      // Seed initial permissions:
      // Device 11 initially assigned to Driver 1 (Budi)
      // Device 13 initially assigned to Driver 3 (Doni)
      mockDriversRepo.deviceDriversMap[11] = [tDriver1];
      mockDriversRepo.deviceDriversMap[13] = [tDriver3];

      driversProvider = DriversProvider(repository: mockDriversRepo);
      await driversProvider.fetchDrivers();
      driversProvider.setDeviceDriverLinks(11, [1]);
      driversProvider.setDeviceDriverLinks(13, [3]);
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
          ChangeNotifierProvider<DriversProvider>.value(value: driversProvider),
          Provider<DriversRepository>.value(value: mockDriversRepo),
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
      'TC-DRI-REG-01: Full End-to-End Navigation Cycle: Shell -> Drawer -> Debounced Search -> Clear Filter -> Selection',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // 1. Mount FleetShellScreen
        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 2. Open DriverListDrawer via AppBar action button
        expect(
          find.byKey(const Key('driver_drawer_action_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('driver_drawer_action_button')));
        await pumpAndAdvance(tester, 400);

        // 3. Verify DriverListDrawer header and initial 3 drivers
        expect(find.byType(DriverListDrawer), findsOneWidget);
        expect(find.text('Daftar Pengemudi'), findsOneWidget);
        expect(find.text('3 Supir'), findsOneWidget);
        expect(find.byType(DriverListItem), findsNWidgets(3));

        // 4. Test Debounced Search by name: 'budi'
        final searchField = find.byKey(const Key('driver_drawer_search_field'));
        await tester.enterText(searchField, 'budi');
        await tester.pump(const Duration(milliseconds: 50));
        // Before 200ms debounce completes:
        expect(find.byType(DriverListItem), findsNWidgets(3));

        // After 200ms debounce completes:
        await pumpAndAdvance(tester, 300);
        expect(find.byType(DriverListItem), findsOneWidget);
        expect(find.text('Budi Santoso'), findsOneWidget);
        expect(find.text('Agus Setiawan'), findsNothing);
        expect(find.text('Doni Pratama'), findsNothing);

        // 5. Test Debounced Search by RFID identifier: '3003'
        await tester.enterText(searchField, '3003');
        await pumpAndAdvance(tester, 300);
        expect(find.byType(DriverListItem), findsOneWidget);
        expect(find.text('Doni Pratama'), findsOneWidget);
        expect(find.text('Budi Santoso'), findsNothing);

        // 6. Clear search filter
        await tester.enterText(searchField, '');
        await pumpAndAdvance(tester, 300);
        expect(find.byType(DriverListItem), findsNWidgets(3));

        // 7. Tap on driver item to select
        await tester.tap(find.text('Budi Santoso'));
        await pumpAndAdvance(tester, 200);
        expect(driversProvider.selectedDriver?.id, equals(1));
      },
    );

    testWidgets(
      'TC-DRI-REG-02: Driver Form Modal CRUD Flow: Validation -> Add New Driver -> Reactive Drawer & Repository Update',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open drawer
        await tester.tap(find.byKey(const Key('driver_drawer_action_button')));
        await pumpAndAdvance(tester, 400);

        // 2. Tap Add (+) button in drawer header
        expect(
          find.byKey(const Key('driver_drawer_add_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('driver_drawer_add_button')));
        await pumpAndAdvance(tester, 400);

        // 3. Verify DriverFormModal opens
        expect(find.byType(DriverFormModal), findsOneWidget);
        expect(find.text('Tambah Pengemudi Baru'), findsOneWidget);

        // 4. Test Form Validation: tap Simpan without input
        await tester.tap(find.byKey(const Key('driver_form_submit_button')));
        await pumpAndAdvance(tester, 100);
        expect(find.text('Nama pengemudi wajib diisi'), findsOneWidget);
        expect(find.text('Nomor kartu/RFID unik wajib diisi'), findsOneWidget);

        // 5. Fill valid driver data
        await tester.enterText(
          find.byKey(const Key('driver_form_name_field')),
          'Eko Purwanto',
        );
        await tester.enterText(
          find.byKey(const Key('driver_form_unique_id_field')),
          'RFID-4004',
        );
        await tester.enterText(
          find.byKey(const Key('driver_form_phone_field')),
          '081399887766',
        );
        await tester.enterText(
          find.byKey(const Key('driver_form_license_field')),
          'B2-778899',
        );
        await pumpAndAdvance(tester, 100);

        // 6. Submit form
        await tester.tap(find.byKey(const Key('driver_form_submit_button')));
        await pumpAndAdvance(tester, 400);

        // 7. Verify modal closes and SnackBar feedback
        expect(find.byType(DriverFormModal), findsNothing);
        expect(
          find.text('Pengemudi baru berhasil ditambahkan'),
          findsOneWidget,
        );

        // 8. Verify repository received new driver and drawer reflects 4 drivers
        expect(
          mockDriversRepo.mockDrivers.any((d) => d.name == 'Eko Purwanto'),
          isTrue,
        );
        expect(find.text('4 Supir'), findsOneWidget);
        expect(find.text('Eko Purwanto'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-DRI-REG-03: Multi-Vehicle Assignment & Permissions Reconciliation: Diffing POST/DELETE via /api/permissions',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open drawer
        await tester.tap(find.byKey(const Key('driver_drawer_action_button')));
        await pumpAndAdvance(tester, 400);

        // 2. Open popup menu on Driver 1 (Budi Santoso)
        final menuBtn = find.byKey(const Key('driver_item_menu_button_1'));
        expect(menuBtn, findsOneWidget);
        await tester.tap(menuBtn);
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Tautkan Armada'
        expect(find.text('Tautkan Armada'), findsOneWidget);
        await tester.tap(find.text('Tautkan Armada'));
        await pumpAndAdvance(tester, 400);

        // 4. Verify assignment dialog opens with candidate devices
        expect(find.byType(DriverDeviceAssignmentDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DriverDeviceAssignmentDialog),
            matching: find.text('Truk Hino Dutro B 1111 AA'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DriverDeviceAssignmentDialog),
            matching: find.text('Truk Isuzu Giga B 2222 BB'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DriverDeviceAssignmentDialog),
            matching: find.text('Grand Max Blind Van B 3333 CC'),
          ),
          findsOneWidget,
        );
        expect(find.text('1 kendaraan dipilih'), findsOneWidget);

        // 5. Select Device 12 (Truk Isuzu Giga) -> new link
        await tester.tap(
          find.byKey(const Key('driver_assignment_device_checkbox_12')),
        );
        await pumpAndAdvance(tester, 100);

        // 6. Unselect Device 11 (Truk Hino Dutro) -> unlink
        await tester.tap(
          find.byKey(const Key('driver_assignment_device_checkbox_11')),
        );
        await pumpAndAdvance(tester, 100);

        // 7. Save assignment
        await tester.tap(
          find.byKey(const Key('driver_assignment_save_button')),
        );
        await pumpAndAdvance(tester, 400);

        // 8. Verify REST permissions diffing endpoints invoked
        expect(
          mockDriversRepo.linkedDeviceCalls.any(
            (c) => c.deviceId == 12 && c.driverId == 1,
          ),
          isTrue,
        );
        expect(
          mockDriversRepo.unlinkedDeviceCalls.any(
            (c) => c.deviceId == 11 && c.driverId == 1,
          ),
          isTrue,
        );
        expect(
          find.text('Penautan armada berhasil diperbarui'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-DRI-REG-04: Active Driver Resolution on VehicleDetailSheet: Telemetry RFID vs Assigned Driver vs Unregistered RFID vs Tanpa Pengemudi',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // Case A: Device 12 has position with RFID matching Driver 2 ('Agus Setiawan')
        liveFleet.selectDevice(12);
        await pumpAndAdvance(tester, 300);

        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(VehicleDetailSheet),
            matching: find.text('Truk Isuzu Giga B 2222 BB'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('vehicle_sheet_driver_card')),
          findsOneWidget,
        );
        expect(find.text('Agus Setiawan'), findsOneWidget);
        expect(find.text('RFID-1002'), findsOneWidget);
        expect(find.text('08198765432'), findsOneWidget);

        // Case B: Device 13 has no position RFID, but is assigned to Driver 3 ('Doni Pratama')
        liveFleet.selectDevice(13);
        await pumpAndAdvance(tester, 300);

        expect(
          find.descendant(
            of: find.byType(VehicleDetailSheet),
            matching: find.text('Grand Max Blind Van B 3333 CC'),
          ),
          findsOneWidget,
        );
        expect(find.text('Doni Pratama'), findsOneWidget);
        expect(find.text('IBUTTON-3003'), findsOneWidget);

        // Case C: Position with uncatalogued RFID tag ('UNKNOWN-CARD-99')
        final uncataloguedPos = tPos11.copyWith(
          id: 104,
          fixTime: tPos11.fixTime.add(const Duration(seconds: 10)),
          attributes: {'driverUniqueId': 'UNKNOWN-CARD-99'},
        );
        liveFleet.updatePositions([uncataloguedPos]);
        liveFleet.selectDevice(11);
        await pumpAndAdvance(tester, 300);

        expect(find.text('Kartu: UNKNOWN-CARD-99'), findsOneWidget);
        expect(find.text('UNKNOWN-CARD-99'), findsOneWidget);

        // Case D: Vehicle without RFID and without assigned driver
        final emptyPos = tPos11.copyWith(
          id: 105,
          fixTime: tPos11.fixTime.add(const Duration(seconds: 20)),
          attributes: {},
        );
        liveFleet.updatePositions([emptyPos]);
        driversProvider.setDeviceDriverLinks(11, []);
        liveFleet.selectDevice(11);
        await pumpAndAdvance(tester, 300);

        expect(find.text('Tanpa Pengemudi'), findsOneWidget);

        // Dismiss sheet
        liveFleet.selectDevice(null);
        await pumpAndAdvance(tester, 200);
        expect(find.byType(VehicleDetailSheet), findsNothing);
      },
    );

    testWidgets(
      'TC-DRI-REG-05: Driver Deletion Lifecycle: Confirmation Dialog Cancel & Confirm -> Cascade Unlink & Remove',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open drawer
        await tester.tap(find.byKey(const Key('driver_drawer_action_button')));
        await pumpAndAdvance(tester, 400);

        // 2. Open popup menu on Driver 3 (Doni Pratama)
        await tester.tap(find.byKey(const Key('driver_item_menu_button_3')));
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Hapus'
        expect(find.text('Hapus'), findsOneWidget);
        await tester.tap(find.text('Hapus'));
        await pumpAndAdvance(tester, 300);

        // 4. Verify confirmation dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Hapus Pengemudi'), findsOneWidget);

        // 5. Cancel deletion
        await tester.tap(find.byKey(const Key('driver_delete_cancel_button')));
        await pumpAndAdvance(tester, 300);

        // Verify driver 3 remains in list
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Doni Pratama'), findsOneWidget);
        expect(mockDriversRepo.mockDrivers.any((d) => d.id == 3), isTrue);

        // 6. Tap Hapus again and Confirm
        await tester.tap(find.byKey(const Key('driver_item_menu_button_3')));
        await pumpAndAdvance(tester, 300);
        await tester.tap(find.text('Hapus'));
        await pumpAndAdvance(tester, 300);

        await tester.tap(find.byKey(const Key('driver_delete_confirm_button')));
        await pumpAndAdvance(tester, 400);

        // 7. Verify deletion completed
        expect(mockDriversRepo.lastDeletedId, equals(3));
        expect(mockDriversRepo.mockDrivers.any((d) => d.id == 3), isFalse);
        expect(
          find.text('Pengemudi "Doni Pratama" berhasil dihapus'),
          findsOneWidget,
        );
        expect(find.text('2 Supir'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-DRI-REG-06: Session Termination & Deterministic State Cleanup: User Logout invokes clearDrivers()',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // Select a driver
        driversProvider.selectDriver(tDriver1);
        expect(driversProvider.drivers.isNotEmpty, isTrue);
        expect(driversProvider.selectedDriver, isNotNull);
        expect(driversProvider.getDriversForDevice(11).isNotEmpty, isTrue);

        // Tap Logout button on AppBar
        expect(find.byTooltip('Logout'), findsOneWidget);
        await tester.tap(find.byTooltip('Logout'));
        await pumpAndAdvance(tester, 300);

        // Verify auth logout called
        expect(mockAuthRepo.logoutCalled, isTrue);

        // Verify DriversProvider state is completely cleared
        expect(driversProvider.drivers.isEmpty, isTrue);
        expect(driversProvider.selectedDriver, isNull);
        expect(driversProvider.searchQuery.isEmpty, isTrue);
        expect(driversProvider.getDriversForDevice(11).isEmpty, isTrue);
      },
    );
  });
}
