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
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/repositories/geofences_repository.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_list_drawer.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_list_item.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_map_layer_toggle_button.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Admin Telematics',
    email: 'admin@gpsku.id',
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

class MockGeofencesRepository implements GeofencesRepository {
  final List<GeofenceModel> mockGeofences = [];
  final Map<int, List<GeofenceModel>> deviceGeofencesMap = {};
  final List<int> linkedDeviceCalls = [];
  final List<int> unlinkedDeviceCalls = [];
  int? lastDeletedId;

  @override
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (deviceId != null) {
      return Right(deviceGeofencesMap[deviceId] ?? []);
    }
    return Right(List.from(mockGeofences));
  }

  @override
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    final created = geofence.copyWith(id: 100 + mockGeofences.length + 1);
    mockGeofences.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    final idx = mockGeofences.indexWhere((g) => g.id == geofence.id);
    if (idx >= 0) {
      mockGeofences[idx] = geofence;
    }
    return Right(geofence);
  }

  @override
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    mockGeofences.removeWhere((g) => g.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceCalls.add(deviceId);
    final current = deviceGeofencesMap[deviceId] ?? [];
    final toAdd = mockGeofences.firstWhere(
      (g) => g.id == geofenceId,
      orElse: () => GeofenceModel(id: geofenceId, name: 'Target', area: ''),
    );
    deviceGeofencesMap[deviceId] = [...current, toAdd];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    unlinkedDeviceCalls.add(deviceId);
    final current = deviceGeofencesMap[deviceId] ?? [];
    current.removeWhere((g) => g.id == geofenceId);
    deviceGeofencesMap[deviceId] = current;
    return const Right(null);
  }
}

void main() {
  group('Phase 7.7 Geofence Management - Consolidation Regression Tests', () {
    late MockAuthRepository mockAuthRepo;
    late AuthProvider authProvider;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late MockGeofencesRepository mockGeofencesRepo;
    late GeofencesProvider geofencesProvider;

    final tCircleGeofence = const GeofenceModel(
      id: 1,
      name: 'Gudang Pusat Cakung',
      description: 'Hub Logistik Utama',
      area: 'CIRCLE (-6.1925 106.9450, 1200.0)',
      attributes: {'color': '#1E88E5', 'speedLimit': 30.0},
    );

    final tPolygonGeofence = const GeofenceModel(
      id: 2,
      name: 'Pelabuhan Tanjung Priok',
      description: 'Kawasan Terbatas Dermaga 09',
      area:
          'POLYGON ((-6.101 106.881, -6.101 106.892, -6.115 106.892, -6.115 106.881, -6.101 106.881))',
      attributes: {'color': '#43A047'},
    );

    final tPolylineGeofence = const GeofenceModel(
      id: 3,
      name: 'Tol Jakarta Cikampek',
      description: 'Koridor Bebas Hambatan',
      area:
          'LINESTRING (-6.241 106.992, -6.248 107.031, -6.255 107.085, -6.271 107.152)',
      attributes: {'color': '#E53935', 'polylineDistance': 50.0},
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
        initialDevices: tDevices,
        initialPositions: const [],
      );

      mockGeofencesRepo = MockGeofencesRepository();
      mockGeofencesRepo.mockGeofences.addAll([
        tCircleGeofence,
        tPolygonGeofence,
        tPolylineGeofence,
      ]);
      // Device 11 initially assigned to Geofence 1
      mockGeofencesRepo.deviceGeofencesMap[11] = [tCircleGeofence];
      mockGeofencesRepo.deviceGeofencesMap[12] = [];
      mockGeofencesRepo.deviceGeofencesMap[13] = [];

      geofencesProvider = GeofencesProvider(repository: mockGeofencesRepo);
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
          ChangeNotifierProvider<GeofencesProvider>.value(
            value: geofencesProvider,
          ),
          Provider<GeofencesRepository>.value(value: mockGeofencesRepo),
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
      'TC-GEO-REG-01: Full End-to-End Cycle: Shell -> Drawer -> Filter -> Debounce Search -> Select',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // 1. Mount FleetShellScreen
        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 2. Open GeofenceListDrawer via AppBar fence icon
        expect(find.byIcon(Icons.fence), findsOneWidget);
        await tester.tap(find.byIcon(Icons.fence));
        await pumpAndAdvance(tester, 400);

        // 3. Verify GeofenceListDrawer header and initial 3 items
        expect(find.text('Daftar Geofence'), findsOneWidget);
        expect(find.text('3 / 3'), findsOneWidget);
        expect(find.byType(GeofenceListItem), findsNWidgets(3));

        // 4. Test Geometry Filter Chip: 'Lingkaran'
        await tester.ensureVisible(
          find.widgetWithText(FilterChip, 'Lingkaran'),
        );
        await tester.tap(find.widgetWithText(FilterChip, 'Lingkaran'));
        await pumpAndAdvance(tester, 300);

        expect(find.byType(GeofenceListItem), findsOneWidget);
        expect(find.text('Gudang Pusat Cakung'), findsOneWidget);
        expect(find.text('Pelabuhan Tanjung Priok'), findsNothing);

        // 5. Test Geometry Filter Chip: 'Poligon'
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Poligon'));
        await tester.tap(find.widgetWithText(FilterChip, 'Poligon'));
        await pumpAndAdvance(tester, 300);

        expect(find.byType(GeofenceListItem), findsOneWidget);
        expect(find.text('Pelabuhan Tanjung Priok'), findsOneWidget);

        // 6. Restore to 'Semua'
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Semua'));
        await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
        await pumpAndAdvance(tester, 300);
        expect(find.byType(GeofenceListItem), findsNWidgets(3));

        // 7. Test Debounced Search
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'cikampek');
        await tester.pump(const Duration(milliseconds: 50));
        // Before 200ms debounce:
        expect(find.byType(GeofenceListItem), findsNWidgets(3));

        // After 200ms debounce:
        await pumpAndAdvance(tester, 300);
        expect(find.byType(GeofenceListItem), findsOneWidget);
        expect(find.text('Tol Jakarta Cikampek'), findsOneWidget);

        // 8. Select geofence item
        await tester.tap(find.text('Tol Jakarta Cikampek'));
        await pumpAndAdvance(tester, 400);

        // Drawer is dismissed and selection updated
        expect(find.byType(GeofenceListDrawer), findsNothing);
        expect(geofencesProvider.selectedGeofence?.id, equals(3));
      },
    );

    testWidgets(
      'TC-GEO-REG-02: Geofence Creation Lifecycle: Form Modal -> Circle WKT -> Add & Reflect',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open GeofenceListDrawer
        await tester.tap(find.byIcon(Icons.fence));
        await pumpAndAdvance(tester, 400);

        // 2. Tap Add (+) button
        await tester.tap(find.byTooltip('Tambah Geofence'));
        await pumpAndAdvance(tester, 400);

        // 3. Verify GeofenceFormModal opened
        expect(find.text('Tambah Geofence Baru'), findsOneWidget);

        // 4. Fill required form inputs
        final nameField = find.widgetWithText(TextFormField, 'Nama Geofence *');
        await tester.enterText(nameField, 'Depo Baru Cikarang');

        final radiusField = find.widgetWithText(
          TextFormField,
          'Radius (meter) *',
        );
        await tester.enterText(radiusField, '750');

        final speedLimitField = find.widgetWithText(
          TextFormField,
          'Batas Kecepatan Maksimum (Opsional)',
        );
        await tester.enterText(speedLimitField, '40');

        // 5. Submit form
        await tester.ensureVisible(find.text('Simpan Geofence'));
        await tester.tap(find.text('Simpan Geofence'));
        await pumpAndAdvance(tester, 400);

        // 6. Verify geofence was added to provider and repository
        expect(mockGeofencesRepo.mockGeofences.length, equals(4));
        final created = mockGeofencesRepo.mockGeofences.last;
        expect(created.name, equals('Depo Baru Cikarang'));
        expect(created.speedLimit, equals(40.0));
        expect(created.isCircle, isTrue);

        // Drawer count updated to 4 / 4
        expect(find.text('4 / 4'), findsOneWidget);
        expect(find.text('Depo Baru Cikarang'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-GEO-REG-03: Multi-Vehicle Assignment & Permissions Reconciliation Diffing',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open GeofenceListDrawer
        await tester.tap(find.byIcon(Icons.fence));
        await pumpAndAdvance(tester, 400);

        // 2. Open context menu on first geofence (Gudang Cakung)
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Tautkan Kendaraan'
        await tester.tap(find.text('Tautkan Kendaraan'));
        await pumpAndAdvance(tester, 400);

        // 4. Verify GeofenceDeviceAssignmentDialog is shown
        expect(find.text('Tautkan Kendaraan'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Gudang Pusat Cakung'),
          ),
          findsOneWidget,
        );

        // 5. Select Device 12 (Truk Isuzu Giga) -> new link
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Truk Isuzu Giga B 2222 BB'),
        );
        await pumpAndAdvance(tester, 100);

        // 6. Unselect Device 11 (Truk Hino Dutro) -> unlink
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Truk Hino Dutro B 1111 AA'),
        );
        await pumpAndAdvance(tester, 100);

        // 7. Save assignment
        await tester.tap(find.widgetWithText(FilledButton, 'Simpan Perubahan'));
        await pumpAndAdvance(tester, 400);

        // 8. Verify REST permissions diffing endpoints invoked
        expect(mockGeofencesRepo.linkedDeviceCalls, contains(12));
        expect(mockGeofencesRepo.unlinkedDeviceCalls, contains(11));
      },
    );

    testWidgets(
      'TC-GEO-REG-04: Floating Map Layer Visibility Toggle Interactivity',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Locate layer toggle button
        expect(find.byType(GeofenceMapLayerToggleButton), findsOneWidget);
        expect(geofencesProvider.isLayersVisible, isTrue);
        expect(find.byIcon(Icons.layers), findsOneWidget);

        // 2. Tap toggle button -> hide layers
        await tester.tap(find.byType(GeofenceMapLayerToggleButton));
        await pumpAndAdvance(tester, 200);

        expect(geofencesProvider.isLayersVisible, isFalse);
        expect(find.byIcon(Icons.layers_clear), findsOneWidget);

        // 3. Tap again -> show layers
        await tester.tap(find.byType(GeofenceMapLayerToggleButton));
        await pumpAndAdvance(tester, 200);

        expect(geofencesProvider.isLayersVisible, isTrue);
        expect(find.byIcon(Icons.layers), findsOneWidget);
      },
    );

    testWidgets(
      'TC-GEO-REG-05: Geofence Deletion with Confirmation & Safe Teardown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Open Drawer
        await tester.tap(find.byIcon(Icons.fence));
        await pumpAndAdvance(tester, 400);

        expect(find.text('3 / 3'), findsOneWidget);

        // 2. Tap options on first geofence
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await pumpAndAdvance(tester, 300);

        // 3. Tap 'Hapus'
        await tester.tap(find.text('Hapus'));
        await pumpAndAdvance(tester, 300);

        // 4. Confirmation dialog shown
        expect(find.text('Hapus Geofence'), findsOneWidget);
        expect(
          find.textContaining('Apakah Anda yakin ingin menghapus geofence'),
          findsOneWidget,
        );

        // 5. Confirm deletion
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await pumpAndAdvance(tester, 400);

        // 6. Verify deleted
        expect(mockGeofencesRepo.lastDeletedId, equals(1));
        expect(geofencesProvider.geofences.length, equals(2));
        expect(find.text('2 / 2'), findsOneWidget);
        expect(find.text('Gudang Pusat Cakung'), findsNothing);
      },
    );

    testWidgets(
      'TC-GEO-REG-06: Session Termination: clearGeofences() cleanses provider state on logout',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        expect(geofencesProvider.geofences.isNotEmpty, isTrue);

        // 1. Set some active state
        geofencesProvider.setSearchQuery('temp query');
        geofencesProvider.setGeometryFilter('CIRCLE');

        // 2. Tap Logout button in AppBar
        expect(find.byIcon(Icons.logout), findsOneWidget);
        await tester.tap(find.byIcon(Icons.logout));
        await pumpAndAdvance(tester, 300);

        // 3. Verify clean-up completed
        expect(mockAuthRepo.logoutCalled, isTrue);
        expect(geofencesProvider.geofences, isEmpty);
        expect(geofencesProvider.selectedGeofence, isNull);
        expect(geofencesProvider.searchQuery, isEmpty);
        expect(geofencesProvider.selectedGeometryFilter, equals('all'));
      },
    );
  });
}
