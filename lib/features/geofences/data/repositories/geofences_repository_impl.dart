import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/geofences_repository.dart';
import '../datasources/geofences_remote_data_source.dart';
import '../models/geofence_model.dart';

/// Production implementation of [GeofencesRepository] enforcing typed Failure mappings
/// and unmodifiable collections.
class GeofencesRepositoryImpl implements GeofencesRepository {
  final GeofencesRemoteDataSource remoteDataSource;

  GeofencesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    try {
      final geofences = await remoteDataSource.getGeofences(
        all: all,
        userId: userId,
        deviceId: deviceId,
        groupId: groupId,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(geofences));
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
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    try {
      final created = await remoteDataSource.createGeofence(
        geofence,
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
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    try {
      final updated = await remoteDataSource.updateGeofence(
        geofence,
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
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.deleteGeofence(id, cancelToken: cancelToken);
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
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.linkDeviceGeofence(
        deviceId: deviceId,
        geofenceId: geofenceId,
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
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.unlinkDeviceGeofence(
        deviceId: deviceId,
        geofenceId: geofenceId,
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
