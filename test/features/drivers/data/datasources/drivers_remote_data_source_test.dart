import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/drivers/data/datasources/drivers_remote_data_source.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';

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

  @override
  Future<Response<T>> put<T>(
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

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
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
  late MockDioClient mockDioClient;
  late DriversRemoteDataSourceImpl dataSource;

  const tDriver = DriverModel(
    id: 1,
    name: 'Budi Santoso',
    uniqueId: 'RFID-123',
    attributes: {'phone': '08123456789'},
  );

  setUp(() {
    mockDioClient = MockDioClient();
    dataSource = DriversRemoteDataSourceImpl(dioClient: mockDioClient);
  });

  DioException createDioException({
    required DioExceptionType type,
    int? statusCode,
    String? message,
    dynamic responseData,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: ApiEndpoints.drivers),
      type: type,
      message: message,
      response: Response(
        requestOptions: RequestOptions(path: ApiEndpoints.drivers),
        statusCode: statusCode,
        data: responseData,
      ),
    );
  }

  group('DriversRemoteDataSource CRUD & Permissions Tests', () {
    test(
      'TC-DDS-01: getDrivers sends GET /api/drivers with default headers',
      () async {
        mockDioClient.mockResponseData = [
          {
            'id': 1,
            'name': 'Budi Santoso',
            'uniqueId': 'RFID-123',
            'attributes': {'phone': '08123456789'},
          },
        ];

        final result = await dataSource.getDrivers();

        expect(mockDioClient.lastPath, equals(ApiEndpoints.drivers));
        expect(
          mockDioClient.lastOptions?.headers?['Accept'],
          equals('application/json'),
        );
        expect(result.length, equals(1));
        expect(result.first.name, equals('Budi Santoso'));
      },
    );

    test('TC-DDS-02: getDrivers correctly passes query parameters', () async {
      mockDioClient.mockResponseData = [];

      await dataSource.getDrivers(
        all: true,
        userId: 5,
        deviceId: 10,
        groupId: 2,
      );

      expect(mockDioClient.lastQueryParams?['all'], equals(true));
      expect(mockDioClient.lastQueryParams?['userId'], equals(5));
      expect(mockDioClient.lastQueryParams?['deviceId'], equals(10));
      expect(mockDioClient.lastQueryParams?['groupId'], equals(2));
    });

    test(
      'TC-DDS-03: getDrivers returns empty list when response data is not a list',
      () async {
        mockDioClient.mockResponseData = null;

        final result = await dataSource.getDrivers();

        expect(result, isEmpty);
      },
    );

    test(
      'TC-DDS-04: createDriver sends POST /api/drivers and strips id=0',
      () async {
        mockDioClient.mockResponseData = {
          'id': 99,
          'name': 'New Driver',
          'uniqueId': 'NEW-RFID',
        };

        const newDriver = DriverModel(
          id: 0,
          name: 'New Driver',
          uniqueId: 'NEW-RFID',
        );

        final result = await dataSource.createDriver(newDriver);

        expect(mockDioClient.lastPath, equals(ApiEndpoints.drivers));
        final sentData = mockDioClient.lastData as Map<String, dynamic>;
        expect(sentData.containsKey('id'), isFalse);
        expect(sentData['name'], equals('New Driver'));
        expect(result.id, equals(99));
      },
    );

    test('TC-DDS-05: updateDriver sends PUT /api/drivers/{id}', () async {
      mockDioClient.mockResponseData = tDriver.toJson();

      final result = await dataSource.updateDriver(tDriver);

      expect(mockDioClient.lastPath, equals('${ApiEndpoints.drivers}/1'));
      expect(result.id, equals(1));
      expect(result.name, equals('Budi Santoso'));
    });

    test('TC-DDS-06: deleteDriver sends DELETE /api/drivers/{id}', () async {
      mockDioClient.mockResponseData = null;

      await dataSource.deleteDriver(1);

      expect(mockDioClient.lastPath, equals('${ApiEndpoints.drivers}/1'));
    });

    test(
      'TC-DDS-07: linkDeviceDriver sends POST /api/permissions with deviceId and driverId',
      () async {
        mockDioClient.mockResponseData = null;

        await dataSource.linkDeviceDriver(deviceId: 10, driverId: 1);

        expect(mockDioClient.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDioClient.lastData, equals({'deviceId': 10, 'driverId': 1}));
      },
    );

    test(
      'TC-DDS-08: unlinkDeviceDriver sends DELETE /api/permissions with deviceId and driverId',
      () async {
        mockDioClient.mockResponseData = null;

        await dataSource.unlinkDeviceDriver(deviceId: 10, driverId: 1);

        expect(mockDioClient.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDioClient.lastData, equals({'deviceId': 10, 'driverId': 1}));
      },
    );
  });

  group('DriversRemoteDataSource Error Handling Tests', () {
    test('TC-DDS-09: Throws AuthException on HTTP 401', () async {
      mockDioClient.exceptionToThrow = createDioException(
        type: DioExceptionType.badResponse,
        statusCode: 401,
      );

      expect(() => dataSource.getDrivers(), throwsA(isA<AuthException>()));
    });

    test('TC-DDS-10: Throws ForbiddenException on HTTP 403', () async {
      mockDioClient.exceptionToThrow = createDioException(
        type: DioExceptionType.badResponse,
        statusCode: 403,
      );

      expect(
        () => dataSource.createDriver(tDriver),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('TC-DDS-11: Throws ServerException on HTTP 400', () async {
      mockDioClient.exceptionToThrow = createDioException(
        type: DioExceptionType.badResponse,
        statusCode: 400,
        responseData: 'Bad driver payload',
      );

      expect(
        () => dataSource.updateDriver(tDriver),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'TC-DDS-12: Throws ConnectionTimeoutException on connectionTimeout',
      () async {
        mockDioClient.exceptionToThrow = createDioException(
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout connecting to Traccar',
        );

        expect(
          () => dataSource.deleteDriver(1),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test('TC-DDS-13: Throws NetworkException on connectionError', () async {
      mockDioClient.exceptionToThrow = createDioException(
        type: DioExceptionType.connectionError,
        message: 'Socket connection failed',
      );

      expect(
        () => dataSource.linkDeviceDriver(deviceId: 10, driverId: 1),
        throwsA(isA<NetworkException>()),
      );
    });

    test('TC-DDS-14: Throws NetworkException on request cancel', () async {
      mockDioClient.exceptionToThrow = createDioException(
        type: DioExceptionType.cancel,
        message: 'Cancelled by client',
      );

      expect(
        () => dataSource.unlinkDeviceDriver(deviceId: 10, driverId: 1),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'TC-DDS-15: Throws ServerException on unexpected HTTP 500 error',
      () async {
        mockDioClient.exceptionToThrow = createDioException(
          type: DioExceptionType.badResponse,
          statusCode: 500,
          responseData: 'Internal Server Error',
        );

        expect(() => dataSource.getDrivers(), throwsA(isA<ServerException>()));
      },
    );
  });
}
