import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/emulator/data/datasources/telemetry_emulator_remote_data_source.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';
import 'package:gpsku/features/emulator/data/repositories/telemetry_emulator_repository_impl.dart';

class MockTelemetryEmulatorRemoteDataSource
    implements TelemetryEmulatorRemoteDataSource {
  bool sendTelemetryResult = true;
  bool probeOsmandResult = true;
  Exception? exceptionToThrow;

  TelemetryPacketModel? lastPacket;
  String? lastCustomHost;
  int? lastCustomPort;
  bool? lastUsePost;
  CancelToken? lastCancelToken;

  @override
  Future<bool> sendTelemetryPacket(
    TelemetryPacketModel packet, {
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async {
    lastPacket = packet;
    lastCustomHost = customHost;
    lastCustomPort = customPort;
    lastUsePost = usePost;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return sendTelemetryResult;
  }

  @override
  Future<bool> probeOsmandPort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async {
    lastCustomHost = customHost;
    lastCustomPort = customPort;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return probeOsmandResult;
  }
}

void main() {
  group('TelemetryEmulatorRepositoryImpl Unit Tests', () {
    late MockTelemetryEmulatorRemoteDataSource mockDataSource;
    late TelemetryEmulatorRepositoryImpl repository;

    final tPacket = TelemetryPacketModel(
      id: 'TRONTON-77',
      lat: -6.2088,
      lon: 106.8456,
      timestamp: DateTime.utc(2026, 11, 10, 9, 30, 0),
      speed: 25.0,
      bearing: 90.0,
      altitude: 10.0,
      battery: 100.0,
    );

    setUp(() {
      mockDataSource = MockTelemetryEmulatorRemoteDataSource();
      repository = TelemetryEmulatorRepositoryImpl(
        remoteDataSource: mockDataSource,
      );
    });

    test(
      'TC-ERI-01: sendTelemetry returns Right(true) on successful transmission',
      () async {
        mockDataSource.sendTelemetryResult = true;

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(result, const Right(true));
        expect(mockDataSource.lastPacket, equals(tPacket));
      },
    );

    test(
      'TC-ERI-02: sendTelemetry maps ConnectionTimeoutException to TimeoutFailure',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Koneksi timeout ke port 5055',
          408,
        );

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(
          result,
          const Left(
            TimeoutFailure('Koneksi timeout ke port 5055', statusCode: 408),
          ),
        );
      },
    );

    test(
      'TC-ERI-03: sendTelemetry maps NetworkException to NetworkFailure',
      () async {
        mockDataSource.exceptionToThrow = const NetworkException(
          'Port 5055 connection refused',
        );

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(
          result,
          const Left(NetworkFailure('Port 5055 connection refused')),
        );
      },
    );

    test(
      'TC-ERI-04: sendTelemetry maps ServerException to ServerFailure',
      () async {
        mockDataSource.exceptionToThrow = const ServerException(
          'ID TRONTON-77 tidak terdaftar',
          400,
        );

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(
          result,
          const Left(
            ServerFailure('ID TRONTON-77 tidak terdaftar', statusCode: 400),
          ),
        );
      },
    );

    test(
      'TC-ERI-05: sendTelemetry maps AuthException to AuthFailure',
      () async {
        mockDataSource.exceptionToThrow = const AuthException(
          'Unauthorized',
          401,
        );

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(
          result,
          const Left(AuthFailure('Unauthorized', statusCode: 401)),
        );
      },
    );

    test(
      'TC-ERI-06: sendTelemetry maps ForbiddenException to ForbiddenFailure',
      () async {
        mockDataSource.exceptionToThrow = const ForbiddenException(
          'Forbidden',
          403,
        );

        final result = await repository.sendTelemetry(packet: tPacket);

        expect(
          result,
          const Left(ForbiddenFailure('Forbidden', statusCode: 403)),
        );
      },
    );

    test(
      'TC-ERI-07: probePort returns Right(true) when port is reachable',
      () async {
        mockDataSource.probeOsmandResult = true;

        final result = await repository.probePort();

        expect(result, const Right(true));
      },
    );

    test(
      'TC-ERI-08: probePort returns Left(NetworkFailure) when port does not respond',
      () async {
        mockDataSource.probeOsmandResult = false;

        final result = await repository.probePort();

        expect(
          result,
          const Left(
            NetworkFailure(
              'Port OsmAnd tidak merespons atau tidak aktif',
              statusCode: 503,
            ),
          ),
        );
      },
    );

    test(
      'TC-ERI-09: probePort maps ConnectionTimeoutException to TimeoutFailure',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Probe timeout',
          408,
        );

        final result = await repository.probePort();

        expect(
          result,
          const Left(TimeoutFailure('Probe timeout', statusCode: 408)),
        );
      },
    );

    test(
      'TC-ERI-10: probePort maps NetworkException to NetworkFailure',
      () async {
        mockDataSource.exceptionToThrow = const NetworkException(
          'Port unreachable',
        );

        final result = await repository.probePort();

        expect(result, const Left(NetworkFailure('Port unreachable')));
      },
    );
  });
}
