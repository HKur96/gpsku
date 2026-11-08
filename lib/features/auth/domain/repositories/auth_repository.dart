import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  });

  Future<Either<Failure, UserModel>> getCurrentSession();

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, ({String? email, String? password, bool rememberMe})>>
  getSavedCredentials();

  Future<Either<Failure, void>> clearSavedCredentials();
}
