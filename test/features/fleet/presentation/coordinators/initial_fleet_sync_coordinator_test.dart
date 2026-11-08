import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';

class MockFleetRepository implements FleetRepository {
  Either<Failure, List<DeviceModel>> devicesResult = const Right([]);
  Either<Failure, List<PositionModel>> positionsResult = const Right([]);
  Either<Failure, List<GroupModel>> groupsResult = const Right([]);
  int getDevicesCallCount = 0;
  int getPositionsCallCount = 0;
  int getGroupsCallCount = 0;
  Duration delay = Duration.zero;

  @override
  Future<Either<Failure, List<DeviceModel>>> getDevices({
    CancelToken? cancelToken,
  }) async {
    getDevicesCallCount++;
    if (delay > Duration.zero) await Future.delayed(delay);
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/devices'),
        type: DioExceptionType.cancel,
      );
    }
    return devicesResult;
  }

  @override
  Future<Either<Failure, List<PositionModel>>> getPositions({
    CancelToken? cancelToken,
  }) async {
    getPositionsCallCount++;
    if (delay > Duration.zero) await Future.delayed(delay);
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/positions'),
        type: DioExceptionType.cancel,
      );
    }
    return positionsResult;
  }

  @override
  Future<Either<Failure, List<GroupModel>>> getGroups({
    CancelToken? cancelToken,
  }) async {
    getGroupsCallCount++;
    if (delay > Duration.zero) await Future.delayed(delay);
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/groups'),
        type: DioExceptionType.cancel,
      );
    }
    return groupsResult;
  }
}

class FakeWebSocketService extends TraccarWebSocketService {
  final _stateStreamController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  int connectCallCount = 0;
  bool isConnected = false;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => isConnected
      ? WebSocketConnectionState.connected
      : WebSocketConnectionState.disconnected;

  @override
  Stream<WebSocketConnectionState> get stateStream =>
      _stateStreamController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgStreamController.stream;

  @override
  Future<void> connect() async {
    connectCallCount++;
    isConnected = true;
    _stateStreamController.add(WebSocketConnectionState.connected);
  }

  void emitState(WebSocketConnectionState newState) {
    isConnected = newState == WebSocketConnectionState.connected;
    _stateStreamController.add(newState);
  }

  void emitMessage(Map<String, dynamic> msg) {
    _msgStreamController.add(msg);
  }

  @override
  void dispose() {
    _stateStreamController.close();
    _msgStreamController.close();
    super.dispose();
  }
}

void main() {
  group('InitialFleetSyncCoordinator - Dual-Fetch & Synchronization Lifecycle Tests', () {
    late MockFleetRepository mockRepo;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator coordinator;

    final testDevices = [
      const DeviceModel(
        id: 1,
        name: 'Vehicle 1',
        uniqueId: 'V1',
        status: 'online',
      ),
      const DeviceModel(
        id: 2,
        name: 'Vehicle 2',
        uniqueId: 'V2',
        status: 'offline',
      ),
    ];

    final testPositions = [
      PositionModel(
        id: 10,
        deviceId: 1,
        serverTime: DateTime.parse('2026-11-08T08:00:00Z'),
        fixTime: DateTime.parse('2026-11-08T08:00:00Z'),
        latitude: -6.2088,
        longitude: 106.8456,
      ),
    ];

    setUp(() {
      mockRepo = MockFleetRepository();
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 50),
      );
      coordinator = InitialFleetSyncCoordinator(
        fleetRepository: mockRepo,
        liveFleetProvider: liveFleet,
        webSocketService: fakeWs,
        autoListenReconnection: false, // Tested in dedicated suite
      );
    });

    tearDown(() {
      coordinator.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    test(
      'TC-FSC-01: Correct synchronization ordering: concurrent REST seed before WebSocket activation',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);

        expect(coordinator.syncState, equals(FleetSyncState.notInitialized));
        expect(fakeWs.connectCallCount, equals(0));

        final result = await coordinator.synchronizeFleet();

        expect(result.isSuccess, isTrue);
        expect(result.devicesCount, equals(2));
        expect(result.positionsCount, equals(1));
        expect(coordinator.syncState, equals(FleetSyncState.ready));

        // Provider seeded
        expect(liveFleet.devices.length, equals(2));
        expect(liveFleet.positions.length, equals(1));

        // WebSocket connected strictly after REST data was ready
        expect(fakeWs.connectCallCount, equals(1));
      },
    );

    test(
      'TC-FSC-02: Both REST requests succeed -> State transitions to ready',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);

        final result = await coordinator.synchronizeFleet();

        expect(result.status, equals(FleetSyncStatus.success));
        expect(coordinator.isReady, isTrue);
        expect(coordinator.hasError, isFalse);
        expect(coordinator.errorMessage, isNull);
      },
    );

    test(
      'TC-FSC-03: Devices succeed, positions fail -> State is partialData, seeds devices, connects WebSocket',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = const Left(
          ServerFailure('Positions DB timeout', statusCode: 504),
        );

        final result = await coordinator.synchronizeFleet();

        expect(result.isPartial, isTrue);
        expect(result.devicesCount, equals(2));
        expect(coordinator.hasPartialData, isTrue);
        expect(coordinator.syncState, equals(FleetSyncState.partialData));

        // Devices retained
        expect(liveFleet.devices.length, equals(2));
        expect(liveFleet.positions, isEmpty);

        // WebSocket still connected to recover positions
        expect(fakeWs.connectCallCount, equals(1));
      },
    );

    test(
      'TC-FSC-04: Devices fail, positions succeed -> State is partialData, seeds positions',
      () async {
        mockRepo.devicesResult = const Left(
          NetworkFailure('Devices network error'),
        );
        mockRepo.positionsResult = Right(testPositions);

        final result = await coordinator.synchronizeFleet();

        expect(result.isPartial, isTrue);
        expect(result.positionsCount, equals(1));
        expect(coordinator.hasPartialData, isTrue);
        expect(liveFleet.positions.length, equals(1));
      },
    );

    test(
      'TC-FSC-05: Both REST requests fail -> State is error, WebSocket is NOT connected',
      () async {
        mockRepo.devicesResult = const Left(
          ServerFailure('Server 500', statusCode: 500),
        );
        mockRepo.positionsResult = const Left(
          ServerFailure('Server 500', statusCode: 500),
        );

        final result = await coordinator.synchronizeFleet();

        expect(result.isFailure, isTrue);
        expect(coordinator.hasError, isTrue);
        expect(coordinator.syncState, equals(FleetSyncState.error));
        expect(coordinator.errorMessage, isNotNull);

        // WebSocket must NOT connect when initial sync completely fails
        expect(fakeWs.connectCallCount, equals(0));
      },
    );

    test(
      'TC-FSC-06: Prevents duplicate concurrent synchronization (serializes in-flight future)',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);
        mockRepo.delay = const Duration(milliseconds: 50);

        // Launch 3 concurrent calls simultaneously
        final future1 = coordinator.synchronizeFleet();
        final future2 = coordinator.synchronizeFleet();
        final future3 = coordinator.synchronizeFleet();

        expect(coordinator.isLoading, isTrue);

        final results = await Future.wait([future1, future2, future3]);

        // Exactly ONE set of concurrent REST calls was executed
        expect(mockRepo.getDevicesCallCount, equals(1));
        expect(mockRepo.getPositionsCallCount, equals(1));
        expect(mockRepo.getGroupsCallCount, equals(1));
        expect(results[0].isSuccess, isTrue);
        expect(results[1].isSuccess, isTrue);
        expect(results[2].isSuccess, isTrue);
      },
    );

    test(
      'TC-FSC-07: Cancellation via cancel() aborts pending sync cleanly',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);
        mockRepo.delay = const Duration(milliseconds: 100);

        final syncFuture = coordinator.synchronizeFleet();
        expect(coordinator.isLoading, isTrue);

        coordinator.cancel();

        final result = await syncFuture;
        expect(result.isCancelled, isTrue);
        expect(coordinator.syncState, equals(FleetSyncState.notInitialized));
        expect(liveFleet.devices, isEmpty);
      },
    );

    test(
      'TC-FSC-08: User logout / reset returns coordinator to notInitialized state',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);

        await coordinator.synchronizeFleet();
        expect(coordinator.isReady, isTrue);

        coordinator.reset();
        expect(coordinator.syncState, equals(FleetSyncState.notInitialized));
        expect(coordinator.errorMessage, isNull);
      },
    );

    test(
      'TC-FSC-09: Empty device and position lists handled cleanly without error',
      () async {
        mockRepo.devicesResult = const Right([]);
        mockRepo.positionsResult = const Right([]);

        final result = await coordinator.synchronizeFleet();

        expect(result.isSuccess, isTrue);
        expect(result.devicesCount, equals(0));
        expect(result.positionsCount, equals(0));
        expect(coordinator.isReady, isTrue);
        expect(liveFleet.devices, isEmpty);
        expect(liveFleet.positions, isEmpty);
      },
    );

    test(
      'TC-FSC-10: Groups are fetched and seeded into LiveFleetProvider on sync',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);
        mockRepo.groupsResult = const Right([
          GroupModel(id: 10, name: 'Divisi Logistik', groupId: null),
          GroupModel(id: 20, name: 'Divisi Operasional', groupId: null),
        ]);

        final result = await coordinator.synchronizeFleet();

        expect(result.isSuccess, isTrue);
        expect(liveFleet.groups.length, equals(2));
        expect(liveFleet.groups[10]?.name, equals('Divisi Logistik'));
        expect(liveFleet.groups[20]?.name, equals('Divisi Operasional'));
      },
    );

    test(
      'TC-FSC-11: Graceful fallback when groups call fails — sync still succeeds with devices and positions',
      () async {
        mockRepo.devicesResult = Right(testDevices);
        mockRepo.positionsResult = Right(testPositions);
        mockRepo.groupsResult = const Left(ServerFailure('Groups 500 error'));

        final result = await coordinator.synchronizeFleet();

        expect(result.isSuccess, isTrue);
        expect(result.devicesCount, equals(2));
        expect(result.positionsCount, equals(1));
        expect(liveFleet.groups, isEmpty);
      },
    );
  });
}
