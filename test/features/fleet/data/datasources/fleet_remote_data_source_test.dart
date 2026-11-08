import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/constants/api_endpoints.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/fleet_remote_data_source.dart';

class MockDioClient extends DioClient {
  dynamic mockResponseData;
  int mockStatusCode = 200;
  DioException? exceptionToThrow;
  String? lastRequestedPath;
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
    lastRequestedPath = path;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    final reqOptions = RequestOptions(path: path);
    return Response<T>(
      requestOptions: reqOptions,
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }
}

void main() {
  group('FleetRemoteDataSource - REST API Contract & Parsing Tests', () {
    late MockDioClient mockDioClient;
    late FleetRemoteDataSourceImpl dataSource;

    setUp(() {
      mockDioClient = MockDioClient();
      dataSource = FleetRemoteDataSourceImpl(dioClient: mockDioClient);
    });

    test(
      'TC-RDS-01: Successful device response from /api/devices maps to List<DeviceModel>',
      () async {
        mockDioClient.mockResponseData = [
          {
            'id': 1,
            'name': 'Truck Alpha',
            'uniqueId': 'TRK-001',
            'status': 'online',
            'category': 'truck',
            'disabled': false,
            'positionId': 101,
          },
          {
            'id': 2,
            'name': 'Motorcycle Beta',
            'uniqueId': 'MOT-002',
            'status': 'offline',
            'category': 'motorcycle',
            'disabled': false,
          },
        ];

        final devices = await dataSource.getDevices();

        expect(mockDioClient.lastRequestedPath, equals(ApiEndpoints.devices));
        expect(devices.length, equals(2));
        expect(devices[0].id, equals(1));
        expect(devices[0].name, equals('Truck Alpha'));
        expect(devices[0].isOnline, isTrue);
        expect(devices[0].category, equals('truck'));
        expect(devices[1].id, equals(2));
        expect(devices[1].isOnline, isFalse);
      },
    );

    test(
      'TC-RDS-02: Successful position response from /api/positions maps to List<PositionModel>',
      () async {
        mockDioClient.mockResponseData = [
          {
            'id': 101,
            'deviceId': 1,
            'serverTime': '2026-11-08T08:00:00.000Z',
            'fixTime': '2026-11-08T08:00:00.000Z',
            'latitude': -6.2088,
            'longitude': 106.8456,
            'speed': 25.0, // knots
            'course': 180.0,
            'altitude': 15.0,
            'valid': true,
          },
        ];

        final positions = await dataSource.getPositions();

        expect(mockDioClient.lastRequestedPath, equals(ApiEndpoints.positions));
        expect(positions.length, equals(1));
        expect(positions[0].id, equals(101));
        expect(positions[0].deviceId, equals(1));
        expect(positions[0].latitude, equals(-6.2088));
        expect(positions[0].longitude, equals(106.8456));
        expect(positions[0].speedKmh, closeTo(46.3, 0.1));
      },
    );

    test(
      'TC-RDS-03: Empty responses ([] or null) return empty list without throwing',
      () async {
        mockDioClient.mockResponseData = [];
        final devicesEmpty = await dataSource.getDevices();
        expect(devicesEmpty, isEmpty);

        mockDioClient.mockResponseData = null;
        final positionsNull = await dataSource.getPositions();
        expect(positionsNull, isEmpty);
      },
    );

    test(
      'TC-RDS-04: Malformed non-List JSON response throws ServerException',
      () async {
        mockDioClient.mockResponseData = {
          'error': 'Unexpected JSON object instead of array',
        };

        expect(() => dataSource.getDevices(), throwsA(isA<ServerException>()));

        expect(
          () => dataSource.getPositions(),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test(
      'TC-RDS-05: HTTP 401 response throws AuthException with statusCode 401',
      () async {
        final reqOptions = RequestOptions(path: ApiEndpoints.devices);
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          response: Response(requestOptions: reqOptions, statusCode: 401),
        );

        expect(
          () => dataSource.getDevices(),
          throwsA(predicate((e) => e is AuthException && e.statusCode == 401)),
        );
      },
    );

    test(
      'TC-RDS-06: HTTP 403 Forbidden response throws ServerException with statusCode 403',
      () async {
        final reqOptions = RequestOptions(path: ApiEndpoints.devices);
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          response: Response(requestOptions: reqOptions, statusCode: 403),
        );

        expect(
          () => dataSource.getDevices(),
          throwsA(
            predicate((e) => e is ServerException && e.statusCode == 403),
          ),
        );
      },
    );

    test(
      'TC-RDS-07: HTTP 500 Internal Server Error throws ServerException with statusCode 500',
      () async {
        final reqOptions = RequestOptions(path: ApiEndpoints.positions);
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          response: Response(
            requestOptions: reqOptions,
            statusCode: 500,
            data: 'Internal Database Error',
          ),
        );

        expect(
          () => dataSource.getPositions(),
          throwsA(
            predicate((e) => e is ServerException && e.statusCode == 500),
          ),
        );
      },
    );

    test(
      'TC-RDS-08: Network timeout (connectionTimeout, receiveTimeout) throws ConnectionTimeoutException',
      () async {
        final reqOptions = RequestOptions(path: ApiEndpoints.devices);
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out after 10000ms',
        );

        expect(
          () => dataSource.getDevices(),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-RDS-09: Request cancelled via CancelToken throws NetworkException',
      () async {
        final reqOptions = RequestOptions(path: ApiEndpoints.devices);
        mockDioClient.exceptionToThrow = DioException(
          requestOptions: reqOptions,
          type: DioExceptionType.cancel,
          message: 'Request was cancelled by user',
        );

        expect(() => dataSource.getDevices(), throwsA(isA<NetworkException>()));
      },
    );

    test(
      'TC-RDS-10: Correct endpoint paths and cancelToken forwarding verified',
      () async {
        mockDioClient.mockResponseData = [];
        final cancelToken = CancelToken();

        await dataSource.getDevices(cancelToken: cancelToken);
        expect(mockDioClient.lastRequestedPath, equals('/api/devices'));
        expect(mockDioClient.lastCancelToken, equals(cancelToken));

        await dataSource.getPositions(cancelToken: cancelToken);
        expect(mockDioClient.lastRequestedPath, equals('/api/positions'));
        expect(mockDioClient.lastCancelToken, equals(cancelToken));

        await dataSource.getGroups(cancelToken: cancelToken);
        expect(mockDioClient.lastRequestedPath, equals('/api/groups'));
        expect(mockDioClient.lastCancelToken, equals(cancelToken));
      },
    );

    test(
      'TC-RDS-11: Successful group response from /api/groups maps to List<GroupModel>',
      () async {
        mockDioClient.mockResponseData = [
          {
            'id': 1,
            'name': 'Regional West',
            'groupId': 0,
            'attributes': {'color': 'blue'},
          },
          {'id': 2, 'name': 'Patrol Unit', 'groupId': 1},
        ];

        final groups = await dataSource.getGroups();

        expect(mockDioClient.lastRequestedPath, equals(ApiEndpoints.groups));
        expect(groups.length, equals(2));
        expect(groups[0].id, equals(1));
        expect(groups[0].name, equals('Regional West'));
        expect(groups[0].groupId, isNull);
        expect(groups[0].isRoot, isTrue);
        expect(groups[1].id, equals(2));
        expect(groups[1].groupId, equals(1));
        expect(groups[1].isRoot, isFalse);
      },
    );

    test(
      'TC-RDS-12: Empty group responses ([] or null) return empty list without throwing',
      () async {
        mockDioClient.mockResponseData = [];
        final groupsEmpty = await dataSource.getGroups();
        expect(groupsEmpty, isEmpty);

        mockDioClient.mockResponseData = null;
        final groupsNull = await dataSource.getGroups();
        expect(groupsNull, isEmpty);
      },
    );

    test(
      'TC-RDS-13: Malformed non-List JSON response throws ServerException for groups',
      () async {
        mockDioClient.mockResponseData = {'error': 'not a list'};

        expect(() => dataSource.getGroups(), throwsA(isA<ServerException>()));
      },
    );
  });
}
