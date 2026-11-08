import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/reports/data/datasources/reports_remote_data_source.dart';

class MockDioClient extends DioClient {
  dynamic mockResponseData;
  int mockStatusCode = 200;
  DioException? exceptionToThrow;
  String? lastPath;
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
}

void main() {
  group('ReportsRemoteDataSource Unit Tests', () {
    late MockDioClient mockDioClient;
    late ReportsRemoteDataSourceImpl dataSource;

    final tFrom = DateTime.utc(2026, 11, 8, 8, 0, 0);
    final tTo = DateTime.utc(2026, 11, 8, 17, 0, 0);

    setUp(() {
      mockDioClient = MockDioClient();
      dataSource = ReportsRemoteDataSourceImpl(dioClient: mockDioClient);
    });

    test(
      'TC-RDS-01: getRouteReport sends proper endpoint, parameters, and Accept header',
      () async {
        mockDioClient.mockResponseData = [
          {
            'id': 101,
            'deviceId': 42,
            'serverTime': '2026-11-08T08:05:00.000Z',
            'fixTime': '2026-11-08T08:05:00.000Z',
            'latitude': -6.2088,
            'longitude': 106.8456,
            'speed': 15.0,
            'course': 90.0,
          },
        ];

        final result = await dataSource.getRouteReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(mockDioClient.lastPath, ApiEndpoints.reportsRoute);
        expect(mockDioClient.lastQueryParams, {
          'deviceId': 42,
          'from': '2026-11-08T08:00:00.000Z',
          'to': '2026-11-08T17:00:00.000Z',
        });
        expect(
          mockDioClient.lastOptions?.headers?['Accept'],
          'application/json',
        );
        expect(result.length, 1);
        expect(result.first.id, 101);
        expect(result.first.deviceId, 42);
        expect(result.first.latitude, -6.2088);
      },
    );

    test(
      'TC-RDS-02: getRouteReport safely handles large payloads (>2,000 points)',
      () async {
        final largeList = List.generate(
          2500,
          (i) => {
            'id': 1000 + i,
            'deviceId': 42,
            'serverTime': '2026-11-08T08:00:00.000Z',
            'fixTime': '2026-11-08T08:00:00.000Z',
            'latitude': -6.2000 + (i * 0.0001),
            'longitude': 106.8000 + (i * 0.0001),
            'speed': 20.0,
            'course': 180.0,
          },
        );
        mockDioClient.mockResponseData = largeList;

        final result = await dataSource.getRouteReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.length, 2500);
        expect(result.first.id, 1000);
        expect(result.last.id, 3499);
      },
    );

    test(
      'TC-RDS-03: getRouteReport returns empty list when server responds with []',
      () async {
        mockDioClient.mockResponseData = [];

        final result = await dataSource.getRouteReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result, isEmpty);
      },
    );

    test(
      'TC-RDS-04: getTripReport queries /api/reports/trips and deserializes trips list',
      () async {
        mockDioClient.mockResponseData = [
          {
            'deviceId': 42,
            'deviceName': 'Truck 01',
            'distance': 15000.0,
            'averageSpeed': 22.0,
            'maxSpeed': 40.0,
            'startTime': '2026-11-08T08:00:00.000Z',
            'endTime': '2026-11-08T08:45:00.000Z',
            'duration': 2700000,
          },
        ];

        final result = await dataSource.getTripReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(mockDioClient.lastPath, ApiEndpoints.reportsTrips);
        expect(mockDioClient.lastQueryParams?['deviceId'], 42);
        expect(
          mockDioClient.lastOptions?.headers?['Accept'],
          'application/json',
        );
        expect(result.length, 1);
        expect(result.first.deviceId, 42);
        expect(result.first.distance, 15000.0);
      },
    );

    test(
      'TC-RDS-05: getTripReport returns empty list when server responds with []',
      () async {
        mockDioClient.mockResponseData = [];

        final result = await dataSource.getTripReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result, isEmpty);
      },
    );

    test(
      'TC-RDS-06: getStopReport queries /api/reports/stops and deserializes stops list',
      () async {
        mockDioClient.mockResponseData = [
          {
            'deviceId': 42,
            'deviceName': 'Truck 01',
            'distance': 0.0,
            'averageSpeed': 0.0,
            'maxSpeed': 0.0,
            'startTime': '2026-11-08T09:00:00.000Z',
            'endTime': '2026-11-08T09:30:00.000Z',
            'positionId': 505,
            'latitude': -6.2100,
            'longitude': 106.8500,
            'duration': 1800000,
            'engineHours': 0,
          },
        ];

        final result = await dataSource.getStopReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(mockDioClient.lastPath, ApiEndpoints.reportsStops);
        expect(mockDioClient.lastQueryParams?['deviceId'], 42);
        expect(
          mockDioClient.lastOptions?.headers?['Accept'],
          'application/json',
        );
        expect(result.length, 1);
        expect(result.first.deviceId, 42);
        expect(result.first.positionId, 505);
      },
    );

    test(
      'TC-RDS-07: getStopReport returns empty list when server responds with []',
      () async {
        mockDioClient.mockResponseData = [];

        final result = await dataSource.getStopReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result, isEmpty);
      },
    );

    test('TC-RDS-08: Translates HTTP 401 into AuthException', () async {
      mockDioClient.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
          statusCode: 401,
        ),
      );

      expect(
        () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
        throwsA(isA<AuthException>()),
      );
    });

    test('TC-RDS-09: Translates HTTP 403 into ServerException', () async {
      mockDioClient.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
          statusCode: 403,
        ),
      );

      expect(
        () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test(
      'TC-RDS-10: Translates connectionTimeout to ConnectionTimeoutException',
      () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout connecting',
        );

        expect(
          () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test('TC-RDS-11: Translates connectionError to NetworkException', () async {
      mockDioClient.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
        type: DioExceptionType.connectionError,
        message: 'No internet',
      );

      expect(
        () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
        throwsA(isA<NetworkException>()),
      );
    });

    test('TC-RDS-12: Translates cancel to NetworkException', () async {
      mockDioClient.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reportsRoute),
        type: DioExceptionType.cancel,
        message: 'Cancelled by user',
      );

      expect(
        () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'TC-RDS-13: Translates malformed response format into ServerException',
      () async {
        mockDioClient.mockResponseData = {'error': 'Not an array'};

        expect(
          () => dataSource.getRouteReport(deviceId: 42, from: tFrom, to: tTo),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('TC-RDS-14: Propagates CancelToken to Dio client', () async {
      final token = CancelToken();
      mockDioClient.mockResponseData = [];

      await dataSource.getRouteReport(
        deviceId: 42,
        from: tFrom,
        to: tTo,
        cancelToken: token,
      );

      expect(mockDioClient.lastCancelToken, same(token));
    });
  });
}
