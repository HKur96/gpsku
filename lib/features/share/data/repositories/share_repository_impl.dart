import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/share_repository.dart';
import '../datasources/share_remote_data_source.dart';
import '../models/share_link_model.dart';

/// Production implementation of [ShareRepository].
///
/// Encapsulates token generation, expiry computation, and share URL formatting
/// based on active [AppConfig.baseUrl].
class ShareRepositoryImpl implements ShareRepository {
  final ShareRemoteDataSource remoteDataSource;
  final AppConfig appConfig;

  ShareRepositoryImpl({
    required this.remoteDataSource,
    required this.appConfig,
  });

  @override
  Future<Either<Failure, ShareLinkModel>> generateShareLink(
    int deviceId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    if (duration <= Duration.zero) {
      return const Left(
        ServerFailure(
          'Durasi tautan berbagi harus lebih dari 0',
          statusCode: 400,
        ),
      );
    }

    if (deviceId <= 0) {
      return const Left(
        ServerFailure('ID perangkat tidak valid', statusCode: 400),
      );
    }

    try {
      final expiration = DateTime.now().toUtc().add(duration);
      final token = await remoteDataSource.createDeviceShareToken(
        deviceId: deviceId,
        expiration: expiration,
        cancelToken: cancelToken,
      );

      final shareUrl = ShareLinkModel.buildShareUrl(appConfig.baseUrl, token);

      final model = ShareLinkModel(
        deviceId: deviceId,
        token: token,
        expiration: expiration,
        shareUrl: shareUrl,
        attributes: const {},
      );

      return Right(model);
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
      return Left(UnexpectedFailure('Terjadi kesalahan tak terduga: $e'));
    }
  }

  @override
  Future<Either<Failure, ShareLinkModel>> generateGroupShareLink(
    int groupId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    if (duration <= Duration.zero) {
      return const Left(
        ServerFailure(
          'Durasi tautan berbagi harus lebih dari 0',
          statusCode: 400,
        ),
      );
    }

    if (groupId <= 0) {
      return const Left(ServerFailure('ID grup tidak valid', statusCode: 400));
    }

    try {
      final expiration = DateTime.now().toUtc().add(duration);
      final token = await remoteDataSource.createGroupShareToken(
        groupId: groupId,
        expiration: expiration,
        cancelToken: cancelToken,
      );

      final shareUrl = ShareLinkModel.buildShareUrl(appConfig.baseUrl, token);

      final model = ShareLinkModel(
        deviceId: 0,
        groupId: groupId,
        token: token,
        expiration: expiration,
        shareUrl: shareUrl,
        attributes: const {},
      );

      return Right(model);
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
      return Left(UnexpectedFailure('Terjadi kesalahan tak terduga: $e'));
    }
  }
}
