import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'initial_fleet_sync_coordinator_test.dart';

void main() {
  group('Position Ordering & Monotonic Handover Integration Tests', () {
    late MockFleetRepository mockRepo;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;
    late InitialFleetSyncCoordinator coordinator;

    final t0 = DateTime.parse('2026-11-08T08:00:00.000Z');

    setUp(() {
      mockRepo = MockFleetRepository();
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 40),
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

    test(
      'TC-POH-01: REST position arrives first, newer WebSocket position replaces it cleanly',
      () async {
        mockRepo.devicesResult = Right([
          const DeviceModel(id: 1, name: 'Bus 01', uniqueId: 'BUS-01'),
        ]);
        mockRepo.positionsResult = Right([
          PositionModel(
            id: 100,
            deviceId: 1,
            serverTime: t0,
            fixTime: t0,
            latitude: -6.2000,
            longitude: 106.8166,
            speed: 30.0,
          ),
        ]);

        await coordinator.synchronizeFleet();
        expect(liveFleet.positions[1]!.id, equals(100));

        // Real-time WebSocket packet arrives with newer timestamp (t0 + 10s)
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 105,
              'deviceId': 1,
              'fixTime': t0.add(const Duration(seconds: 10)).toIso8601String(),
              'serverTime': t0
                  .add(const Duration(seconds: 10))
                  .toIso8601String(),
              'latitude': -6.2050,
              'longitude': 106.8200,
              'speed': 45.0,
            },
          ],
        });

        await Future.delayed(const Duration(milliseconds: 60));

        expect(liveFleet.positions[1]!.id, equals(105));
        expect(liveFleet.positions[1]!.speed, equals(45.0));
      },
    );

    test(
      'TC-POH-02: WebSocket position arrives BEFORE delayed REST response; older REST does NOT overwrite it',
      () async {
        final newerWsPosition = {
          'positions': [
            {
              'id': 200,
              'deviceId': 2,
              'fixTime': t0.add(const Duration(seconds: 30)).toIso8601String(),
              'serverTime': t0
                  .add(const Duration(seconds: 30))
                  .toIso8601String(),
              'latitude': -6.3000,
              'longitude': 106.8500,
              'speed': 60.0,
            },
          ],
        };

        // Simulate WebSocket receiving fresh telemetry ahead of a slow REST query
        fakeWs.emitMessage(newerWsPosition);
        await Future.delayed(const Duration(milliseconds: 60));
        expect(liveFleet.positions[2]!.id, equals(200));

        // Now a delayed REST response arrives with older data (t0 + 5s)
        final olderRestPosition = PositionModel(
          id: 150,
          deviceId: 2,
          serverTime: t0.add(const Duration(seconds: 5)),
          fixTime: t0.add(const Duration(seconds: 5)),
          latitude: -6.2500,
          longitude: 106.8300,
          speed: 20.0,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [
            const DeviceModel(id: 2, name: 'Car 02', uniqueId: 'CAR-02'),
          ],
          initialPositions: [olderRestPosition],
          clearExisting: false,
        );

        // The newer WebSocket position (id 200) MUST be preserved!
        expect(liveFleet.positions[2]!.id, equals(200));
        expect(liveFleet.positions[2]!.speed, equals(60.0));
      },
    );

    test(
      'TC-POH-03: Repeated initial REST synchronization preserves existing newer positions',
      () async {
        // 1. Initial sync
        mockRepo.devicesResult = Right([
          const DeviceModel(id: 3, name: 'Van 03', uniqueId: 'VAN-03'),
        ]);
        mockRepo.positionsResult = Right([
          PositionModel(
            id: 301,
            deviceId: 3,
            serverTime: t0,
            fixTime: t0,
            latitude: -6.1000,
            longitude: 106.7000,
          ),
        ]);
        await coordinator.synchronizeFleet();

        // 2. Telemetry update over WebSocket (t0 + 15s)
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 305,
              'deviceId': 3,
              'fixTime': t0.add(const Duration(seconds: 15)).toIso8601String(),
              'serverTime': t0
                  .add(const Duration(seconds: 15))
                  .toIso8601String(),
              'latitude': -6.1050,
              'longitude': 106.7050,
            },
          ],
        });
        await Future.delayed(const Duration(milliseconds: 60));
        expect(liveFleet.positions[3]!.id, equals(305));

        // 3. User triggers manual sync repeating REST with slightly stale data (t0 + 5s)
        mockRepo.positionsResult = Right([
          PositionModel(
            id: 302,
            deviceId: 3,
            serverTime: t0.add(const Duration(seconds: 5)),
            fixTime: t0.add(const Duration(seconds: 5)),
            latitude: -6.1020,
            longitude: 106.7020,
          ),
        ]);

        await coordinator.synchronizeFleet();

        // Position 305 is preserved without jump-back
        expect(liveFleet.positions[3]!.id, equals(305));
      },
    );

    test(
      'TC-POH-04: WebSocket duplicate position with identical fixTime is handled deterministically',
      () async {
        final originalPos = PositionModel(
          id: 400,
          deviceId: 4,
          serverTime: t0,
          fixTime: t0,
          latitude: -6.4000,
          longitude: 106.9000,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [
            const DeviceModel(id: 4, name: 'Bike 04', uniqueId: 'BK-04'),
          ],
          initialPositions: [originalPos],
        );

        // Duplicate packet with exact same ID and fixTime
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 400,
              'deviceId': 4,
              'fixTime': t0.toIso8601String(),
              'serverTime': t0.toIso8601String(),
              'latitude': -6.4000,
              'longitude': 106.9000,
            },
          ],
        });

        await Future.delayed(const Duration(milliseconds: 60));
        expect(liveFleet.positions[4]!.id, equals(400));
      },
    );

    test(
      'TC-POH-05: WebSocket out-of-order stale packet is rejected by PositionOrderingGuard',
      () async {
        final currentPos = PositionModel(
          id: 502,
          deviceId: 5,
          serverTime: t0.add(const Duration(seconds: 20)),
          fixTime: t0.add(const Duration(seconds: 20)),
          latitude: -6.5000,
          longitude: 106.9500,
          speed: 50.0,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [
            const DeviceModel(id: 5, name: 'Truck 05', uniqueId: 'TRK-05'),
          ],
          initialPositions: [currentPos],
        );

        // Incoming packet delayed in network transit (fixTime t0 + 10s)
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 501,
              'deviceId': 5,
              'fixTime': t0.add(const Duration(seconds: 10)).toIso8601String(),
              'serverTime': t0
                  .add(const Duration(seconds: 10))
                  .toIso8601String(),
              'latitude': -6.4900,
              'longitude': 106.9400,
              'speed': 35.0,
            },
          ],
        });

        await Future.delayed(const Duration(milliseconds: 60));

        expect(liveFleet.positions[5]!.id, equals(502));
        expect(liveFleet.positions[5]!.speed, equals(50.0));
      },
    );

    test(
      'TC-POH-06: Equal fixTime with different IDs breaks tie via auto-increment database PK',
      () async {
        final posA = PositionModel(
          id: 601,
          deviceId: 6,
          serverTime: t0,
          fixTime: t0,
          latitude: -6.6000,
          longitude: 106.9600,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [
            const DeviceModel(id: 6, name: 'Sedan 06', uniqueId: 'SED-06'),
          ],
          initialPositions: [posA],
        );

        // Packet with exact same fixTime but higher database PK 602
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 602,
              'deviceId': 6,
              'fixTime': t0.toIso8601String(),
              'serverTime': t0.toIso8601String(),
              'latitude': -6.6010,
              'longitude': 106.9610,
            },
          ],
        });

        await Future.delayed(const Duration(milliseconds: 60));
        expect(liveFleet.positions[6]!.id, equals(602));
      },
    );

    test(
      'TC-POH-07: Multiple devices updating concurrently maintain independent monotonic ordering',
      () async {
        mockRepo.devicesResult = Right([
          const DeviceModel(id: 7, name: 'Fleet A', uniqueId: 'FA'),
          const DeviceModel(id: 8, name: 'Fleet B', uniqueId: 'FB'),
        ]);
        mockRepo.positionsResult = Right([
          PositionModel(
            id: 701,
            deviceId: 7,
            serverTime: t0,
            fixTime: t0,
            latitude: -6.1,
            longitude: 106.1,
          ),
          PositionModel(
            id: 801,
            deviceId: 8,
            serverTime: t0,
            fixTime: t0,
            latitude: -6.2,
            longitude: 106.2,
          ),
        ]);

        await coordinator.synchronizeFleet();

        // Burst packet: Device 7 has newer position, Device 8 has stale position
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 702,
              'deviceId': 7,
              'fixTime': t0.add(const Duration(seconds: 10)).toIso8601String(),
              'serverTime': t0
                  .add(const Duration(seconds: 10))
                  .toIso8601String(),
              'latitude': -6.11,
              'longitude': 106.11,
            },
            {
              'id': 800,
              'deviceId': 8,
              'fixTime': t0
                  .subtract(const Duration(seconds: 10))
                  .toIso8601String(),
              'serverTime': t0
                  .subtract(const Duration(seconds: 10))
                  .toIso8601String(),
              'latitude': -6.19,
              'longitude': 106.19,
            },
          ],
        });

        await Future.delayed(const Duration(milliseconds: 60));

        expect(
          liveFleet.positions[7]!.id,
          equals(702),
          reason: 'Device 7 accepted newer position',
        );
        expect(
          liveFleet.positions[8]!.id,
          equals(801),
          reason: 'Device 8 rejected older position',
        );
      },
    );
  });
}
