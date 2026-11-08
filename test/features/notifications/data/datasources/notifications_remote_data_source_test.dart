import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';

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
  late MockDioClient mockDio;
  late NotificationsRemoteDataSource dataSource;

  setUp(() {
    mockDio = MockDioClient();
    dataSource = NotificationsRemoteDataSourceImpl(dioClient: mockDio);
  });

  group('NotificationsRemoteDataSource Unit Tests', () {
    test(
      'TC-NRD-01: getNotifications passes query params and parses list',
      () async {
        mockDio.mockResponseData = [
          {
            'id': 1,
            'type': 'deviceOnline',
            'notificators': 'web,firebase',
            'always': true,
          },
          {'id': 2, 'type': 'alarm', 'notificators': 'mail', 'always': false},
        ];

        final result = await dataSource.getNotifications(
          all: true,
          userId: 10,
          deviceId: 25,
          groupId: 3,
          refresh: true,
        );

        expect(mockDio.lastPath, ApiEndpoints.notifications);
        expect(mockDio.lastQueryParams, {
          'all': true,
          'userId': 10,
          'deviceId': 25,
          'groupId': 3,
          'refresh': true,
        });
        expect(result.length, 2);
        expect(result.first.id, 1);
        expect(result.first.hasFirebase, isTrue);
        expect(result.last.id, 2);
      },
    );

    test(
      'TC-NRD-02: createNotification posts body and parses returned model',
      () async {
        final input = const NotificationModel(
          id: 0,
          type: 'deviceMoving',
          notificators: 'web',
        );

        mockDio.mockResponseData = {
          'id': 99,
          'type': 'deviceMoving',
          'notificators': 'web',
        };

        final result = await dataSource.createNotification(input);

        expect(mockDio.lastPath, ApiEndpoints.notifications);
        expect(mockDio.lastData['type'], 'deviceMoving');
        expect(result.id, 99);
        expect(result.type, 'deviceMoving');
      },
    );

    test('TC-NRD-03: updateNotification sends PUT with ID in path', () async {
      final input = const NotificationModel(
        id: 77,
        type: 'alarm',
        notificators: 'web,mail',
      );

      mockDio.mockResponseData = {
        'id': 77,
        'type': 'alarm',
        'notificators': 'web,mail',
      };

      final result = await dataSource.updateNotification(input);

      expect(mockDio.lastPath, '${ApiEndpoints.notifications}/77');
      expect(result.id, 77);
      expect(result.notificators, 'web,mail');
    });

    test(
      'TC-NRD-04: deleteNotification issues DELETE with correct path',
      () async {
        mockDio.mockResponseData = null;
        mockDio.mockStatusCode = 204;

        await dataSource.deleteNotification(44);

        expect(mockDio.lastPath, '${ApiEndpoints.notifications}/44');
      },
    );

    test('TC-NRD-05: getNotificationTypes fetches event types', () async {
      mockDio.mockResponseData = [
        {'type': 'deviceOnline'},
        {'type': 'alarm'},
        {'type': 'geofenceEnter'},
      ];

      final result = await dataSource.getNotificationTypes();

      expect(mockDio.lastPath, ApiEndpoints.notificationsTypes);
      expect(result.length, 3);
      expect(result.map((t) => t.type), [
        'deviceOnline',
        'alarm',
        'geofenceEnter',
      ]);
    });

    test(
      'TC-NRD-06: getNotificators fetches channel options with announcement',
      () async {
        mockDio.mockResponseData = [
          {'type': 'web'},
          {'type': 'mail'},
          {'type': 'sms'},
          {'type': 'firebase'},
        ];

        final result = await dataSource.getNotificators(announcement: false);

        expect(mockDio.lastPath, ApiEndpoints.notificationsNotificators);
        expect(mockDio.lastQueryParams, {'announcement': false});
        expect(result.length, 4);
        expect(result.any((n) => n.type == 'firebase'), isTrue);
      },
    );

    test(
      'TC-NRD-07: testNotificationChannel sends POST to specific channel',
      () async {
        mockDio.mockResponseData = null;
        mockDio.mockStatusCode = 204;

        await dataSource.testNotificationChannel('firebase');

        expect(mockDio.lastPath, '/api/notifications/test/firebase');
      },
    );

    test(
      'TC-NRD-08: testAllNotificationChannels sends POST to test root',
      () async {
        mockDio.mockResponseData = null;
        mockDio.mockStatusCode = 204;

        await dataSource.testAllNotificationChannels();

        expect(mockDio.lastPath, ApiEndpoints.notificationTestAll);
      },
    );

    test('TC-NRD-09: updateUser performs PUT /api/users/{id}', () async {
      final user = const UserModel(
        id: 12,
        name: 'Fleet Manager',
        email: 'manager@gpsku.id',
        attributes: {'notificationTokens': 'tokenA,tokenB'},
      );

      mockDio.mockResponseData = {
        'id': 12,
        'name': 'Fleet Manager',
        'email': 'manager@gpsku.id',
        'attributes': {'notificationTokens': 'tokenA,tokenB'},
      };

      final result = await dataSource.updateUser(user);

      expect(mockDio.lastPath, '/api/users/12');
      expect(
        mockDio.lastData['attributes']['notificationTokens'],
        'tokenA,tokenB',
      );
      expect(result.id, 12);
      expect(result.attributes['notificationTokens'], 'tokenA,tokenB');
    });

    test('TC-NRD-10: handles 401 Unauthorized with AuthException', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.notifications),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.notifications),
          statusCode: 401,
        ),
      );

      expect(
        () => dataSource.getNotifications(),
        throwsA(isA<AuthException>()),
      );
    });

    test('TC-NRD-11: handles 403 Forbidden with ForbiddenException', () async {
      mockDio.exceptionToThrow = DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.notifications),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.notifications),
          statusCode: 403,
        ),
      );

      expect(
        () => dataSource.createNotification(
          const NotificationModel(id: 0, type: 'alarm'),
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test(
      'TC-NRD-12: handles timeout with ConnectionTimeoutException',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.notifications),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );

        expect(
          () => dataSource.getNotifications(),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-NRD-13: handles network connection error with NetworkException',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.notifications),
          type: DioExceptionType.connectionError,
          message: 'No internet connection',
        );

        expect(
          () => dataSource.getNotifications(),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });
}
