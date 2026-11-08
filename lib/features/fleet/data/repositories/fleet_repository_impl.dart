import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/fleet_repository.dart';
import '../datasources/fleet_remote_data_source.dart';
import '../models/device_model.dart';
import '../models/group_model.dart';
import '../models/position_model.dart';

/// Implementation of [FleetRepository] mapping remote datasource exceptions
/// into clean, domain-level [Failure] abstractions.
class FleetRepositoryImpl implements FleetRepository {
  final FleetRemoteDataSource remoteDataSource;

  FleetRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<DeviceModel>>> getDevices({
    CancelToken? cancelToken,
  }) async {
    try {
      final devices = await remoteDataSource.getDevices(
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(devices));
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
  Future<Either<Failure, List<PositionModel>>> getPositions({
    CancelToken? cancelToken,
  }) async {
    try {
      final positions = await remoteDataSource.getPositions(
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
  Future<Either<Failure, List<GroupModel>>> getGroups({
    CancelToken? cancelToken,
  }) async {
    try {
      final groups = await remoteDataSource.getGroups(cancelToken: cancelToken);
      return Right(List.unmodifiable(groups));
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
