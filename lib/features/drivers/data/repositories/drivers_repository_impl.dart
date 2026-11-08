import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/drivers_repository.dart';
import '../datasources/drivers_remote_data_source.dart';
import '../models/driver_model.dart';

/// Production implementation of [DriversRepository] enforcing typed Failure mappings
/// and unmodifiable collections.
class DriversRepositoryImpl implements DriversRepository {
  final DriversRemoteDataSource remoteDataSource;

  DriversRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<DriverModel>>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    try {
      final items = await remoteDataSource.getDrivers(
        all: all,
        userId: userId,
        deviceId: deviceId,
        groupId: groupId,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(items));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DriverModel>> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    try {
      final created = await remoteDataSource.createDriver(
        driver,
        cancelToken: cancelToken,
      );
      return Right(created);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DriverModel>> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    try {
      final updated = await remoteDataSource.updateDriver(
        driver,
        cancelToken: cancelToken,
      );
      return Right(updated);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDriver(
    int id, {
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.deleteDriver(id, cancelToken: cancelToken);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.linkDeviceDriver(
        deviceId: deviceId,
        driverId: driverId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.unlinkDeviceDriver(
        deviceId: deviceId,
        driverId: driverId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
