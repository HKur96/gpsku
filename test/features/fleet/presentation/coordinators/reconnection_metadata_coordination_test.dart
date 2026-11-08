import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'initial_fleet_sync_coordinator_test.dart';

void main() {
  group('Reconnection Metadata Coordination Tests', () {
    late MockFleetRepository mockRepo;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator coordinator;

    final initialDevice = const DeviceModel(
      id: 1,
      name: 'Initial Name',
      uniqueId: 'UNQ-01',
      status: 'online',
    );

    final initialPosition = PositionModel(
      id: 101,
      deviceId: 1,
      serverTime: DateTime.parse('2026-11-08T08:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T08:00:00Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 25.0,
    );

    setUp(() {
      mockRepo = MockFleetRepository();
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 30),
      );
      coordinator = InitialFleetSyncCoordinator(
        fleetRepository: mockRepo,
        liveFleetProvider: liveFleet,
        webSocketService: fakeWs,
        autoListenReconnection: true, // Enable reconnection listener
      );
    });

    tearDown(() {
      coordinator.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
    });

    test(
      'TC-RMC-01: Reconnecting -> Connected transition triggers background /api/devices refresh',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);

        // 1. Initial sync & connect
        await coordinator.synchronizeFleet();
        expect(mockRepo.getDevicesCallCount, equals(1));
        expect(liveFleet.devices[1]!.name, equals('Initial Name'));

        // 2. Prepare refreshed metadata
        final updatedDevice = const DeviceModel(
          id: 1,
          name: 'Refreshed Name (Online)',
          uniqueId: 'UNQ-01',
          status: 'online',
          category: 'truck',
        );
        mockRepo.devicesResult = Right([updatedDevice]);

        // 3. Simulate disconnection and reconnecting transition
        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(coordinator.isReconnecting, isTrue);

        // 4. Reconnect successfully
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // Refresh was triggered
        expect(mockRepo.getDevicesCallCount, equals(2));
        expect(liveFleet.devices[1]!.name, equals('Refreshed Name (Online)'));
        expect(liveFleet.devices[1]!.category, equals('truck'));
      },
    );

    test(
      'TC-RMC-02: Reconnect does NOT refresh repeatedly on the same steady connected state',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);

        await coordinator.synchronizeFleet();
        expect(mockRepo.getDevicesCallCount, equals(1));

        // Emitting multiple steady-state 'connected' events without a disconnect in between
        fakeWs.emitState(WebSocketConnectionState.connected);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 30));

        // No redundant GET /api/devices calls
        expect(mockRepo.getDevicesCallCount, equals(1));
      },
    );

    test(
      'TC-RMC-03: Metadata refresh merges new device name/status without touching or resetting positions',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);
        await coordinator.synchronizeFleet();

        expect(liveFleet.positions[1]!.id, equals(101));

        // Reconnect with changed status
        mockRepo.devicesResult = Right([
          const DeviceModel(
            id: 1,
            name: 'Renamed Vehicle',
            uniqueId: 'UNQ-01',
            status: 'offline',
          ),
        ]);

        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // Device metadata was updated
        expect(liveFleet.devices[1]!.name, equals('Renamed Vehicle'));
        expect(liveFleet.devices[1]!.status, equals('offline'));

        // Position was NOT reset or cleared!
        expect(liveFleet.positions.containsKey(1), isTrue);
        expect(liveFleet.positions[1]!.id, equals(101));
        expect(liveFleet.positions[1]!.latitude, equals(-6.2088));
      },
    );

    test(
      'TC-RMC-04: Metadata refresh failure logs warning and does NOT break the active WebSocket connection',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);
        await coordinator.synchronizeFleet();

        // Simulate network 500 when refreshing metadata
        mockRepo.devicesResult = const Left(
          ServerFailure('Server 500 on refresh', statusCode: 500),
        );

        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // Refresh was attempted
        expect(mockRepo.getDevicesCallCount, equals(2));

        // Existing fleet data remains intact
        expect(liveFleet.devices[1]!.name, equals('Initial Name'));
        expect(fakeWs.isConnected, isTrue);
      },
    );

    test(
      'TC-RMC-05: Reconnection refresh does not fire after coordinator is disposed',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);
        await coordinator.synchronizeFleet();
        expect(mockRepo.getDevicesCallCount, equals(1));

        coordinator.dispose();

        // Trigger reconnect event
        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // No new calls made after disposal
        expect(mockRepo.getDevicesCallCount, equals(1));
      },
    );

    test(
      'TC-RMC-06: Cooldown guard throttles metadata refresh during rapid network flapping (< 3s)',
      () async {
        mockRepo.devicesResult = Right([initialDevice]);
        mockRepo.positionsResult = Right([initialPosition]);
        await coordinator.synchronizeFleet();
        expect(mockRepo.getDevicesCallCount, equals(1));

        // 1. First reconnection -> triggers refresh
        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(mockRepo.getDevicesCallCount, equals(2));

        // 2. Immediate rapid flapping: reconnecting -> connected within 100ms
        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // Must still be 2 because cooldown (3s) is active!
        expect(mockRepo.getDevicesCallCount, equals(2));

        // 3. Flap again within 100ms
        fakeWs.emitState(WebSocketConnectionState.reconnecting);
        fakeWs.emitState(WebSocketConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));

        // Still throttled!
        expect(mockRepo.getDevicesCallCount, equals(2));
      },
    );
  });
}
