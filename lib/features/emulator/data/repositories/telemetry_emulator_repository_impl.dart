import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/telemetry_emulator_repository.dart';
import '../datasources/telemetry_emulator_remote_data_source.dart';
import '../models/telemetry_packet_model.dart';

/// Production implementation of [TelemetryEmulatorRepository] mapping low-level
/// datasource exceptions into typed domain [Failure] models.
class TelemetryEmulatorRepositoryImpl implements TelemetryEmulatorRepository {
  final TelemetryEmulatorRemoteDataSource remoteDataSource;

  TelemetryEmulatorRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, bool>> sendTelemetry({
    required TelemetryPacketModel packet,
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final success = await remoteDataSource.sendTelemetryPacket(
        packet,
        customHost: customHost,
        customPort: customPort,
        usePost: usePost,
        cancelToken: cancelToken,
      );
      return Right(success);
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> probePort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async {
    try {
      final reachable = await remoteDataSource.probeOsmandPort(
        customHost: customHost,
        customPort: customPort,
        cancelToken: cancelToken,
      );
      if (reachable) {
        return const Right(true);
      }
      return const Left(
        NetworkFailure(
          'Port OsmAnd tidak merespons atau tidak aktif',
          statusCode: 503,
        ),
      );
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
