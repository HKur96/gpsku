import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';

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
  group('MaintenanceRemoteDataSourceImpl Tests', () {
    late MockDioClient mockDio;
    late MaintenanceRemoteDataSourceImpl dataSource;

    final tMaintenance = const MaintenanceModel(
      id: 201,
      name: 'Ganti Filter Udara',
      type: 'totalDistance',
      start: 20000000.0,
      period: 10000000.0,
      attributes: {'brand': 'OEM'},
    );

    final tMaintenanceJson = {
      'id': 201,
      'name': 'Ganti Filter Udara',
      'type': 'totalDistance',
      'start': 20000000.0,
      'period': 10000000.0,
      'attributes': {'brand': 'OEM'},
    };

    setUp(() {
      mockDio = MockDioClient();
      dataSource = MaintenanceRemoteDataSourceImpl(dioClient: mockDio);
    });

    test(
      'TC-MDS-01: Fetches maintenance list successfully from /api/maintenance',
      () async {
        mockDio.mockResponseData = [tMaintenanceJson];

        final result = await dataSource.getMaintenances();

        expect(mockDio.lastPath, equals(ApiEndpoints.maintenance));
        expect(
          mockDio.lastOptions?.headers?['Accept'],
          equals('application/json'),
        );
        expect(result.length, equals(1));
        expect(result.first.id, equals(201));
        expect(result.first.name, equals('Ganti Filter Udara'));
      },
    );

    test(
      'TC-MDS-02: Returns empty list when API returns non-list response',
      () async {
        mockDio.mockResponseData = {'error': 'unexpected map'};

        final result = await dataSource.getMaintenances();

        expect(result, isEmpty);
      },
    );

    test(
      'TC-MDS-03: Passes query parameters (all, userId, deviceId, groupId)',
      () async {
        mockDio.mockResponseData = [];

        await dataSource.getMaintenances(
          all: true,
          userId: 10,
          deviceId: 42,
          groupId: 5,
        );

        expect(mockDio.lastQueryParams?['all'], equals(true));
        expect(mockDio.lastQueryParams?['userId'], equals(10));
        expect(mockDio.lastQueryParams?['deviceId'], equals(42));
        expect(mockDio.lastQueryParams?['groupId'], equals(5));
      },
    );

    test('TC-MDS-04: Passes CancelToken properly on GET requests', () async {
      mockDio.mockResponseData = [];
      final cancelToken = CancelToken();

      await dataSource.getMaintenances(cancelToken: cancelToken);

      expect(mockDio.lastCancelToken, equals(cancelToken));
    });

    test(
      'TC-MDS-05: Creates maintenance schedule successfully via POST',
      () async {
        mockDio.mockResponseData = tMaintenanceJson;

        final result = await dataSource.createMaintenance(tMaintenance);

        expect(mockDio.lastPath, equals(ApiEndpoints.maintenance));
        expect(result.id, equals(201));
        expect(result.name, equals('Ganti Filter Udara'));
      },
    );

    test(
      'TC-MDS-06: Strips id=0 from request payload when creating new item',
      () async {
        mockDio.mockResponseData = tMaintenanceJson;
        final newMaintenance = tMaintenance.copyWith(id: 0);

        await dataSource.createMaintenance(newMaintenance);

        expect(mockDio.lastData, isA<Map<String, dynamic>>());
        expect(
          (mockDio.lastData as Map<String, dynamic>).containsKey('id'),
          isFalse,
        );
      },
    );

    test(
      'TC-MDS-07: Updates maintenance via PUT /api/maintenance/{id}',
      () async {
        mockDio.mockResponseData = tMaintenanceJson;

        final result = await dataSource.updateMaintenance(tMaintenance);

        expect(mockDio.lastPath, equals('${ApiEndpoints.maintenance}/201'));
        expect(result.id, equals(201));
      },
    );

    test(
      'TC-MDS-08: Deletes maintenance via DELETE /api/maintenance/{id}',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.deleteMaintenance(201);

        expect(mockDio.lastPath, equals('${ApiEndpoints.maintenance}/201'));
      },
    );

    test('TC-MDS-09: Links device via POST /api/permissions', () async {
      mockDio.mockResponseData = null;

      await dataSource.linkDeviceMaintenance(deviceId: 77, maintenanceId: 201);

      expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
      expect(mockDio.lastData, equals({'deviceId': 77, 'maintenanceId': 201}));
    });

    test('TC-MDS-10: Unlinks device via DELETE /api/permissions', () async {
      mockDio.mockResponseData = null;

      await dataSource.unlinkDeviceMaintenance(
        deviceId: 77,
        maintenanceId: 201,
      );

      expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
      expect(mockDio.lastData, equals({'deviceId': 77, 'maintenanceId': 201}));
    });

    test('TC-MDS-11: Throws AuthException on HTTP 401', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          statusCode: 401,
        ),
      );

      expect(() => dataSource.getMaintenances(), throwsA(isA<AuthException>()));
    });

    test('TC-MDS-12: Throws ForbiddenException on HTTP 403', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          statusCode: 403,
        ),
      );

      expect(
        () => dataSource.getMaintenances(),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test(
      'TC-MDS-13: Throws ConnectionTimeoutException on connectionTimeout',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout connecting to Traccar',
        );

        expect(
          () => dataSource.getMaintenances(),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-MDS-14: Throws NetworkException on connectionError or cancel',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          type: DioExceptionType.connectionError,
          message: 'Socket error',
        );

        expect(
          () => dataSource.getMaintenances(),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'TC-MDS-15: Throws ServerException on HTTP 500 or unknown errors',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
            statusCode: 500,
            data: 'Internal error',
          ),
        );

        expect(
          () => dataSource.getMaintenances(),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('TC-MDS-16: Throws ServerException on HTTP 400 Bad Request', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.maintenance),
          statusCode: 400,
          data: 'Invalid parameters',
        ),
      );

      expect(
        () => dataSource.getMaintenances(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
