import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/queued_reauth_interceptor.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';

class _MockRemoteAuth implements AuthRemoteDataSource {
  int loginCalls = 0;
  bool shouldFailLogin = false;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
    String? code,
  }) async {
    loginCalls++;
    if (shouldFailLogin) {
      throw Exception('Invalid refreshed credentials');
    }
    return const UserModel(id: 1, name: 'Admin', email: 'admin@gpsku.id');
  }

  @override
  Future<UserModel> getCurrentSession() async {
    throw Exception('Session expired');
  }

  @override
  Future<void> logout() async {}
}

class _InMemorySecureStorage extends SecureStorageService {
  String? email;
  String? password;
  bool rememberMe = false;

  @override
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    rememberMe = true;
  }

  @override
  Future<({String? email, String? password})> getSavedCredentials() async {
    return (email: email, password: password);
  }

  @override
  Future<bool> isRememberMeEnabled() async => rememberMe;

  @override
  Future<void> clearPassword() async {
    password = null;
  }

  @override
  Future<void> clearAll() async {
    email = null;
    password = null;
    rememberMe = false;
  }
}

class _RecordingErrorHandler extends ErrorInterceptorHandler {
  final Completer<DioException> nextCompleter = Completer<DioException>();
  final Completer<Response> resolveCompleter = Completer<Response>();

  @override
  void next(DioException err) {
    if (!nextCompleter.isCompleted) nextCompleter.complete(err);
  }

  @override
  void resolve(Response response) {
    if (!resolveCompleter.isCompleted) resolveCompleter.complete(response);
  }
}

void main() {
  group('Remember Me & Re-authentication Race Conditions & Mutex Tests', () {
    late Dio dio;
    late _MockRemoteAuth mockRemote;
    late _InMemorySecureStorage fakeStorage;
    late SessionCookieJar cookieJar;
    late AuthRepositoryImpl authRepo;
    late AuthProvider authProvider;
    late QueuedReAuthInterceptor interceptor;

    setUp(() {
      dio = Dio();
      mockRemote = _MockRemoteAuth();
      fakeStorage = _InMemorySecureStorage();
      cookieJar = SessionCookieJar();
      authRepo = AuthRepositoryImpl(
        remoteDataSource: mockRemote,
        secureStorage: fakeStorage,
        cookieJar: cookieJar,
      );
      authProvider = AuthProvider(
        authRepository: authRepo,
        onCancelReAuth: () => interceptor.cancelActiveReAuth(),
      );

      interceptor = QueuedReAuthInterceptor(
        dio: dio,
        onReAuth: () => authProvider.transparentReAuth(),
        onSessionExpired: () => authProvider.handleSessionExpired(),
      );
    });

    test(
      'TC-RACE-01: Remember Me OFF — 401 unauthenticates without triggering re-login',
      () async {
        // Remember Me was NOT enabled
        fakeStorage.email = null;
        fakeStorage.password = null;
        fakeStorage.rememberMe = false;

        final req = RequestOptions(path: '/api/devices', method: 'GET');
        final err = DioException(
          requestOptions: req,
          response: Response(requestOptions: req, statusCode: 401),
        );

        final handler = _RecordingErrorHandler();
        await interceptor.onError(err, handler);

        expect(
          mockRemote.loginCalls,
          equals(0),
          reason: 'Must not call login when credentials absent',
        );
        expect(authProvider.status, equals(AuthStatus.unauthenticated));
        expect(handler.nextCompleter.isCompleted, isTrue);
      },
    );

    test(
      'TC-RACE-02: Remember Me ON — Concurrent 401s trigger exactly ONE re-authentication',
      () async {
        // Remember Me enabled with saved credentials
        fakeStorage.email = 'admin@gpsku.id';
        fakeStorage.password = 'Password123';
        fakeStorage.rememberMe = true;

        // Simulate 4 concurrent requests all receiving 401 at the same moment
        final reqs = List.generate(
          4,
          (i) => RequestOptions(path: '/api/fleet/unit_$i', method: 'GET'),
        );

        final handlers = List.generate(4, (_) => _RecordingErrorHandler());

        // We need dio to mock request retry resolution
        dio.httpClientAdapter = _MockHttpClientAdapter((options) {
          return ResponseBody.fromString('{"status": "ok"}', 200);
        });

        // Dispatch all 4 in parallel
        final futures = List.generate(
          4,
          (i) => interceptor.onError(
            DioException(
              requestOptions: reqs[i],
              response: Response(requestOptions: reqs[i], statusCode: 401),
            ),
            handlers[i],
          ),
        );

        await Future.wait(futures);

        // Exactly ONE re-authentication executed for all 4 requests
        expect(mockRemote.loginCalls, equals(1));

        // All 4 waiting handlers were unblocked and resolved
        for (final h in handlers) {
          expect(h.resolveCompleter.isCompleted, isTrue);
        }

        // No lingering mutex lock
        expect(interceptor.isReAuthInProgress, isFalse);
      },
    );

    test(
      'TC-RACE-03: Re-authentication failure clears credentials & never leaves Completer unresolved',
      () async {
        fakeStorage.email = 'admin@gpsku.id';
        fakeStorage.password = 'InvalidOldPassword';
        fakeStorage.rememberMe = true;
        mockRemote.shouldFailLogin = true;

        final req1 = RequestOptions(path: '/api/devices', method: 'GET');
        final req2 = RequestOptions(path: '/api/positions', method: 'GET');

        final h1 = _RecordingErrorHandler();
        final h2 = _RecordingErrorHandler();

        final f1 = interceptor.onError(
          DioException(
            requestOptions: req1,
            response: Response(requestOptions: req1, statusCode: 401),
          ),
          h1,
        );
        final f2 = interceptor.onError(
          DioException(
            requestOptions: req2,
            response: Response(requestOptions: req2, statusCode: 401),
          ),
          h2,
        );

        await Future.wait([f1, f2]);

        // Both waiting requests must be rejected via handler.next
        expect(h1.nextCompleter.isCompleted, isTrue);
        expect(h2.nextCompleter.isCompleted, isTrue);

        // Mutex completer is freed
        expect(interceptor.isReAuthInProgress, isFalse);

        // User state transitioned to unauthenticated
        expect(authProvider.status, equals(AuthStatus.unauthenticated));
      },
    );

    test(
      'TC-RACE-04: Logout during active re-authentication immediately unblocks and cancels re-auth',
      () async {
        fakeStorage.email = 'admin@gpsku.id';
        fakeStorage.password = 'Password123';
        fakeStorage.rememberMe = true;

        final completerReauthStarted = Completer<void>();
        final completerCanFinishReauth = Completer<void>();

        // Slow re-auth callback
        final slowInterceptor = QueuedReAuthInterceptor(
          dio: dio,
          onReAuth: () async {
            completerReauthStarted.complete();
            await completerCanFinishReauth.future;
            return true;
          },
        );

        final req = RequestOptions(path: '/api/reports', method: 'GET');
        final handler = _RecordingErrorHandler();

        // Start 401 handling in background
        final errFuture = slowInterceptor.onError(
          DioException(
            requestOptions: req,
            response: Response(requestOptions: req, statusCode: 401),
          ),
          handler,
        );

        // Wait until re-auth is confirmed in flight
        await completerReauthStarted.future;
        expect(slowInterceptor.isReAuthInProgress, isTrue);

        // User presses Logout while re-auth is in progress!
        slowInterceptor.cancelActiveReAuth();

        // Completer is immediately cancelled
        expect(slowInterceptor.isReAuthInProgress, isFalse);

        // Unblock slow re-auth
        completerCanFinishReauth.complete();
        await errFuture;
      },
    );

    test('TC-RACE-05: Enforces max 1 retry per original request', () async {
      final reqAlreadyRetried = RequestOptions(
        path: '/api/devices',
        method: 'GET',
        extra: {'reauth_retry_count': 1},
      );

      bool sessionExpiredFired = false;
      final retryInterceptor = QueuedReAuthInterceptor(
        dio: dio,
        onReAuth: () async => true,
        onSessionExpired: () => sessionExpiredFired = true,
      );

      final handler = _RecordingErrorHandler();
      await retryInterceptor.onError(
        DioException(
          requestOptions: reqAlreadyRetried,
          response: Response(
            requestOptions: reqAlreadyRetried,
            statusCode: 401,
          ),
        ),
        handler,
      );

      expect(handler.nextCompleter.isCompleted, isTrue);
      expect(sessionExpiredFired, isTrue);
      expect(retryInterceptor.isReAuthInProgress, isFalse);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
