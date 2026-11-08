import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/geofences/data/datasources/geofences_remote_data_source.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';

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
  group('GeofencesRemoteDataSource Unit Tests', () {
    late MockDioClient mockDioClient;
    late GeofencesRemoteDataSourceImpl dataSource;

    setUp(() {
      mockDioClient = MockDioClient();
      dataSource = GeofencesRemoteDataSourceImpl(dioClient: mockDioClient);
    });

    const samplePolygonWkt =
        'POLYGON ((-6.20 106.81, -6.21 106.82, -6.22 106.80, -6.20 106.81))';
    const sampleCircleWkt = 'CIRCLE (-6.2088 106.8456, 500)';

    group('getGeofences (GET /api/geofences)', () {
      test(
        'TC-GDS-01: Returns parsed GeofenceModel list on HTTP 200 OK',
        () async {
          mockDioClient.mockResponseData = [
            {
              'id': 10,
              'name': 'Gudang Cakung',
              'description': 'Perimeter gudang',
              'area': samplePolygonWkt,
              'attributes': {'color': '#1E88E5'},
            },
            {
              'id': 11,
              'name': 'Depot Bekasi',
              'area': sampleCircleWkt,
              'attributes': {'color': '#E53935'},
            },
          ];

          final result = await dataSource.getGeofences();

          expect(mockDioClient.lastPath, equals(ApiEndpoints.geofences));
          expect(result.length, equals(2));
          expect(result[0].id, equals(10));
          expect(result[0].name, equals('Gudang Cakung'));
          expect(result[0].isPolygon, isTrue);
          expect(result[1].id, equals(11));
          expect(result[1].name, equals('Depot Bekasi'));
          expect(result[1].isCircle, isTrue);
        },
      );

      test(
        'TC-GDS-02: Forwards query parameters correctly (all, userId, deviceId, groupId)',
        () async {
          mockDioClient.mockResponseData = [];

          await dataSource.getGeofences(
            all: true,
            userId: 5,
            deviceId: 42,
            groupId: 3,
          );

          expect(mockDioClient.lastQueryParams?['all'], isTrue);
          expect(mockDioClient.lastQueryParams?['userId'], equals(5));
          expect(mockDioClient.lastQueryParams?['deviceId'], equals(42));
          expect(mockDioClient.lastQueryParams?['groupId'], equals(3));
        },
      );

      test('TC-GDS-03: Returns empty list on null response data', () async {
        mockDioClient.mockResponseData = null;

        final result = await dataSource.getGeofences();
        expect(result, isEmpty);
      });

      test(
        'TC-GDS-04: Throws ServerException when response data is not a List',
        () async {
          mockDioClient.mockResponseData = {'error': 'Not an array'};

          expect(
            () => dataSource.getGeofences(),
            throwsA(isA<ServerException>()),
          );
        },
      );
    });

    group('createGeofence (POST /api/geofences)', () {
      test(
        'TC-GDS-05: Sends POST with payload and returns created GeofenceModel on HTTP 200',
        () async {
          const input = GeofenceModel(
            id: 0,
            name: 'Zona Baru',
            area: sampleCircleWkt,
            attributes: {'color': '#4CAF50'},
          );

          mockDioClient.mockResponseData = {
            'id': 55,
            'name': 'Zona Baru',
            'area': sampleCircleWkt,
            'attributes': {'color': '#4CAF50'},
          };
          mockDioClient.mockStatusCode = 200;

          final result = await dataSource.createGeofence(input);

          expect(mockDioClient.lastPath, equals(ApiEndpoints.geofences));
          expect(mockDioClient.lastData['name'], equals('Zona Baru'));
          expect(mockDioClient.lastData['area'], equals(sampleCircleWkt));
          expect(result.id, equals(55));
          expect(result.name, equals('Zona Baru'));
        },
      );

      test(
        'TC-GDS-06: Throws ServerException if POST response is not a Map',
        () async {
          const input = GeofenceModel(
            id: 0,
            name: 'Zona',
            area: sampleCircleWkt,
          );
          mockDioClient.mockResponseData = 'invalid string response';

          expect(
            () => dataSource.createGeofence(input),
            throwsA(isA<ServerException>()),
          );
        },
      );
    });

    group('updateGeofence (PUT /api/geofences/{id})', () {
      test(
        'TC-GDS-07: Sends PUT to /api/geofences/{id} and returns updated model',
        () async {
          const input = GeofenceModel(
            id: 55,
            name: 'Zona Terupdate',
            area: sampleCircleWkt,
            attributes: {'color': '#FF9800'},
          );

          mockDioClient.mockResponseData = {
            'id': 55,
            'name': 'Zona Terupdate',
            'area': sampleCircleWkt,
            'attributes': {'color': '#FF9800'},
          };

          final result = await dataSource.updateGeofence(input);

          expect(
            mockDioClient.lastPath,
            equals('${ApiEndpoints.geofences}/55'),
          );
          expect(mockDioClient.lastData['name'], equals('Zona Terupdate'));
          expect(result.id, equals(55));
          expect(result.name, equals('Zona Terupdate'));
          expect(result.color, equals('#FF9800'));
        },
      );
    });

    group('deleteGeofence (DELETE /api/geofences/{id})', () {
      test(
        'TC-GDS-08: Sends DELETE to /api/geofences/{id} and succeeds on HTTP 204',
        () async {
          mockDioClient.mockStatusCode = 204;
          mockDioClient.mockResponseData = null;

          await dataSource.deleteGeofence(55);

          expect(
            mockDioClient.lastPath,
            equals('${ApiEndpoints.geofences}/55'),
          );
        },
      );
    });

    group('Error Handling across Geofence Endpoints', () {
      final reqOptions = RequestOptions(path: ApiEndpoints.geofences);

      test('TC-GDS-09: HTTP 401 throws AuthException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          response: Response(requestOptions: reqOptions, statusCode: 401),
        );

        expect(
          () => dataSource.getGeofences(),
          throwsA(
            isA<AuthException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('TC-GDS-10: HTTP 403 throws ForbiddenException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          response: Response(requestOptions: reqOptions, statusCode: 403),
        );

        expect(
          () => dataSource.deleteGeofence(99),
          throwsA(
            isA<ForbiddenException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      });

      test(
        'TC-GDS-11: HTTP 400 throws ServerException with bad request details',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: reqOptions,
            response: Response(
              requestOptions: reqOptions,
              statusCode: 400,
              data: 'Geofence area coordinates are invalid',
            ),
          );

          expect(
            () => dataSource.createGeofence(
              const GeofenceModel(id: 0, name: 'Bad', area: 'BAD'),
            ),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 400)
                  .having(
                    (e) => e.message,
                    'message',
                    contains('Geofence area coordinates'),
                  ),
            ),
          );
        },
      );

      test(
        'TC-GDS-12: Connection timeout throws ConnectionTimeoutException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: reqOptions,
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timed out',
          );

          expect(
            () => dataSource.getGeofences(),
            throwsA(isA<ConnectionTimeoutException>()),
          );
        },
      );

      test('TC-GDS-13: Connection error throws NetworkException', () async {
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          type: DioExceptionType.connectionError,
          message: 'Failed host lookup',
        );

        expect(
          () => dataSource.getGeofences(),
          throwsA(isA<NetworkException>()),
        );
      });

      test(
        'TC-GDS-14: HTTP 500 internal server error throws ServerException',
        () async {
          mockDioClient.exceptionToThrow = DioException(
            requestOptions: reqOptions,
            response: Response(
              requestOptions: reqOptions,
              statusCode: 500,
              data: 'Database lock timeout',
            ),
          );

          expect(
            () => dataSource.getGeofences(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.statusCode,
                'statusCode',
                500,
              ),
            ),
          );
        },
      );
    });

    group('Permissions Management (Link / Unlink Devices)', () {
      test(
        'TC-GDS-15: linkDeviceGeofence sends POST /api/permissions with deviceId and geofenceId',
        () async {
          mockDioClient.mockStatusCode = 204;
          mockDioClient.mockResponseData = null;

          await dataSource.linkDeviceGeofence(deviceId: 12, geofenceId: 5);

          expect(mockDioClient.lastPath, equals(ApiEndpoints.permissions));
          expect(
            mockDioClient.lastData,
            equals({'deviceId': 12, 'geofenceId': 5}),
          );
        },
      );

      test(
        'TC-GDS-16: unlinkDeviceGeofence sends DELETE /api/permissions with deviceId and geofenceId',
        () async {
          mockDioClient.mockStatusCode = 204;
          mockDioClient.mockResponseData = null;

          await dataSource.unlinkDeviceGeofence(deviceId: 12, geofenceId: 5);

          expect(mockDioClient.lastPath, equals(ApiEndpoints.permissions));
          expect(
            mockDioClient.lastData,
            equals({'deviceId': 12, 'geofenceId': 5}),
          );
        },
      );
    });
  });
}
