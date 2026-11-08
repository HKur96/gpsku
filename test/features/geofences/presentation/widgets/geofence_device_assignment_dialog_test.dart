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
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/repositories/geofences_repository.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_device_assignment_dialog.dart';

class MockGeofencesRepository implements GeofencesRepository {
  final Map<int, List<GeofenceModel>> deviceGeofencesMap = {};
  final List<int> linkedDeviceIds = [];
  final List<int> unlinkedDeviceIds = [];

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
    return const Right([]);
  }

  @override
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    return Right(geofence);
  }

  @override
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    return Right(geofence);
  }

  @override
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    linkedDeviceIds.add(deviceId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
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
  group('GeofenceDeviceAssignmentDialog Widget Tests', () {
    late MockGeofencesRepository mockRepository;
    late GeofencesProvider geofencesProvider;
    late LiveFleetProvider liveFleetProvider;

    const testGeofence = GeofenceModel(
      id: 77,
      name: 'Zona Bongkar Muat',
      area: 'CIRCLE (-6.20 106.80, 500)',
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
      mockRepository = MockGeofencesRepository();
      // Device 1 initially has geofence 77 linked
      mockRepository.deviceGeofencesMap[1] = [testGeofence];
      mockRepository.deviceGeofencesMap[2] = [];
      mockRepository.deviceGeofencesMap[3] = [];

      geofencesProvider = GeofencesProvider(repository: mockRepository);

      liveFleetProvider = LiveFleetProvider(
        webSocketService: FakeWebSocketService(),
      );
      liveFleetProvider.setInitialFleetData(
        initialDevices: testDevices,
        initialPositions: const [],
      );
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GeofencesProvider>.value(
            value: geofencesProvider,
          ),
          ChangeNotifierProvider<LiveFleetProvider>.value(
            value: liveFleetProvider,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => GeofenceDeviceAssignmentDialog.show(
                  ctx,
                  geofence: testGeofence,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'TC-GDA-01: Displays geofence title, search field, quick action chips, and device list',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Tautkan Kendaraan'), findsOneWidget);
        expect(find.text('Zona Bongkar Muat'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Pilih Semua'), findsOneWidget);
        expect(find.text('Batal Semua'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(3));
      },
    );

    testWidgets(
      'TC-GDA-02: Device 1 is initially checked while others are unchecked',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(tiles.elementAt(0).value, isTrue); // Device 1 checked
        expect(tiles.elementAt(1).value, isFalse); // Device 2 unchecked
        expect(tiles.elementAt(2).value, isFalse); // Device 3 unchecked

        expect(find.text('1 dipilih'), findsOneWidget);
      },
    );

    testWidgets('TC-GDA-03: Filters device list via search field', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'operasional');
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('Mobil Operasional'), findsOneWidget);
    });

    testWidgets(
      'TC-GDA-04: "Pilih Semua" checks all devices and "Batal Semua" unchecks all',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap "Pilih Semua"
        await tester.tap(find.text('Pilih Semua'));
        await tester.pumpAndSettle();

        expect(find.text('3 dipilih'), findsOneWidget);

        // Tap "Batal Semua"
        await tester.tap(find.text('Batal Semua'));
        await tester.pumpAndSettle();

        expect(find.text('0 dipilih'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-GDA-05: Reconciles assignments: links newly selected and unlinks unselected devices',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Uncheck Device 1
        await tester.tap(find.text('Truk Tronton 01'));
        await tester.pumpAndSettle();

        // Check Device 2
        await tester.tap(find.text('Truk Box 02'));
        await tester.pumpAndSettle();

        // Check Device 3
        await tester.tap(find.text('Mobil Operasional'));
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.text('Simpan Perubahan'));
        await tester.pumpAndSettle();

        // Unlinked Device 1
        expect(mockRepository.unlinkedDeviceIds, contains(1));

        // Linked Device 2 and 3
        expect(mockRepository.linkedDeviceIds, containsAll([2, 3]));
      },
    );

    testWidgets(
      'TC-GDA-06: Cancelling dialog does not invoke permissions endpoints and pops with false',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Check Device 2
        await tester.tap(find.text('Truk Box 02'));
        await tester.pumpAndSettle();

        // Cancel
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(mockRepository.linkedDeviceIds, isEmpty);
        expect(mockRepository.unlinkedDeviceIds, isEmpty);
        expect(find.byType(GeofenceDeviceAssignmentDialog), findsNothing);
      },
    );
  });
}
