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
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_test_result_model.dart';
import 'package:gpsku/features/attributes/domain/repositories/computed_attributes_repository.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attributes_drawer.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attribute_form_modal.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attribute_assignment_dialog.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/screens/fleet_shell_screen.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser = const UserModel(
    id: 1,
    name: 'Fleet Administrator',
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

class MockComputedAttributesRegressionRepository
    implements ComputedAttributesRepository {
  List<ComputedAttributeModel> mockAttributes = [];
  Map<int, List<ComputedAttributeModel>> mockDeviceAttributes = {};
  Failure? failureToReturn;
  ComputedAttributeTestResultModel? testResultToReturn;
  int? lastDeletedId;
  final List<({int deviceId, int attributeId})> linkedHistory = [];
  final List<({int deviceId, int attributeId})> unlinkedHistory = [];

  @override
  Future<Either<Failure, List<ComputedAttributeModel>>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (deviceId != null) {
      return Right(mockDeviceAttributes[deviceId] ?? []);
    }
    return Right(mockAttributes);
  }

  @override
  Future<Either<Failure, ComputedAttributeModel>> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final created = attribute.copyWith(id: mockAttributes.length + 100);
    mockAttributes.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, ComputedAttributeModel>> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final idx = mockAttributes.indexWhere((a) => a.id == attribute.id);
    if (idx >= 0) {
      mockAttributes[idx] = attribute;
    }
    return Right(attribute);
  }

  @override
  Future<Either<Failure, void>> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockAttributes.removeWhere((a) => a.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, ComputedAttributeTestResultModel>>
  testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (testResultToReturn != null) return Right(testResultToReturn!);
    return Right(
      ComputedAttributeTestResultModel.success(
        value: 75.5,
        type: attribute.type,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    linkedHistory.add((deviceId: deviceId, attributeId: attributeId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    unlinkedHistory.add((deviceId: deviceId, attributeId: attributeId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async => const Right(null);
}

void main() {
  group('Phase 9.2 Computed Attributes - Consolidation Regression Tests', () {
    late MockAuthRepository mockAuthRepo;
    late AuthProvider authProvider;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late MockComputedAttributesRegressionRepository mockAttrRepo;
    late ComputedAttributesProvider computedAttributesProvider;

    const tDevice1 = DeviceModel(
      id: 101,
      name: 'Truk Tronton Alpha',
      uniqueId: 'TRK-001',
      status: 'online',
    );

    const tDevice2 = DeviceModel(
      id: 102,
      name: 'Mobil Box Beta',
      uniqueId: 'BOX-002',
      status: 'online',
    );

    final tPosition = PositionModel(
      id: 501,
      deviceId: 101,
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 45.0,
      course: 90.0,
      serverTime: DateTime.utc(2026, 11, 9, 12, 0),
      deviceTime: DateTime.utc(2026, 11, 9, 12, 0),
      fixTime: DateTime.utc(2026, 11, 9, 12, 0),
      attributes: const {'ignition': true, 'battery': 3.7, 'adc1': 1023},
    );

    const tAttrExisting = ComputedAttributeModel(
      id: 1,
      description: 'Status Baterai Kritis',
      attribute: 'batteryCritical',
      expression: 'battery < 3.4 ? true : false',
      type: 'boolean',
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
        initialDevices: [tDevice1, tDevice2],
        initialPositions: [tPosition],
      );

      mockAttrRepo = MockComputedAttributesRegressionRepository();
      mockAttrRepo.mockAttributes = [tAttrExisting];
      mockAttrRepo.mockDeviceAttributes = {
        101: [tAttrExisting],
        102: [],
      };

      computedAttributesProvider = ComputedAttributesProvider(
        repository: mockAttrRepo,
      );
    });

    tearDown(() {
      computedAttributesProvider.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    Widget buildTestApp({Widget? home}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
          Provider<TraccarWebSocketService>.value(value: fakeWs),
          ChangeNotifierProvider<ComputedAttributesProvider>.value(
            value: computedAttributesProvider,
          ),
          Provider<ComputedAttributesRepository>.value(value: mockAttrRepo),
        ],
        child: MaterialApp(home: home ?? const FleetShellScreen()),
      );
    }

    Future<void> pumpAndAdvance(
      WidgetTester tester, [
      int durationMs = 300,
    ]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: durationMs));
      await tester.pump();
    }

    testWidgets(
      'TC-ATTR-REG-01: Happy Path Creation & Smart Cursor Syntax Insertion: Shell -> Drawer -> Form Modal -> Chips -> Save -> Drawer Update',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Verify Shell and AppBar computed attributes action button
        final drawerButtonFinder = find.byKey(
          const Key('computed_attributes_drawer_action_button'),
        );
        expect(drawerButtonFinder, findsOneWidget);

        // 2. Open Computed Attributes Drawer
        await tester.tap(drawerButtonFinder);
        await pumpAndAdvance(tester, 300);

        expect(find.text('Atribut Sensor Terhitung'), findsOneWidget);
        expect(find.text('1 formula JEXL terdaftar'), findsOneWidget);

        // 3. Tap Add (+) button
        final addButtonFinder = find.byKey(
          const Key('computed_attributes_add_button'),
        );
        expect(addButtonFinder, findsOneWidget);
        await tester.tap(addButtonFinder);
        await pumpAndAdvance(tester, 300);

        // 4. Modal Form is open
        expect(find.text('Tambah Atribut Terhitung'), findsOneWidget);

        // Enter Description & Target Key
        await tester.enterText(
          find.byKey(const Key('attribute_description_field')),
          'Level Bensin Akurat',
        );
        await tester.enterText(
          find.byKey(const Key('attribute_target_key_field')),
          'fuelPercentage',
        );

        // 5. Use Syntax Helper Chips to build expression
        await tester.ensureVisible(find.byKey(const Key('syntax_chip_adc1')));
        await pumpAndAdvance(tester, 100);
        await tester.tap(find.byKey(const Key('syntax_chip_adc1')));
        await pumpAndAdvance(tester, 100);
        await tester.ensureVisible(find.byKey(const Key('syntax_chip_>')));
        await pumpAndAdvance(tester, 100);
        await tester.tap(find.byKey(const Key('syntax_chip_>')));
        await pumpAndAdvance(tester, 100);

        // Verify expression controller text assembled
        final expressionFieldFinder = find.byKey(
          const Key('attribute_expression_field'),
        );
        final TextFormField exprWidget = tester.widget(expressionFieldFinder);
        expect(exprWidget.controller?.text, 'adc1 > ');

        // 6. Tap Save Button in Modal AppBar
        await tester.tap(
          find.byKey(const Key('computed_attribute_save_button')),
        );
        await pumpAndAdvance(tester, 300);

        // 7. Modal is popped, Drawer reflects updated count
        expect(find.text('Tambah Atribut Terhitung'), findsNothing);
        expect(mockAttrRepo.mockAttributes.length, 2);
        expect(find.text('Level Bensin Akurat'), findsOneWidget);
        expect(find.text('2 formula JEXL terdaftar'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-ATTR-REG-02: Live Test Runner - 3 Evaluation States: Success Green Card, 204 No Content Amber Card, & Syntax Failure Red Card',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            home: const Scaffold(
              body: ComputedAttributeFormModal(initialDeviceId: 101),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('attribute_description_field')),
          'Uji Sensor Suhu',
        );
        await tester.enterText(
          find.byKey(const Key('attribute_target_key_field')),
          'tempValid',
        );
        await tester.enterText(
          find.byKey(const Key('attribute_expression_field')),
          'adc1 * 0.1',
        );
        await tester.pumpAndSettle();

        // Case A: Success Result
        mockAttrRepo.testResultToReturn =
            ComputedAttributeTestResultModel.success(
              value: 102.3,
              type: 'number',
            );

        await tester.ensureVisible(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_success_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_success_card')),
          findsOneWidget,
        );
        expect(find.text('Evaluasi Berhasil'), findsOneWidget);
        expect(find.text('102.3'), findsOneWidget);

        // Case B: 204 No Content / Null Telemetry
        mockAttrRepo.testResultToReturn =
            ComputedAttributeTestResultModel.noContent();

        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_no_content_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_no_content_card')),
          findsOneWidget,
        );
        expect(find.textContaining('204 No Content'), findsOneWidget);

        // Case C: JEXL Syntax Error
        mockAttrRepo.testResultToReturn =
            ComputedAttributeTestResultModel.failure(
              error: 'JexlException: token unrecognized',
              type: 'string',
            );

        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_failure_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_failure_card')),
          findsOneWidget,
        );
        expect(
          find.textContaining('JexlException: token unrecognized'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-ATTR-REG-03: Multi-Vehicle Permissions Diffing: Modify Fleet Assignments -> Automated Link & Unlink Calls',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Device 101 is initially assigned to tAttrExisting
        await tester.pumpWidget(
          buildTestApp(
            home: const Scaffold(
              body: ComputedAttributeAssignmentDialog(attribute: tAttrExisting),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tautkan Armada'), findsOneWidget);
        expect(find.text('1 dipilih'), findsOneWidget);

        // Unlink device 101, Link device 102
        await tester.tap(find.byKey(const Key('device_checkbox_101')));
        await tester.tap(find.byKey(const Key('device_checkbox_102')));
        await tester.pumpAndSettle();

        expect(find.text('1 dipilih'), findsOneWidget);

        // Save
        await tester.tap(
          find.byKey(const Key('save_device_assignment_button')),
        );
        await tester.pumpAndSettle();

        // Verify repository history: 101 was unlinked, 102 was linked
        expect(
          mockAttrRepo.unlinkedHistory.any(
            (h) => h.deviceId == 101 && h.attributeId == 1,
          ),
          isTrue,
        );
        expect(
          mockAttrRepo.linkedHistory.any(
            (h) => h.deviceId == 102 && h.attributeId == 1,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'TC-ATTR-REG-04: Search & Return Type Filtering: Debounced Text Search & Type Filter Chips React Deterministically',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const tAttrNumber = ComputedAttributeModel(
          id: 2,
          description: 'Konsumsi Odometer Real',
          attribute: 'odoReal',
          expression: 'totalDistance / 1000',
          type: 'number',
        );

        const tAttrString = ComputedAttributeModel(
          id: 3,
          description: 'Label Status Kendaraan',
          attribute: 'strStatus',
          expression: 'ignition ? "Jalan" : "Parkir"',
          type: 'string',
        );

        mockAttrRepo.mockAttributes = [
          tAttrExisting, // boolean
          tAttrNumber, // number
          tAttrString, // string
        ];

        await tester.pumpWidget(
          buildTestApp(home: const Scaffold(body: ComputedAttributesDrawer())),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 formula JEXL terdaftar'), findsOneWidget);

        // 1. Debounced Text Search
        await tester.enterText(
          find.byKey(const Key('computed_attributes_search_field')),
          'odometer',
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.text('Konsumsi Odometer Real'), findsOneWidget);
        expect(find.text('Status Baterai Kritis'), findsNothing);
        expect(find.text('Label Status Kendaraan'), findsNothing);

        // Clear search
        await tester.enterText(
          find.byKey(const Key('computed_attributes_search_field')),
          '',
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // 2. Type Filter Chip: Number
        await tester.tap(find.byKey(const Key('type_filter_chip_number')));
        await tester.pumpAndSettle();

        expect(find.text('Konsumsi Odometer Real'), findsOneWidget);
        expect(find.text('Status Baterai Kritis'), findsNothing);

        // 3. Type Filter Chip: String
        await tester.tap(find.byKey(const Key('type_filter_chip_string')));
        await tester.pumpAndSettle();

        expect(find.text('Label Status Kendaraan'), findsOneWidget);
        expect(find.text('Konsumsi Odometer Real'), findsNothing);

        // 4. Reset to All
        await tester.tap(find.byKey(const Key('type_filter_chip_all')));
        await tester.pumpAndSettle();

        expect(find.text('Status Baterai Kritis'), findsOneWidget);
        expect(find.text('Konsumsi Odometer Real'), findsOneWidget);
        expect(find.text('Label Status Kendaraan'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-ATTR-REG-05: Deletion & Confirmation: Cancellation Retains Item, Confirmation Deletes from Repository & UI',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(home: const Scaffold(body: ComputedAttributesDrawer())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Status Baterai Kritis'), findsOneWidget);

        // 1. Open context menu & choose Hapus
        await tester.tap(find.byKey(const Key('attribute_action_menu_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Atribut Terhitung'), findsOneWidget);

        // 2. Cancel dialog
        await tester.tap(
          find.byKey(const Key('attribute_delete_cancel_button')),
        );
        await tester.pumpAndSettle();

        expect(mockAttrRepo.lastDeletedId, isNull);
        expect(find.text('Status Baterai Kritis'), findsOneWidget);

        // 3. Open context menu, choose Hapus, and confirm
        await tester.tap(find.byKey(const Key('attribute_action_menu_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('attribute_delete_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(mockAttrRepo.lastDeletedId, 1);
        expect(mockAttrRepo.mockAttributes, isEmpty);
        expect(find.text('Status Baterai Kritis'), findsNothing);
      },
    );

    testWidgets(
      'TC-ATTR-REG-06: Session Reset on Logout: FleetShellScreen Logout Deterministically Purges Computed Attributes State',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await pumpAndAdvance(tester, 100);

        // 1. Load attributes in provider and select one
        await computedAttributesProvider.fetchAttributes();
        computedAttributesProvider.selectAttribute(tAttrExisting);
        computedAttributesProvider.setSearchQuery('baterai');
        computedAttributesProvider.setTypeFilter('boolean');

        expect(computedAttributesProvider.attributes.length, 1);
        expect(computedAttributesProvider.selectedAttribute, isNotNull);
        expect(computedAttributesProvider.searchQuery, 'baterai');
        expect(computedAttributesProvider.typeFilter, 'boolean');

        // 2. Tap Logout on FleetShellScreen
        final logoutBtn = find.byKey(const Key('fleet_app_bar_logout_button'));
        expect(logoutBtn, findsOneWidget);
        await tester.tap(logoutBtn);
        await pumpAndAdvance(tester, 300);

        // 3. Verify clean state after logout
        expect(mockAuthRepo.logoutCalled, isTrue);
        expect(fakeWs.disconnectCalled, isTrue);
        expect(computedAttributesProvider.attributes, isEmpty);
        expect(computedAttributesProvider.selectedAttribute, isNull);
        expect(computedAttributesProvider.searchQuery, isEmpty);
        expect(computedAttributesProvider.typeFilter, 'all');
        expect(computedAttributesProvider.testResult, isNull);
      },
    );
  });
}
