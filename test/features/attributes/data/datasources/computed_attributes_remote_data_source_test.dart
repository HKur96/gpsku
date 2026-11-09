import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/attributes/data/datasources/computed_attributes_remote_data_source.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';

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
  late MockDioClient mockDio;
  late ComputedAttributesRemoteDataSourceImpl dataSource;

  final tModel = const ComputedAttributeModel(
    id: 5,
    description: 'Level BBM',
    attribute: 'fuelLevel',
    expression: 'adc1 * 0.05',
    type: 'number',
    priority: 0,
  );

  setUp(() {
    mockDio = MockDioClient();
    dataSource = ComputedAttributesRemoteDataSourceImpl(dioClient: mockDio);
  });

  group('ComputedAttributesRemoteDataSource Tests', () {
    test(
      'TC-CARD-01: getComputedAttributes without query parameters returns list of models',
      () async {
        mockDio.mockResponseData = [
          {
            'id': 1,
            'description': 'Speed Warning',
            'attribute': 'speedAlert',
            'expression': 'speed > 100',
            'type': 'boolean',
          },
        ];

        final result = await dataSource.getComputedAttributes();

        expect(mockDio.lastPath, equals(ApiEndpoints.attributesComputed));
        expect(mockDio.lastQueryParams, isNull);
        expect(result.length, equals(1));
        expect(result.first.id, equals(1));
        expect(result.first.attribute, equals('speedAlert'));
      },
    );

    test(
      'TC-CARD-02: getComputedAttributes passes all, userId, deviceId, groupId parameters',
      () async {
        mockDio.mockResponseData = <Map<String, dynamic>>[];

        await dataSource.getComputedAttributes(
          all: true,
          userId: 2,
          deviceId: 10,
          groupId: 3,
        );

        expect(mockDio.lastQueryParams?['all'], isTrue);
        expect(mockDio.lastQueryParams?['userId'], equals(2));
        expect(mockDio.lastQueryParams?['deviceId'], equals(10));
        expect(mockDio.lastQueryParams?['groupId'], equals(3));
      },
    );

    test(
      'TC-CARD-03: getComputedAttributes returns empty list on non-list response',
      () async {
        mockDio.mockResponseData = {'error': 'not a list'};

        final result = await dataSource.getComputedAttributes();
        expect(result, isEmpty);
      },
    );

    test(
      'TC-CARD-04: createComputedAttribute posts JSON body and returns created model',
      () async {
        mockDio.mockResponseData = {
          'id': 15,
          'description': 'New Sensor',
          'attribute': 'temp',
          'expression': 'adc2 * 0.1',
          'type': 'number',
        };

        final result = await dataSource.createComputedAttribute(tModel);

        expect(mockDio.lastPath, equals(ApiEndpoints.attributesComputed));
        expect(result.id, equals(15));
        expect(result.description, equals('New Sensor'));
      },
    );

    test(
      'TC-CARD-05: updateComputedAttribute puts JSON body and returns updated model',
      () async {
        mockDio.mockResponseData = {
          'id': 5,
          'description': 'Level BBM Updated',
          'attribute': 'fuelLevel',
          'expression': 'adc1 * 0.05',
          'type': 'number',
        };

        final result = await dataSource.updateComputedAttribute(tModel);

        expect(
          mockDio.lastPath,
          equals(ApiEndpoints.attributesComputedById(5)),
        );
        expect(result.description, equals('Level BBM Updated'));
      },
    );

    test(
      'TC-CARD-06: deleteComputedAttribute sends DELETE to /api/attributes/computed/{id}',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.deleteComputedAttribute(5);

        expect(
          mockDio.lastPath,
          equals(ApiEndpoints.attributesComputedById(5)),
        );
      },
    );

    test(
      'TC-CARD-07: testComputedAttribute sends POST with deviceId query param and returns result',
      () async {
        mockDio.mockResponseData = 42.5;

        final result = await dataSource.testComputedAttribute(
          deviceId: 77,
          attribute: tModel,
        );

        expect(mockDio.lastPath, equals(ApiEndpoints.attributesComputedTest));
        expect(mockDio.lastQueryParams?['deviceId'], equals(77));
        expect(result.success, isTrue);
        expect(result.rawValue, equals(42.5));
        expect(result.stringValue, equals('42.5'));
      },
    );

    test(
      'TC-CARD-08: testComputedAttribute handles 204 No Content / null data returning empty test result',
      () async {
        mockDio.mockStatusCode = 204;
        mockDio.mockResponseData = null;

        final result = await dataSource.testComputedAttribute(
          deviceId: 77,
          attribute: tModel,
        );

        expect(result.success, isTrue);
        expect(result.hasValue, isFalse);
        expect(result.stringValue, equals(''));
      },
    );

    test(
      'TC-CARD-09: linkDeviceAttribute sends POST to /api/permissions with deviceId and attributeId',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.linkDeviceAttribute(deviceId: 77, attributeId: 5);

        expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDio.lastData, equals({'deviceId': 77, 'attributeId': 5}));
      },
    );

    test(
      'TC-CARD-10: unlinkDeviceAttribute sends DELETE to /api/permissions with deviceId and attributeId',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.unlinkDeviceAttribute(deviceId: 77, attributeId: 5);

        expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDio.lastData, equals({'deviceId': 77, 'attributeId': 5}));
      },
    );

    test(
      'TC-CARD-11: linkGroupAttribute sends POST to /api/permissions with groupId and attributeId',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.linkGroupAttribute(groupId: 3, attributeId: 5);

        expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDio.lastData, equals({'groupId': 3, 'attributeId': 5}));
      },
    );

    test(
      'TC-CARD-12: unlinkGroupAttribute sends DELETE to /api/permissions with groupId and attributeId',
      () async {
        mockDio.mockResponseData = null;

        await dataSource.unlinkGroupAttribute(groupId: 3, attributeId: 5);

        expect(mockDio.lastPath, equals(ApiEndpoints.permissions));
        expect(mockDio.lastData, equals({'groupId': 3, 'attributeId': 5}));
      },
    );

    test('TC-CARD-13: Throws AuthException on HTTP 401', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
          statusCode: 401,
        ),
      );

      expect(
        () => dataSource.getComputedAttributes(),
        throwsA(isA<AuthException>()),
      );
    });

    test('TC-CARD-14: Throws ForbiddenException on HTTP 403', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
          statusCode: 403,
        ),
      );

      expect(
        () => dataSource.createComputedAttribute(tModel),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('TC-CARD-15: Throws ConflictException on HTTP 409', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.permissions),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.permissions),
          statusCode: 409,
        ),
      );

      expect(
        () => dataSource.linkDeviceAttribute(deviceId: 77, attributeId: 5),
        throwsA(isA<ConflictException>()),
      );
    });

    test('TC-CARD-16: Throws ServerException on HTTP 400', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(
          path: ApiEndpoints.attributesComputedTest,
        ),
        response: Response(
          requestOptions: RequestOptions(
            path: ApiEndpoints.attributesComputedTest,
          ),
          statusCode: 400,
          data: 'Invalid JEXL expression',
        ),
      );

      expect(
        () => dataSource.testComputedAttribute(deviceId: 77, attribute: tModel),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'TC-CARD-17: Throws ConnectionTimeoutException on connection timeouts',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout connecting',
        );

        expect(
          () => dataSource.getComputedAttributes(),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-CARD-18: Throws NetworkException on connection error or cancel',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
          type: DioExceptionType.connectionError,
          message: 'Socket error',
        );

        expect(
          () => dataSource.getComputedAttributes(),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('TC-CARD-19: Throws ServerException on general server 500', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.attributesComputed),
          statusCode: 500,
          data: 'Internal error',
        ),
      );

      expect(
        () => dataSource.deleteComputedAttribute(5),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
