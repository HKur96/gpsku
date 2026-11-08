import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/domain/repositories/drivers_repository.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_device_assignment_dialog.dart';

class MockDriversAssignmentRepository implements DriversRepository {
  final Map<int, List<DriverModel>> deviceDriversMap = {};
  final List<int> linkedDeviceIds = [];
  final List<int> unlinkedDeviceIds = [];

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
    return const Right([]);
  }

  @override
  Future<Either<Failure, DriverModel>> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async => Right(driver);

  @override
  Future<Either<Failure, DriverModel>> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async => Right(driver);

  @override
  Future<Either<Failure, void>> deleteDriver(
    int id, {
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceIds.add(deviceId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    unlinkedDeviceIds.add(deviceId);
    return const Right(null);
  }
}

class FakeWebSocketService extends Fake implements TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  WebSocketConnectionState get state => WebSocketConnectionState.connected;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
  }
}

void main() {
  group('DriverDeviceAssignmentDialog Widget Tests', () {
    late MockDriversAssignmentRepository mockRepo;
    late DriversProvider driversProvider;
    late LiveFleetProvider liveFleetProvider;

    const testDriver = DriverModel(
      id: 55,
      name: 'Supardi Logistik',
      uniqueId: 'RFID-5555',
    );

    final testDevices = [
      const DeviceModel(
        id: 1,
        name: 'Truk Tronton 01',
        uniqueId: 'TRK-001',
        status: 'online',
      ),
      const DeviceModel(
        id: 2,
        name: 'Truk Box 02',
        uniqueId: 'TRK-002',
        status: 'offline',
      ),
      const DeviceModel(
        id: 3,
        name: 'Mobil Operasional',
        uniqueId: 'OPS-003',
        status: 'online',
      ),
    ];

    setUp(() {
      mockRepo = MockDriversAssignmentRepository();
      driversProvider = DriversProvider(repository: mockRepo);
      liveFleetProvider = LiveFleetProvider(
        webSocketService: FakeWebSocketService(),
      );

      // Seed fleet with devices
      liveFleetProvider.setInitialFleetData(
        initialDevices: testDevices,
        initialPositions: const [],
      );

      // Device 1 initially has driver 55
      mockRepo.deviceDriversMap[1] = [testDriver];
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<LiveFleetProvider>.value(
              value: liveFleetProvider,
            ),
            ChangeNotifierProvider<DriversProvider>.value(
              value: driversProvider,
            ),
          ],
          child: const Scaffold(
            body: DriverDeviceAssignmentDialog(driver: testDriver),
          ),
        ),
      );
    }

    testWidgets(
      'TC-DDAD-01: Loads and displays vehicles with initial selection',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Tautkan Armada'), findsOneWidget);
        expect(find.text('Supardi Logistik'), findsOneWidget);
        expect(find.text('Truk Tronton 01'), findsOneWidget);
        expect(find.text('Truk Box 02'), findsOneWidget);
        expect(find.text('Mobil Operasional'), findsOneWidget);
        expect(find.text('1 kendaraan dipilih'), findsOneWidget);

        final checkboxFinder = find.byKey(
          const Key('driver_assignment_device_checkbox_1'),
        );
        final checkbox = tester.widget<CheckboxListTile>(checkboxFinder);
        expect(checkbox.value, isTrue);
      },
    );

    testWidgets('TC-DDAD-02: Search text filters the displayed vehicles', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('driver_assignment_search_field')),
        'Mobil',
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobil Operasional'), findsOneWidget);
      expect(find.text('Truk Tronton 01'), findsNothing);
      expect(find.text('Truk Box 02'), findsNothing);
    });

    testWidgets('TC-DDAD-03: Select All selects all filtered vehicles', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('driver_assignment_select_all_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 kendaraan dipilih'), findsOneWidget);
    });

    testWidgets('TC-DDAD-04: Deselect All clears selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('driver_assignment_deselect_all_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 kendaraan dipilih'), findsOneWidget);
    });

    testWidgets('TC-DDAD-05: Checkbox toggle alters selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check Device 2
      await tester.tap(
        find.byKey(const Key('driver_assignment_device_checkbox_2')),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 kendaraan dipilih'), findsOneWidget);
    });

    testWidgets(
      'TC-DDAD-06: Save button reconciles permissions and closes dialog',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Device 1 was initially linked.
        // Select Device 3, uncheck Device 1
        await tester.tap(
          find.byKey(const Key('driver_assignment_device_checkbox_1')),
        ); // Unlink 1
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('driver_assignment_device_checkbox_3')),
        ); // Link 3
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('driver_assignment_save_button')),
        );
        await tester.pumpAndSettle();

        expect(mockRepo.linkedDeviceIds, equals([3]));
        expect(mockRepo.unlinkedDeviceIds, equals([1]));
      },
    );

    testWidgets('TC-DDAD-07: Cancel button closes dialog without saving', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('driver_assignment_select_all_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('driver_assignment_cancel_button')),
      );
      await tester.pumpAndSettle();

      expect(mockRepo.linkedDeviceIds, isEmpty);
      expect(mockRepo.unlinkedDeviceIds, isEmpty);
    });
  });
}
