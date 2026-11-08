import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/sanitized_requests_inspector_interceptor.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inspector Security Audit & Immutability Verification', () {
    late SanitizedRequestsInspectorInterceptor interceptor;

    setUp(() {
      InspectorController(
        enabled: true,
        showInspectorOn: ShowInspectorOn.LongPress,
      );
      interceptor = SanitizedRequestsInspectorInterceptor();
      InspectorController().clearAllRequests();
    });

    test(
      'TC-ISA-01: Case-insensitive header masking (UPPERCASE, mixed case)',
      () {
        final req = RequestOptions(
          path: '/api/session',
          headers: {
            'AUTHORIZATION': 'Bearer secret_jwt',
            'Cookie': 'JSESSIONID=node01secret',
            'set-cookie': 'JSESSIONID=newsecret; Path=/',
            'X-CSRF-TOKEN': 'csrf_val',
            'Normal-Header': 'KeepMe',
          },
        );

        final res = Response(requestOptions: req, statusCode: 200, data: {});
        interceptor.onResponse(res, ResponseInterceptorHandler());

        final recorded = InspectorController().requestsList.first;
        expect(recorded.headers['AUTHORIZATION'], equals('[REDACTED]'));
        expect(recorded.headers['Cookie'], equals('[REDACTED]'));
        expect(recorded.headers['set-cookie'], equals('[REDACTED]'));
        expect(recorded.headers['X-CSRF-TOKEN'], equals('[REDACTED]'));
        expect(recorded.headers['Normal-Header'], equals('KeepMe'));
      },
    );

    test('TC-ISA-02: Query parameters masking for sensitive keys', () {
      final req = RequestOptions(
        path:
            '/api/session?token=secret_query_token&password=my_password&safe=visible',
        queryParameters: {
          'token': 'secret_query_token',
          'password': 'my_password',
          'safe': 'visible',
        },
      );

      final res = Response(requestOptions: req, statusCode: 200, data: {});
      interceptor.onResponse(res, ResponseInterceptorHandler());

      final recorded = InspectorController().requestsList.first;
      expect(recorded.queryParameters['token'], equals('[REDACTED]'));
      expect(recorded.queryParameters['password'], equals('[REDACTED]'));
      expect(recorded.queryParameters['safe'], equals('visible'));
    });

    test(
      'TC-ISA-03: Nested JSON objects and arrays containing sensitive keys',
      () {
        final originalData = {
          'users': [
            {'id': 1, 'email': 'user1@gpsku.id', 'password': 'Password1!'},
            {'id': 2, 'email': 'user2@gpsku.id', 'password': 'Password2!'},
          ],
          'authConfig': {
            'apiToken': 'secret_api_token',
            'salt': 'database_salt_hash',
            'totpSecret': 'JBSWY3DPEHPK3PXP',
            'publicFlag': true,
          },
        };

        final req = RequestOptions(path: '/api/users', data: originalData);

        final res = Response(requestOptions: req, statusCode: 200, data: {});
        interceptor.onResponse(res, ResponseInterceptorHandler());

        final recorded = InspectorController().requestsList.first;
        final body = recorded.requestBody as Map<String, dynamic>;

        // Verify array elements redacted
        final users = body['users'] as List;
        expect(users[0]['password'], equals('[REDACTED]'));
        expect(users[0]['email'], equals('user1@gpsku.id'));
        expect(users[1]['password'], equals('[REDACTED]'));

        // Verify nested object redacted
        final config = body['authConfig'] as Map<String, dynamic>;
        expect(config['apiToken'], equals('[REDACTED]'));
        expect(config['salt'], equals('[REDACTED]'));
        expect(config['totpSecret'], equals('[REDACTED]'));
        expect(config['publicFlag'], isTrue);
      },
    );

    test(
      'TC-ISA-04: Non-mutation guarantee — Original RequestOptions data is never mutated',
      () {
        final originalMap = <String, dynamic>{
          'email': 'admin@gpsku.id',
          'password': 'RawUnsanitizedPassword123!',
        };

        final req = RequestOptions(
          path: '/api/session',
          method: 'POST',
          data: originalMap,
          headers: {'Authorization': 'Bearer RawToken123'},
        );

        final res = Response(requestOptions: req, statusCode: 200, data: {});
        interceptor.onResponse(res, ResponseInterceptorHandler());

        // Recorded request in inspector MUST be redacted
        final recorded = InspectorController().requestsList.first;
        expect(recorded.headers['Authorization'], equals('[REDACTED]'));
        expect((recorded.requestBody as Map)['password'], equals('[REDACTED]'));

        // BUT original requestOptions data MUST remain untouched so Dio transmits raw password to backend!
        expect(req.headers['Authorization'], equals('Bearer RawToken123'));
        expect(originalMap['password'], equals('RawUnsanitizedPassword123!'));
      },
    );

    test('TC-ISA-05: Form URL-encoded string payload sanitization', () {
      const originalForm =
          'email=admin%40gpsku.id&password=SuperSecretPassword&totp=654321';
      final req = RequestOptions(
        path: '/api/session',
        method: 'POST',
        data: originalForm,
      );

      final res = Response(requestOptions: req, statusCode: 200, data: {});
      interceptor.onResponse(res, ResponseInterceptorHandler());

      final recorded = InspectorController().requestsList.first;
      final sanitizedString = recorded.requestBody.toString();

      expect(sanitizedString, contains('password=[REDACTED]'));
      expect(sanitizedString, contains('totp=[REDACTED]'));
      expect(sanitizedString, isNot(contains('SuperSecretPassword')));

      // Original data string is completely preserved
      expect(req.data, equals(originalForm));
    });
  });
}
