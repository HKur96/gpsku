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
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_device_assignment_dialog.dart';

class MockMaintenanceRepository implements MaintenanceRepository {
  final Map<int, List<MaintenanceModel>> deviceMaintenancesMap = {};
  final List<int> linkedDeviceIds = [];
  final List<int> unlinkedDeviceIds = [];

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
    return const Right([]);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceIds.add(deviceId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
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
  group('MaintenanceDeviceAssignmentDialog Widget Tests', () {
    late MockMaintenanceRepository mockRepository;
    late MaintenanceProvider maintenanceProvider;
    late LiveFleetProvider liveFleetProvider;

    const testMaintenance = MaintenanceModel(
      id: 55,
      name: 'Ganti Filter Solar Berkala',
      type: 'totalDistance',
      start: 0,
      period: 10000000,
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
        uniqueId: 'CAR-003',
        status: 'online',
      ),
    ];

    setUp(() {
      mockRepository = MockMaintenanceRepository();
      maintenanceProvider = MaintenanceProvider(repository: mockRepository);
      liveFleetProvider = LiveFleetProvider(
        webSocketService: FakeWebSocketService(),
      );

      // Pre-seed devices into LiveFleetProvider
      liveFleetProvider.setInitialFleetData(
        initialDevices: testDevices,
        initialPositions: const [],
      );

      // Device 1 initially has testMaintenance assigned
      mockRepository.deviceMaintenancesMap[1] = [testMaintenance];
      mockRepository.deviceMaintenancesMap[2] = [];
      mockRepository.deviceMaintenancesMap[3] = [];
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<MaintenanceProvider>.value(
              value: maintenanceProvider,
            ),
            ChangeNotifierProvider<LiveFleetProvider>.value(
              value: liveFleetProvider,
            ),
          ],
          child: const Scaffold(
            body: MaintenanceDeviceAssignmentDialog(
              maintenance: testMaintenance,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'TC-MDAD-01: Displays maintenance title, devices with initial selection state',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Tautkan Armada'), findsOneWidget);
        expect(find.text('Ganti Filter Solar Berkala'), findsOneWidget);

        // Checkbox count
        expect(find.byType(CheckboxListTile), findsNWidgets(3));

        // Initial summary
        expect(find.text('1 dari 3 terpilih'), findsOneWidget);

        // Device 1 should be checked
        final tile1 = tester.widget<CheckboxListTile>(
          find.byKey(const Key('maintenance_device_tile_1')),
        );
        expect(tile1.value, isTrue);

        // Device 2 should NOT be checked
        final tile2 = tester.widget<CheckboxListTile>(
          find.byKey(const Key('maintenance_device_tile_2')),
        );
        expect(tile2.value, isFalse);
      },
    );

    testWidgets('TC-MDAD-02: Search filters devices by name or unique ID', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        const Key('maintenance_assignment_search_field'),
      );
      await tester.enterText(searchField, 'box');
      await tester.pumpAndSettle();

      expect(find.text('Truk Box 02'), findsOneWidget);
      expect(find.text('Truk Tronton 01'), findsNothing);
      expect(find.text('Mobil Operasional'), findsNothing);
    });

    testWidgets(
      'TC-MDAD-03: Select all and deselect all buttons toggle all visible items',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Tap "Pilih Semua"
        await tester.tap(find.text('Pilih Semua'));
        await tester.pumpAndSettle();

        expect(find.text('3 dari 3 terpilih'), findsOneWidget);

        // Tap "Hapus Semua"
        await tester.tap(find.text('Hapus Semua'));
        await tester.pumpAndSettle();

        expect(find.text('0 dari 3 terpilih'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MDAD-04: Saves changes and correctly diffs link/unlink permissions',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Uncheck Device 1 (was linked)
        await tester.tap(find.byKey(const Key('maintenance_device_tile_1')));
        await tester.pumpAndSettle();

        // Check Device 3 (was unlinked)
        await tester.tap(find.byKey(const Key('maintenance_device_tile_3')));
        await tester.pumpAndSettle();

        // Tap "Simpan Perubahan"
        await tester.tap(
          find.byKey(const Key('maintenance_save_assignments_button')),
        );
        await tester.pumpAndSettle();

        // Device 3 should have been linked
        expect(mockRepository.linkedDeviceIds, contains(3));

        // Device 1 should have been unlinked
        expect(mockRepository.unlinkedDeviceIds, contains(1));
      },
    );
  });
}
