import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/queued_reauth_interceptor.dart';

void main() {
  group('QueuedReAuthInterceptor Mutex & Concurrency Tests', () {
    late Dio mockDio;

    setUp(() {
      mockDio = Dio();
    });

    test(
      'TC-QRA-01: Excludes POST /api/session from triggering re-authentication',
      () async {
        int reauthCallCount = 0;
        final interceptor = QueuedReAuthInterceptor(
          dio: mockDio,
          onReAuth: () async {
            reauthCallCount++;
            return true;
          },
        );

        final reqOptions = RequestOptions(path: '/api/session', method: 'POST');

        final error = DioException(
          requestOptions: reqOptions,
          response: Response(requestOptions: reqOptions, statusCode: 401),
        );

        bool handlerNextCalled = false;

        // We test error handling
        await interceptor.onError(
          error,
          _MockErrorHandler(onNext: (_) => handlerNextCalled = true),
        );

        expect(
          reauthCallCount,
          equals(0),
          reason: 'Login endpoint must not trigger re-auth',
        );
        expect(handlerNextCalled, isTrue);
      },
    );

    test(
      'TC-QRA-02: Mutex serializes concurrent 401 requests into exactly one reauth invocation',
      () async {
        int reauthCallCount = 0;
        final interceptor = QueuedReAuthInterceptor(
          dio: mockDio,
          onReAuth: () async {
            reauthCallCount++;
            await Future.delayed(const Duration(milliseconds: 50));
            return true;
          },
        );

        final req1 = RequestOptions(path: '/api/devices', method: 'GET');
        final req2 = RequestOptions(path: '/api/positions', method: 'GET');

        final err1 = DioException(
          requestOptions: req1,
          response: Response(requestOptions: req1, statusCode: 401),
        );
        final err2 = DioException(
          requestOptions: req2,
          response: Response(requestOptions: req2, statusCode: 401),
        );

        // Simulate simultaneous 401 failures
        final f1 = interceptor.onError(err1, _MockErrorHandler());
        final f2 = interceptor.onError(err2, _MockErrorHandler());

        await Future.wait([f1, f2]);

        // Exactly ONE re-auth should have executed for both concurrent requests
        expect(reauthCallCount, equals(1));
      },
    );

    test(
      'TC-QRA-03: Enforces single retry limit preventing infinite loop',
      () async {
        int reauthCallCount = 0;
        bool sessionExpiredNotified = false;

        final interceptor = QueuedReAuthInterceptor(
          dio: mockDio,
          onReAuth: () async {
            reauthCallCount++;
            return true;
          },
          onSessionExpired: () {
            sessionExpiredNotified = true;
          },
        );

        // Request that was ALREADY retried once
        final retriedReq = RequestOptions(
          path: '/api/devices',
          method: 'GET',
          extra: {'reauth_retry_count': 1},
        );

        final err = DioException(
          requestOptions: retriedReq,
          response: Response(requestOptions: retriedReq, statusCode: 401),
        );

        bool nextCalled = false;
        await interceptor.onError(
          err,
          _MockErrorHandler(onNext: (_) => nextCalled = true),
        );

        expect(
          reauthCallCount,
          equals(0),
          reason: 'Must not re-auth when retry count >= 1',
        );
        expect(sessionExpiredNotified, isTrue);
        expect(nextCalled, isTrue);
      },
    );
  });
}

class _MockErrorHandler extends ErrorInterceptorHandler {
  final void Function(DioException)? onNext;

  _MockErrorHandler({this.onNext});

  @override
  void next(DioException err) {
    onNext?.call(err);
  }
}
