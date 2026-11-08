import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gpsku/core/network/dio_client.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();
  FlutterSecureStorage.setMockInitialValues({});

  group('Traccar Backend Live Integration Tests (Auth API)', () {
    const backendBaseUrl = 'http://localhost:8082';
    const validEmail = 'admin@gps.local';
    const validPassword = 'Password123!';
    const invalidPassword = 'WrongPassword999!';

    late SessionCookieJar cookieJar;
    late AppConfig appConfig;
    late DioClient dioClient;
    late AuthRemoteDataSource remoteDataSource;
    late SecureStorageService secureStorage;
    late AuthRepositoryImpl authRepository;

    setUp(() {
      HttpOverrides.global = RealHttpOverrides();
      cookieJar = SessionCookieJar();
      appConfig = const AppConfig(baseUrl: backendBaseUrl);
      dioClient = DioClient(appConfig: appConfig, cookieJar: cookieJar);
      remoteDataSource = AuthRemoteDataSourceImpl(dioClient: dioClient);
      secureStorage = SecureStorageService();
      authRepository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        secureStorage: secureStorage,
        cookieJar: cookieJar,
      );
    });

    test(
      'INT-AUTH-01: Valid login through POST /api/session returns 200 with User data',
      () async {
        final result = await authRepository.login(
          email: validEmail,
          password: validPassword,
          rememberMe: false,
        );

        expect(result.isRight(), isTrue);
        result.fold((f) => fail('Login failed: ${f.message}'), (user) {
          expect(user.id, equals(1));
          expect(user.email, equals(validEmail));
          expect(user.administrator, isTrue);
        });
      },
    );

    test(
      'INT-AUTH-02 & 03: Actual Set-Cookie response extracted into SessionCookieJar without attribute leakage',
      () async {
        final response = await dioClient.post<dynamic>(
          '/api/session',
          data: {'email': validEmail, 'password': validPassword},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        expect(response.statusCode, equals(200));

        // 1. Verify actual backend sent Set-Cookie with JSESSIONID
        final setCookieHeaders = response.headers['set-cookie'];
        expect(setCookieHeaders, isNotNull);
        expect(setCookieHeaders!.isNotEmpty, isTrue);
        expect(setCookieHeaders.first, contains('JSESSIONID='));

        // 2. Verify Cookie extraction and storage
        expect(cookieJar.hasValidSession, isTrue);
        expect(cookieJar.sessionCookieValue, isNotNull);
        expect(cookieJar.sessionCookieValue!.isNotEmpty, isTrue);

        // 3. Verify outgoing format strictly strips Path, HttpOnly, SameSite
        final outgoingHeader = cookieJar.outgoingCookieHeader;
        expect(outgoingHeader, isNotNull);
        expect(outgoingHeader, contains('JSESSIONID='));
        expect(outgoingHeader, isNot(contains('Path=')));
        expect(outgoingHeader, isNot(contains('HttpOnly')));

        // 4. Verify WebSocket header
        expect(cookieJar.webSocketCookieHeader, startsWith('JSESSIONID='));
        expect(cookieJar.webSocketCookieHeader, isNot(contains('Path=')));
      },
    );

    test(
      'INT-AUTH-04: Authenticated GET /api/session succeeds using extracted session cookie',
      () async {
        // Step 1: Login to acquire session cookie
        await authRepository.login(email: validEmail, password: validPassword);
        expect(cookieJar.hasValidSession, isTrue);

        // Step 2: Call GET /api/session
        final sessionResult = await authRepository.getCurrentSession();
        expect(sessionResult.isRight(), isTrue);
        sessionResult.fold((f) => fail('Session fetch failed: ${f.message}'), (
          user,
        ) {
          expect(user.id, equals(1));
          expect(user.email, equals(validEmail));
        });
      },
    );

    test(
      'INT-AUTH-05: Invalid credential handling returns 401 AuthFailure',
      () async {
        final result = await authRepository.login(
          email: validEmail,
          password: invalidPassword,
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, equals('Invalid credentials'));
        }, (_) => fail('Expected Left but got Right'));
      },
    );

    test(
      'INT-AUTH-06 & 07: Logout through DELETE /api/session invalidates session on server and client (old cookie cannot be reused)',
      () async {
        // Step 1: Log in
        await authRepository.login(email: validEmail, password: validPassword);
        expect(cookieJar.hasValidSession, isTrue);
        final loggedOutCookie = cookieJar.sessionCookieValue!;

        // Step 2: Log out
        final logoutResult = await authRepository.logout();
        expect(logoutResult.isRight(), isTrue);

        // Step 3: Local cookie jar must be empty
        expect(cookieJar.hasValidSession, isFalse);
        expect(cookieJar.sessionCookieValue, isNull);

        // Step 4: GET /api/session without cookie fails
        final checkResult = await authRepository.getCurrentSession();
        expect(checkResult.isLeft(), isTrue);

        // Step 5: Attempting to reuse the revoked session cookie against GET /api/session
        // Server MUST reject it with 401 because session was invalidated on backend
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=$loggedOutCookie; Path=/; HttpOnly',
        ]);
        final reuseResult = await authRepository.getCurrentSession();
        expect(reuseResult.isLeft(), isTrue);
        reuseResult.fold((failure) {
          expect(failure, isA<AuthFailure>());
        }, (_) => fail('Old cookie must be permanently revoked on server'));
      },
    );

    test(
      'INT-AUTH-08: Remember Me OFF — Credentials are not persisted in secure storage',
      () async {
        await authRepository.login(
          email: validEmail,
          password: validPassword,
          rememberMe: false,
        );

        final creds = await secureStorage.getSavedCredentials();
        expect(creds.email, isNull);
        expect(creds.password, isNull);
        final isRemember = await secureStorage.isRememberMeEnabled();
        expect(isRemember, isFalse);
      },
    );

    test(
      'INT-AUTH-09: Remember Me ON — Credentials and session cookie securely saved',
      () async {
        await authRepository.login(
          email: validEmail,
          password: validPassword,
          rememberMe: true,
        );

        final creds = await secureStorage.getSavedCredentials();
        expect(creds.email, equals(validEmail));
        expect(creds.password, equals(validPassword));
        final isRemember = await secureStorage.isRememberMeEnabled();
        expect(isRemember, isTrue);

        // Cleanup
        await secureStorage.clearAll();
      },
    );

    test('INT-AUTH-10: TOTP policy inspection on active backend', () async {
      // Check user model attributes for totpKey
      final result = await authRepository.login(
        email: validEmail,
        password: validPassword,
      );

      result.fold((_) => fail('Login failed'), (user) {
        // Standard admin account has totpKey null unless 2FA is enrolled
        expect(
          user.attributes.containsKey('totpKey')
              ? user.attributes['totpKey']
              : null,
          isNull,
        );
      });
    });
  });
}
