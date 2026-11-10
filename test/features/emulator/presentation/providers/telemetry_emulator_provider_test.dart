import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';
import 'package:gpsku/features/emulator/domain/repositories/telemetry_emulator_repository.dart';
import 'package:gpsku/features/emulator/presentation/providers/telemetry_emulator_provider.dart';

class MockTelemetryEmulatorRepository implements TelemetryEmulatorRepository {
  bool sendTelemetrySuccess = true;
  bool probePortSuccess = true;
  Failure? failureToReturn;

  TelemetryPacketModel? lastPacket;
  String? lastCustomHost;
  int? lastCustomPort;
  int sendTelemetryCallCount = 0;
  int probePortCallCount = 0;

  @override
  Future<Either<Failure, bool>> sendTelemetry({
    required TelemetryPacketModel packet,
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async {
    sendTelemetryCallCount++;
    lastPacket = packet;
    lastCustomHost = customHost;
    lastCustomPort = customPort;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(sendTelemetrySuccess);
  }

  @override
  Future<Either<Failure, bool>> probePort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async {
    probePortCallCount++;
    lastCustomHost = customHost;
    lastCustomPort = customPort;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(probePortSuccess);
  }
}

void main() {
  group('TelemetryEmulatorProvider Unit Tests', () {
    late MockTelemetryEmulatorRepository mockRepo;
    late TelemetryEmulatorProvider provider;

    const tDevice = DeviceModel(
      id: 101,
      name: 'Truk Logistik B 1234 ABC',
      uniqueId: 'TRONTON-99',
      status: 'online',
    );

    final tPosition = PositionModel(
      id: 501,
      deviceId: 101,
      protocol: 'osmand',
      serverTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      fixTime: DateTime.utc(2026, 11, 10, 8, 0, 0),
      valid: true,
      latitude: -6.1754,
      longitude: 106.8272,
      altitude: 30.0,
      speed: 16.2, // ~30 km/h in knots
      course: 180.0,
      attributes: const {'ignition': true, 'batteryLevel': 92.0},
    );

    setUp(() {
      mockRepo = MockTelemetryEmulatorRepository();
      provider = TelemetryEmulatorProvider(repository: mockRepo);
    });

    tearDown(() {
      provider.dispose();
    });

    test(
      'TC-TEP-01: Initial state has default values and idle simulation status',
      () {
        expect(provider.simulationStatus, EmulatorSimulationStatus.idle);
        expect(provider.portStatus, OsmandPortStatus.unknown);
        expect(provider.targetUniqueId, isEmpty);
        expect(provider.currentLat, -6.2088);
        expect(provider.currentLon, 106.8456);
        expect(provider.currentSpeed, 20.0);
        expect(provider.currentBearing, 90.0);
        expect(provider.currentBattery, 85.0);
        expect(provider.isIgnitionOn, isTrue);
        expect(provider.transmissionSuccessCount, 0);
        expect(provider.transmissionFailureCount, 0);
        expect(provider.isSimulating, isFalse);
        expect(provider.isPaused, isFalse);
        expect(provider.isBusy, isFalse);
      },
    );

    test(
      'TC-TEP-02: setTargetDevice enforces device.uniqueId mapping and pre-fills position',
      () {
        provider.setTargetDevice(tDevice, tPosition);

        // Verify strict Condition 2 resolution: targetUniqueId == 'TRONTON-99', NOT '101'
        expect(provider.targetUniqueId, 'TRONTON-99');
        expect(provider.targetDeviceName, 'Truk Logistik B 1234 ABC');
        expect(provider.currentLat, -6.1754);
        expect(provider.currentLon, 106.8272);
        expect(provider.currentBearing, 180.0);
        expect(provider.currentAltitude, 30.0);
        expect(provider.isIgnitionOn, isTrue);
        expect(provider.currentBattery, 92.0);
      },
    );

    test(
      'TC-TEP-03: Parameter updaters modify values and trigger listener notifications',
      () {
        bool notified = false;
        provider.addListener(() => notified = true);

        provider.updateCoordinates(lat: -7.2504, lon: 112.7688);
        expect(provider.currentLat, -7.2504);
        expect(provider.currentLon, 112.7688);
        expect(notified, isTrue);

        notified = false;
        provider.updateSpeed(65.0);
        expect(provider.currentSpeed, 65.0);
        expect(notified, isTrue);

        notified = false;
        provider.updateBearing(270.0);
        expect(provider.currentBearing, 270.0);
        expect(notified, isTrue);

        notified = false;
        provider.updateBattery(45.0);
        expect(provider.currentBattery, 45.0);
        expect(notified, isTrue);

        notified = false;
        provider.setIgnition(false);
        expect(provider.isIgnitionOn, isFalse);
        expect(notified, isTrue);
      },
    );

    test(
      'TC-TEP-04: probePort transitions status to probing then reachable on success',
      () async {
        mockRepo.probePortSuccess = true;

        final success = await provider.probePort();

        expect(success, isTrue);
        expect(provider.portStatus, OsmandPortStatus.reachable);
        expect(mockRepo.probePortCallCount, 1);
      },
    );

    test(
      'TC-TEP-05: probePort transitions status to unreachable on failure',
      () async {
        mockRepo.failureToReturn = const NetworkFailure(
          'Port 5055 unreachable',
        );

        final success = await provider.probePort();

        expect(success, isFalse);
        expect(provider.portStatus, OsmandPortStatus.unreachable);
        expect(provider.lastErrorMessage, 'Port 5055 unreachable');
      },
    );

    test('TC-TEP-06: sendSingleFix fails if targetUniqueId is empty', () async {
      final success = await provider.sendSingleFix();

      expect(success, isFalse);
      expect(provider.lastErrorMessage, contains('belum dipilih'));
      expect(mockRepo.sendTelemetryCallCount, 0);
    });

    test(
      'TC-TEP-07: sendSingleFix transmits packet and updates success statistics',
      () async {
        provider.setTargetDevice(tDevice);
        mockRepo.sendTelemetrySuccess = true;

        final success = await provider.sendSingleFix();

        expect(success, isTrue);
        expect(mockRepo.sendTelemetryCallCount, 1);
        expect(mockRepo.lastPacket?.id, 'TRONTON-99');
        expect(provider.transmissionSuccessCount, 1);
        expect(provider.lastStatusCode, 200);
        expect(provider.portStatus, OsmandPortStatus.reachable);
        expect(provider.lastTransmissionTime, isNotNull);
      },
    );

    test(
      'TC-TEP-08: sendSingleFix records error when repository fails',
      () async {
        provider.setTargetDevice(tDevice);
        mockRepo.failureToReturn = const ServerFailure(
          'Bad Request',
          statusCode: 400,
        );

        final success = await provider.sendSingleFix();

        expect(success, isFalse);
        expect(provider.transmissionFailureCount, 1);
        expect(provider.lastStatusCode, 400);
        expect(provider.lastErrorMessage, 'Bad Request');
      },
    );

    test(
      'TC-TEP-09: startSimulation sets status and executes periodic timer transmissions',
      () async {
        provider.setTargetDevice(tDevice);
        provider.setSimulationInterval(const Duration(milliseconds: 50));

        expect(provider.isSimulating, isFalse);
        provider.startSimulation();
        expect(provider.isSimulating, isTrue);
        expect(provider.simulationStatus, EmulatorSimulationStatus.simulating);

        // Wait for timer to tick twice
        await Future<void>.delayed(const Duration(milliseconds: 140));

        expect(mockRepo.sendTelemetryCallCount, greaterThanOrEqualTo(2));
        expect(provider.transmissionSuccessCount, greaterThanOrEqualTo(2));

        provider.stopSimulation();
        expect(provider.isSimulating, isFalse);
        expect(provider.simulationStatus, EmulatorSimulationStatus.idle);
      },
    );

    test(
      'TC-TEP-10: pauseSimulation and stopSimulation control timer state safely',
      () async {
        provider.setTargetDevice(tDevice);
        provider.setSimulationInterval(const Duration(milliseconds: 50));

        provider.startSimulation();
        expect(provider.isSimulating, isTrue);

        provider.pauseSimulation();
        expect(provider.isPaused, isTrue);
        expect(provider.simulationStatus, EmulatorSimulationStatus.paused);

        final countBefore = mockRepo.sendTelemetryCallCount;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        // No more ticks while paused
        expect(mockRepo.sendTelemetryCallCount, countBefore);

        provider.stopSimulation();
        expect(provider.isSimulating, isFalse);
        expect(provider.simulationStatus, EmulatorSimulationStatus.idle);
      },
    );

    test(
      'TC-TEP-11: Waypoint route path advances position toward successive waypoints',
      () async {
        final waypoints = [
          const LatLng(-6.2000, 106.8000),
          const LatLng(-6.2050, 106.8050),
          const LatLng(-6.2100, 106.8100),
        ];

        provider.setTargetDevice(tDevice);
        provider.setWaypoints(waypoints);

        expect(provider.simulationWaypoints.length, 3);
        expect(provider.currentLat, closeTo(-6.2000, 0.0001));
        expect(provider.currentLon, closeTo(106.8000, 0.0001));

        final initialLat = provider.currentLat;
        final initialLon = provider.currentLon;

        // Advance position manually via simulation tick at higher speed
        provider.updateSpeed(120.0);
        provider.setSimulationInterval(const Duration(milliseconds: 40));
        provider.startSimulation();

        await Future<void>.delayed(const Duration(milliseconds: 160));
        provider.stopSimulation();

        // Coordinates should have moved away from start toward waypoint 1 (-6.2050, 106.8050)
        expect(provider.currentLat, lessThan(initialLat));
        expect(provider.currentLon, greaterThan(initialLon));
      },
    );

    test(
      'TC-TEP-12: clearState resets all state and cancels active timers',
      () {
        provider.setTargetDevice(tDevice);
        provider.setSimulationInterval(const Duration(milliseconds: 50));
        provider.startSimulation();

        provider.clearState();

        expect(provider.isSimulating, isFalse);
        expect(provider.simulationStatus, EmulatorSimulationStatus.idle);
        expect(provider.portStatus, OsmandPortStatus.unknown);
        expect(provider.targetUniqueId, isEmpty);
        expect(provider.targetDeviceName, isNull);
        expect(provider.transmissionSuccessCount, 0);
        expect(provider.transmissionFailureCount, 0);
        expect(provider.simulationWaypoints, isEmpty);
      },
    );

    test(
      'TC-TEP-13: computeNextCoordinate advances geographic position along bearing vector',
      () {
        const start = LatLng(-6.2088, 106.8456);
        const distance = 100.0; // 100 meters East (90 deg)

        final eastPos = TelemetryEmulatorProvider.computeNextCoordinate(
          start,
          distance,
          90.0,
        );
        expect(eastPos.longitude, greaterThan(start.longitude));
        expect(eastPos.latitude, closeTo(start.latitude, 0.0001));

        // 100 meters North (0 deg)
        final northPos = TelemetryEmulatorProvider.computeNextCoordinate(
          start,
          distance,
          0.0,
        );
        expect(northPos.latitude, greaterThan(start.latitude));
        expect(northPos.longitude, closeTo(start.longitude, 0.0001));

        // 0 distance returns original coordinate
        final zeroMove = TelemetryEmulatorProvider.computeNextCoordinate(
          start,
          0.0,
          45.0,
        );
        expect(zeroMove, equals(start));
      },
    );
  });
}
