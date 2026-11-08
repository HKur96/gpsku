import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/sanitized_requests_inspector_interceptor.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SanitizedRequestsInspectorInterceptor Security Tests', () {
    late SanitizedRequestsInspectorInterceptor interceptor;

    setUp(() {
      InspectorController(
        enabled: true,
        showInspectorOn: ShowInspectorOn.LongPress,
      );
      interceptor = SanitizedRequestsInspectorInterceptor();
    });

    test(
      'TC-SRI-01: Header sanitization redacts sensitive auth and cookie tokens',
      () {
        final requestOptions = RequestOptions(
          path: '/api/session',
          headers: {
            'Authorization': 'Bearer super_secret_jwt_token',
            'Cookie': 'JSESSIONID=node01secret12345; rememberMe=true',
            'X-CSRF-Token': 'csrf_token_value',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'status': 'ok'},
        );

        interceptor.onResponse(response, ResponseInterceptorHandler());

        final recorded = InspectorController().requestsList.first;
        expect(recorded.headers['Authorization'], equals('[REDACTED]'));
        expect(recorded.headers['Cookie'], equals('[REDACTED]'));
        expect(recorded.headers['X-CSRF-Token'], equals('[REDACTED]'));
        expect(recorded.headers['Content-Type'], equals('application/json'));
        expect(recorded.headers['Accept'], equals('application/json'));
      },
    );

    test(
      'TC-SRI-02: Map payload sanitization redacts password and secret keys',
      () {
        final requestOptions = RequestOptions(
          path: '/api/session',
          method: 'POST',
          headers: {},
          data: {
            'email': 'fleet_manager@gpsku.id',
            'password': 'P@sswordSuperSecret123',
            'totp': '123456',
            'nested': {
              'apiKey': 'my_api_key',
              'token': 'secret_refresh_token',
              'safeField': 'visible_data',
            },
          },
        );

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'userId': 42},
        );

        interceptor.onResponse(response, ResponseInterceptorHandler());

        final recorded = InspectorController().requestsList.first;
        final body = recorded.requestBody as Map<String, dynamic>;

        expect(body['email'], equals('fleet_manager@gpsku.id'));
        expect(body['password'], equals('[REDACTED]'));
        expect(body['totp'], equals('[REDACTED]'));

        final nested = body['nested'] as Map<String, dynamic>;
        expect(nested['token'], equals('[REDACTED]'));
        expect(nested['safeField'], equals('visible_data'));
      },
    );

    test(
      'TC-SRI-03: URL-encoded string payload sanitizes password parameter',
      () {
        final requestOptions = RequestOptions(
          path: '/api/session',
          method: 'POST',
          headers: {},
          data:
              'email=admin%40traccar.org&password=secretpassword123&code=999888',
        );

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'id': 1},
        );

        interceptor.onResponse(response, ResponseInterceptorHandler());

        final recorded = InspectorController().requestsList.first;
        final sanitizedData = recorded.requestBody.toString();

        expect(sanitizedData, contains('email=admin@traccar.org'));
        expect(sanitizedData, contains('password=[REDACTED]'));
        expect(sanitizedData, isNot(contains('secretpassword123')));
      },
    );
  });
}
