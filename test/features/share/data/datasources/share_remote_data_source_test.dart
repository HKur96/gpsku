import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/share/data/datasources/share_remote_data_source.dart';

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
      queryParameters: queryParameters,
      headers: options?.headers,
      contentType: options?.contentType,
    );

    return Response<T>(
      requestOptions: reqOptions,
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }
}

void main() {
  late MockDioClient mockDio;
  late ShareRemoteDataSourceImpl dataSource;

  final tFutureExpiration = DateTime.now().add(const Duration(days: 7));
  const tToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.device_share_token_abc';

  setUp(() {
    mockDio = MockDioClient();
    dataSource = ShareRemoteDataSourceImpl(dioClient: mockDio);
  });

  group('ShareRemoteDataSourceImpl Unit Tests', () {
    test(
      'TC-SRD-01: createDeviceShareToken posts to /api/share/device and returns token',
      () async {
        mockDio.mockResponseData = tToken;
        mockDio.mockStatusCode = 200;

        final cancelToken = CancelToken();
        final result = await dataSource.createDeviceShareToken(
          deviceId: 42,
          expiration: tFutureExpiration,
          cancelToken: cancelToken,
        );

        expect(result, tToken);
        expect(mockDio.lastPath, ApiEndpoints.shareDevice);
        expect(
          mockDio.lastOptions?.contentType,
          Headers.formUrlEncodedContentType,
        );
        expect(mockDio.lastCancelToken, cancelToken);

        final data = mockDio.lastData as Map<String, dynamic>;
        expect(data['deviceId'], 42);
        expect(data['expiration'], tFutureExpiration.toUtc().toIso8601String());
      },
    );

    test(
      'TC-SRD-02: createDeviceShareToken throws ServerException if expiration is in the past',
      () async {
        final pastExpiration = DateTime.now().subtract(const Duration(days: 1));

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: pastExpiration,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              contains('Waktu kedaluwarsa tidak boleh di masa lalu'),
            ),
          ),
        );
      },
    );

    test(
      'TC-SRD-03: createDeviceShareToken throws AuthException on 401 Unauthorized',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
            statusCode: 401,
          ),
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(isA<AuthException>()),
        );
      },
    );

    test(
      'TC-SRD-04: createDeviceShareToken throws ForbiddenException on 403 Forbidden',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
            statusCode: 403,
          ),
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(
            isA<ForbiddenException>().having(
              (e) => e.message,
              'message',
              contains('Fitur berbagi publik dinonaktifkan'),
            ),
          ),
        );
      },
    );

    test(
      'TC-SRD-05: createDeviceShareToken throws ConflictException(409) on Conflict',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
            statusCode: 409,
          ),
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(
            isA<ConflictException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );
      },
    );

    test(
      'TC-SRD-06: createDeviceShareToken throws ServerException on 400 Bad Request',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
            statusCode: 400,
            data: 'Invalid parameter',
          ),
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test(
      'TC-SRD-07: createDeviceShareToken throws ConnectionTimeoutException on timeout',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-SRD-08: createDeviceShareToken throws NetworkException on connection error',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          type: DioExceptionType.connectionError,
          message: 'Network socket failure',
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'TC-SRD-09: createDeviceShareToken throws NetworkException on request cancellation',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.shareDevice),
          type: DioExceptionType.cancel,
        );

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.message,
              'message',
              contains('dibatalkan'),
            ),
          ),
        );
      },
    );

    test(
      'TC-SRD-10: createDeviceShareToken throws ServerException when token returned is empty',
      () async {
        mockDio.mockResponseData = '   ';

        expect(
          () => dataSource.createDeviceShareToken(
            deviceId: 42,
            expiration: tFutureExpiration,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              contains('kosong'),
            ),
          ),
        );
      },
    );

    test(
      'TC-SRD-11: createGroupShareToken posts to /api/share/group and returns token',
      () async {
        mockDio.mockResponseData = 'group_token_xyz';
        mockDio.mockStatusCode = 200;

        final result = await dataSource.createGroupShareToken(
          groupId: 7,
          expiration: tFutureExpiration,
        );

        expect(result, 'group_token_xyz');
        expect(mockDio.lastPath, ApiEndpoints.shareGroup);
        final data = mockDio.lastData as Map<String, dynamic>;
        expect(data['groupId'], 7);
      },
    );

    test(
      'TC-SRD-12: createUserSessionToken posts to /api/session/token and returns token',
      () async {
        mockDio.mockResponseData = 'session_token_123';
        mockDio.mockStatusCode = 200;

        final result = await dataSource.createUserSessionToken(
          expiration: tFutureExpiration,
        );

        expect(result, 'session_token_123');
        expect(mockDio.lastPath, ApiEndpoints.sessionToken);
        final data = mockDio.lastData as Map<String, dynamic>;
        expect(data['expiration'], tFutureExpiration.toUtc().toIso8601String());
      },
    );
  });
}
