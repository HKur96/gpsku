import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  UserModel? mockUser;
  Exception? exceptionToThrow;
  bool logoutCalled = false;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
    String? code,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockUser!;
  }

  @override
  Future<UserModel> getCurrentSession() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockUser!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }
}

class FakeSecureStorageService extends SecureStorageService {
  String? savedEmail;
  String? savedPassword;
  bool rememberMe = false;
  String? savedSessionCookie;

  @override
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    savedEmail = email;
    savedPassword = password;
    rememberMe = true;
  }

  @override
  Future<({String? email, String? password})> getSavedCredentials() async {
    return (email: savedEmail, password: savedPassword);
  }

  @override
  Future<bool> isRememberMeEnabled() async => rememberMe;

  @override
  Future<void> clearPassword() async {
    savedPassword = null;
  }

  @override
  Future<void> clearAll() async {
    savedEmail = null;
    savedPassword = null;
    rememberMe = false;
    savedSessionCookie = null;
  }

  @override
  Future<void> saveSessionCookie(String cookie) async {
    savedSessionCookie = cookie;
  }

  @override
  Future<void> clearSessionCookie() async {
    savedSessionCookie = null;
  }
}

void main() {
  group('AuthRepositoryImpl Either & Result Tests', () {
    late MockAuthRemoteDataSource mockRemote;
    late FakeSecureStorageService fakeStorage;
    late SessionCookieJar cookieJar;
    late AuthRepositoryImpl repository;

    const testUser = UserModel(
      id: 1,
      name: 'Fleet Admin',
      email: 'admin@gpsku.id',
      administrator: true,
    );

    setUp(() {
      mockRemote = MockAuthRemoteDataSource();
      fakeStorage = FakeSecureStorageService();
      cookieJar = SessionCookieJar();
      repository = AuthRepositoryImpl(
        remoteDataSource: mockRemote,
        secureStorage: fakeStorage,
        cookieJar: cookieJar,
      );
    });

    test(
      'TC-AR-01: Successful login with Remember Me persists credentials and returns Right(UserModel)',
      () async {
        mockRemote.mockUser = testUser;
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=node01testcookie; Path=/',
        ]);

        final result = await repository.login(
          email: 'admin@gpsku.id',
          password: 'Password123',
          rememberMe: true,
        );

        expect(result.isRight(), isTrue);
        result.fold((f) => fail('Expected Right, got Left: $f'), (user) {
          expect(user.id, equals(1));
          expect(user.email, equals('admin@gpsku.id'));
        });

        expect(fakeStorage.savedEmail, equals('admin@gpsku.id'));
        expect(fakeStorage.savedPassword, equals('Password123'));
        expect(fakeStorage.rememberMe, isTrue);
      },
    );

    test(
      'TC-AR-02: Failed login with invalid credentials returns Left(AuthFailure)',
      () async {
        mockRemote.exceptionToThrow = const AuthException(
          'Invalid credentials',
        );

        final result = await repository.login(
          email: 'wrong@gpsku.id',
          password: 'BadPassword',
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, equals('Invalid credentials'));
        }, (_) => fail('Expected Left, got Right'));
      },
    );

    test(
      'TC-AR-03: Network connection error returns Left(NetworkFailure)',
      () async {
        mockRemote.exceptionToThrow = const NetworkException(
          'Failed to connect to Traccar server',
        );

        final result = await repository.login(
          email: 'user@gpsku.id',
          password: 'Password123',
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<NetworkFailure>());
          expect(failure.message, contains('Failed to connect'));
        }, (_) => fail('Expected Left, got Right'));
      },
    );

    test(
      'TC-AR-04: Logout clears SessionCookieJar and removes sensitive credentials',
      () async {
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=active_session; Path=/',
        ]);
        fakeStorage.savedPassword = 'SecretPassword';
        fakeStorage.rememberMe = true;

        final result = await repository.logout();

        expect(result.isRight(), isTrue);
        expect(mockRemote.logoutCalled, isTrue);
        expect(cookieJar.hasValidSession, isFalse);
        expect(fakeStorage.savedPassword, isNull);
      },
    );

    test(
      'TC-AR-05: Server challenge WWW-Authenticate: TOTP maps to Left(AuthFailure(TOTP_REQUIRED))',
      () async {
        mockRemote.exceptionToThrow = const AuthException('TOTP_REQUIRED');

        final result = await repository.login(
          email: 'admin@gpsku.id',
          password: 'Password123',
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, equals('TOTP_REQUIRED'));
        }, (_) => fail('Expected Left, got Right'));
      },
    );

    test('TC-AR-06: Two-factor second step with code succeeds', () async {
      mockRemote.mockUser = testUser;

      final result = await repository.login(
        email: 'admin@gpsku.id',
        password: 'Password123',
        code: '123456',
      );

      expect(result.isRight(), isTrue);
      result.fold((f) => fail('Expected Right, got Left: $f'), (user) {
        expect(user.email, equals('admin@gpsku.id'));
      });
    });
  });
}
