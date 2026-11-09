import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/computed_attributes_repository.dart';
import '../datasources/computed_attributes_remote_data_source.dart';
import '../models/computed_attribute_model.dart';
import '../models/computed_attribute_test_result_model.dart';

/// Production implementation of [ComputedAttributesRepository] enforcing typed Failure mappings
/// and unmodifiable collections.
class ComputedAttributesRepositoryImpl implements ComputedAttributesRepository {
  final ComputedAttributesRemoteDataSource remoteDataSource;

  ComputedAttributesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ComputedAttributeModel>>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    try {
      final items = await remoteDataSource.getComputedAttributes(
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
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, ComputedAttributeModel>> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    try {
      final created = await remoteDataSource.createComputedAttribute(
        attribute,
        cancelToken: cancelToken,
      );
      return Right(created);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, ComputedAttributeModel>> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    try {
      final updated = await remoteDataSource.updateComputedAttribute(
        attribute,
        cancelToken: cancelToken,
      );
      return Right(updated);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.deleteComputedAttribute(
        id,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, ComputedAttributeTestResultModel>>
  testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await remoteDataSource.testComputedAttribute(
        deviceId: deviceId,
        attribute: attribute,
        cancelToken: cancelToken,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.linkDeviceAttribute(
        deviceId: deviceId,
        attributeId: attributeId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.unlinkDeviceAttribute(
        deviceId: deviceId,
        attributeId: attributeId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.linkGroupAttribute(
        groupId: groupId,
        attributeId: attributeId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await remoteDataSource.unlinkGroupAttribute(
        groupId: groupId,
        attributeId: attributeId,
        cancelToken: cancelToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message, statusCode: e.statusCode));
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
