import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/commands/data/datasources/commands_remote_data_source.dart';
import 'package:gpsku/features/commands/data/models/command_payload_model.dart';

class MockDioClient extends DioClient {
  dynamic mockResponseData;
  int mockStatusCode = 200;
  DioException? exceptionToThrow;
  String? lastPath;
  dynamic lastData;
  Map<String, dynamic>? lastQueryParams;
  Options? lastOptions;
  CancelToken? lastCancelToken;

  MockDioClient()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    lastQueryParams = queryParameters;
    lastOptions = options;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    final reqOptions = RequestOptions(
      path: path,
      queryParameters: queryParameters,
      headers: options?.headers,
    );

    return Response<T>(
      requestOptions: reqOptions,
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    lastData = data;
    lastQueryParams = queryParameters;
    lastOptions = options;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    final reqOptions = RequestOptions(
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: options?.headers,
    );

    return Response<T>(
      requestOptions: reqOptions,
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }
}

void main() {
  group('CommandsRemoteDataSource Unit Tests', () {
    late MockDioClient mockDioClient;
    late CommandsRemoteDataSourceImpl dataSource;

    setUp(() {
      mockDioClient = MockDioClient();
      dataSource = CommandsRemoteDataSourceImpl(dioClient: mockDioClient);
    });

    group('getSupportedCommands (GET /api/commands/types)', () {
      test(
        'TC-CRD-01: Dispatches GET request to /api/commands/types with correct params and headers',
        () async {
          mockDioClient.mockResponseData = [
            {'type': 'engineStop'},
            {'type': 'engineResume'},
            {'type': 'custom'},
          ];

          final result = await dataSource.getSupportedCommands(deviceId: 42);

          expect(mockDioClient.lastPath, equals(ApiEndpoints.commandsTypes));
          expect(mockDioClient.lastQueryParams, equals({'deviceId': 42}));
          expect(
            mockDioClient.lastOptions?.headers?['Accept'],
            equals('application/json'),
          );
          expect(
            mockDioClient.lastOptions?.headers?['Content-Type'],
            equals('application/json'),
          );
          expect(result.length, equals(3));
          expect(result[0].type, equals('engineStop'));
          expect(result[1].type, equals('engineResume'));
          expect(result[2].type, equals('custom'));
        },
      );

      test(
        'TC-CRD-02: Includes optional protocol and textChannel parameters when specified',
        () async {
          mockDioClient.mockResponseData = [
            {'type': 'sendSms'},
          ];

          await dataSource.getSupportedCommands(
            deviceId: 15,
            protocol: 'gt06',
            textChannel: true,
          );

          expect(mockDioClient.lastQueryParams?['deviceId'], equals(15));
          expect(mockDioClient.lastQueryParams?['protocol'], equals('gt06'));
          expect(mockDioClient.lastQueryParams?['textChannel'], isTrue);
        },
      );

      test(
        'TC-CRD-03: Propagates CancelToken to Dio client invocation',
        () async {
          mockDioClient.mockResponseData = [];
          final cancelToken = CancelToken();

          await dataSource.getSupportedCommands(
            deviceId: 99,
            cancelToken: cancelToken,
          );

          expect(mockDioClient.lastCancelToken, equals(cancelToken));
        },
      );

      test(
        'TC-CRD-04: Returns empty list when response data is null or empty',
        () async {
          mockDioClient.mockResponseData = null;
          final result1 = await dataSource.getSupportedCommands(deviceId: 10);
          expect(result1, isEmpty);

          mockDioClient.mockResponseData = [];
          final result2 = await dataSource.getSupportedCommands(deviceId: 10);
          expect(result2, isEmpty);
        },
      );

      test(
        'TC-CRD-05: Throws ServerException when response format is not a List',
        () async {
          mockDioClient.mockResponseData = {'error': 'Unexpected map'};

          expect(
            () => dataSource.getSupportedCommands(deviceId: 10),
            throwsA(isA<ServerException>()),
          );
        },
      );

      test(
        'TC-CRD-06: Throws ServerException when response array contains non-map item',
        () async {
          mockDioClient.mockResponseData = ['string-instead-of-map'];

          expect(
            () => dataSource.getSupportedCommands(deviceId: 10),
            throwsA(isA<ServerException>()),
          );
        },
      );

      test('TC-CRD-07: Maps HTTP 401 Unauthorized to AuthException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
            statusCode: 401,
          ),
        );

        expect(
          () => dataSource.getSupportedCommands(deviceId: 10),
          throwsA(isA<AuthException>()),
        );
      });

      test(
        'TC-CRD-08: Maps HTTP 403 Forbidden to ForbiddenException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
            response: Response(
              requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
              statusCode: 403,
            ),
          );

          expect(
            () => dataSource.getSupportedCommands(deviceId: 10),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'TC-CRD-09: Maps timeout errors to ConnectionTimeoutException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
            type: DioExceptionType.receiveTimeout,
            message: 'Timed out waiting for response',
          );

          expect(
            () => dataSource.getSupportedCommands(deviceId: 10),
            throwsA(isA<ConnectionTimeoutException>()),
          );
        },
      );

      test(
        'TC-CRD-10: Maps network connection and cancellation errors to NetworkException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsTypes),
            type: DioExceptionType.connectionError,
          );

          expect(
            () => dataSource.getSupportedCommands(deviceId: 10),
            throwsA(isA<NetworkException>()),
          );
        },
      );
    });

    group('sendCommand (POST /api/commands/send)', () {
      final tPayload = CommandPayloadModel(
        deviceId: 42,
        type: 'engineStop',
        attributes: const {},
      );

      test(
        'TC-CRD-11: Sends command with correct endpoint, body and headers',
        () async {
          mockDioClient.mockStatusCode = 200;
          mockDioClient.mockResponseData = {
            'id': 100,
            'deviceId': 42,
            'type': 'engineStop',
            'attributes': {},
          };

          final result = await dataSource.sendCommand(tPayload);

          expect(mockDioClient.lastPath, equals(ApiEndpoints.commandsSend));
          expect(mockDioClient.lastData, equals(tPayload.toJson()));
          expect(
            mockDioClient.lastOptions?.headers?['Content-Type'],
            equals('application/json'),
          );
          expect(result.deviceId, equals(42));
          expect(result.type, equals('engineStop'));
          expect(result.isQueued, isFalse);
        },
      );

      test(
        'TC-CRD-12: Correctly tags result as isQueued=true when HTTP 202 Accepted is returned',
        () async {
          mockDioClient.mockStatusCode = 202;
          mockDioClient.mockResponseData = {
            'id': 105,
            'deviceId': 42,
            'type': 'engineStop',
            'attributes': {},
          };

          final result = await dataSource.sendCommand(tPayload);

          expect(result.isQueued, isTrue);
          expect(result.deviceId, equals(42));
        },
      );

      test(
        'TC-CRD-13: Handles List response (queued group command) by extracting first item',
        () async {
          mockDioClient.mockStatusCode = 202;
          mockDioClient.mockResponseData = [
            {'id': 201, 'deviceId': 42, 'type': 'engineStop', 'attributes': {}},
            {'id': 202, 'deviceId': 43, 'type': 'engineStop', 'attributes': {}},
          ];

          final result = await dataSource.sendCommand(tPayload);

          expect(result.id, equals(201));
          expect(result.deviceId, equals(42));
          expect(result.isQueued, isTrue);
        },
      );

      test(
        'TC-CRD-14: Gracefully falls back when response body is string or empty',
        () async {
          mockDioClient.mockStatusCode = 200;
          mockDioClient.mockResponseData = 'OK';

          final result = await dataSource.sendCommand(tPayload);

          expect(result.deviceId, equals(42));
          expect(result.type, equals('engineStop'));
          expect(result.isQueued, isFalse);
        },
      );

      test('TC-CRD-15: Maps HTTP 400 Bad Request to ServerException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
            statusCode: 400,
            data: 'Command not supported by device protocol',
          ),
        );

        expect(
          () => dataSource.sendCommand(tPayload),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              contains('Command not supported by device protocol'),
            ),
          ),
        );
      });

      test(
        'TC-CRD-16: Maps HTTP 403 Forbidden to ForbiddenException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
            response: Response(
              requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
              statusCode: 403,
              data: 'User restricted from sending commands',
            ),
          );

          expect(
            () => dataSource.sendCommand(tPayload),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test('TC-CRD-17: Maps HTTP 401 Unauthorized to AuthException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
            statusCode: 401,
          ),
        );

        expect(
          () => dataSource.sendCommand(tPayload),
          throwsA(isA<AuthException>()),
        );
      });

      test(
        'TC-CRD-18: Maps timeout during send to ConnectionTimeoutException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: RequestOptions(path: ApiEndpoints.commandsSend),
            type: DioExceptionType.sendTimeout,
          );

          expect(
            () => dataSource.sendCommand(tPayload),
            throwsA(isA<ConnectionTimeoutException>()),
          );
        },
      );
    });
  });
}
