import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_data_source.dart';
import '../models/stop_report_model.dart';
import '../models/trip_report_model.dart';

/// Implementation of [ReportsRepository] mapping remote datasource exceptions
/// into clean, domain-level [Failure] abstractions and returning unmodifiable collections.
class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsRemoteDataSource remoteDataSource;

  ReportsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<PositionModel>>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final positions = await remoteDataSource.getRouteReport(
        deviceId: deviceId,
        from: from,
        to: to,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(positions));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TripReportModel>>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final trips = await remoteDataSource.getTripReport(
        deviceId: deviceId,
        from: from,
        to: to,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(trips));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StopReportModel>>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final stops = await remoteDataSource.getStopReport(
        deviceId: deviceId,
        from: from,
        to: to,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(stops));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
