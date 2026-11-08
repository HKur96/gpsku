import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/session_cookie_jar.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorageService secureStorage;
  final SessionCookieJar cookieJar;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
    required this.cookieJar,
  });

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async {
    try {
      final user = await remoteDataSource.login(
        email: email,
        password: password,
        code: code,
      );

      // Handle Remember Me persistence
      if (rememberMe) {
        await secureStorage.saveCredentials(email: email, password: password);
        final sessionCookie = cookieJar.sessionCookieValue;
        if (sessionCookie != null) {
          await secureStorage.saveSessionCookie(sessionCookie);
        }
      } else {
        await secureStorage.clearAll();
      }

      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentSession() async {
    try {
      final user = await remoteDataSource.getCurrentSession();
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Ignore remote logout failures to guarantee local cleanup succeeds
    } finally {
      cookieJar.clear();
      final rememberMe = await secureStorage.isRememberMeEnabled();
      if (!rememberMe) {
        await secureStorage.clearAll();
      } else {
        await secureStorage.clearPassword();
        await secureStorage.clearSessionCookie();
      }
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials() async {
    try {
      final creds = await secureStorage.getSavedCredentials();
      final rememberMe = await secureStorage.isRememberMeEnabled();
      return Right((
        email: creds.email,
        password: creds.password,
        rememberMe: rememberMe,
      ));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async {
    try {
      await secureStorage.clearAll();
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
