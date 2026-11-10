import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/features/emulator/data/datasources/telemetry_emulator_remote_data_source.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';

class MockDio extends DioMixin implements Dio {
  int mockStatusCode = 200;
  dynamic mockResponseData;
  DioException? exceptionToThrow;

  Uri? lastUri;
  dynamic lastData;
  Options? lastOptions;
  CancelToken? lastCancelToken;

  @override
  Future<Response<T>> postUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastUri = uri;
    lastData = data;
    lastOptions = options;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return Response<T>(
      requestOptions: RequestOptions(path: uri.toString()),
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }

  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastUri = uri;
    lastData = data;
    lastOptions = options;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return Response<T>(
      requestOptions: RequestOptions(path: uri.toString()),
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }
}

void main() {
  group('TelemetryEmulatorRemoteDataSource Unit Tests', () {
    late MockDio mockDio;
    late TelemetryEmulatorRemoteDataSourceImpl dataSource;

    final tPacket = TelemetryPacketModel(
      id: 'TRONTON-77',
      lat: -6.2088,
      lon: 106.8456,
      timestamp: DateTime.utc(2026, 11, 10, 9, 0, 0),
      speed: 20.0,
      bearing: 180.0,
      altitude: 50.0,
      battery: 90.0,
    );

    setUp(() {
      mockDio = MockDio();
      dataSource = TelemetryEmulatorRemoteDataSourceImpl(
        appConfig: const AppConfig(baseUrl: 'http://10.0.2.2:8082'),
        dio: mockDio,
        timeout: const Duration(seconds: 3),
        defaultPort: 5055,
      );
    });

    test(
      'TC-EDS-01: sendTelemetryPacket sends HTTP POST with OsmAnd parameters and returns true on 200 OK',
      () async {
        mockDio.mockStatusCode = 200;

        final result = await dataSource.sendTelemetryPacket(tPacket);

        expect(result, isTrue);
        expect(mockDio.lastUri, isNotNull);
        expect(mockDio.lastUri!.scheme, 'http');
        expect(mockDio.lastUri!.host, '10.0.2.2');
        expect(mockDio.lastUri!.port, 5055);
        expect(mockDio.lastUri!.path, '/');
        expect(mockDio.lastUri!.queryParameters['id'], 'TRONTON-77');
        expect(mockDio.lastUri!.queryParameters['lat'], '-6.2088');
        expect(mockDio.lastUri!.queryParameters['lon'], '106.8456');
        expect(mockDio.lastUri!.queryParameters['batt'], '90.0');
      },
    );

    test(
      'TC-EDS-02: sendTelemetryPacket with usePost false sends HTTP GET request',
      () async {
        mockDio.mockStatusCode = 200;

        final result = await dataSource.sendTelemetryPacket(
          tPacket,
          usePost: false,
        );

        expect(result, isTrue);
        expect(mockDio.lastUri!.port, 5055);
        expect(mockDio.lastUri!.queryParameters['id'], 'TRONTON-77');
      },
    );

    test(
      'TC-EDS-03: sendTelemetryPacket respects customHost and customPort overrides',
      () async {
        mockDio.mockStatusCode = 200;

        final result = await dataSource.sendTelemetryPacket(
          tPacket,
          customHost: '192.168.1.150',
          customPort: 5056,
        );

        expect(result, isTrue);
        expect(mockDio.lastUri!.host, '192.168.1.150');
        expect(mockDio.lastUri!.port, 5056);
      },
    );

    test(
      'TC-EDS-04: sendTelemetryPacket throws ServerException on HTTP 400 (unregistered device)',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
          response: Response(
            requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
            statusCode: 400,
            data: 'Bad Request',
          ),
        );

        expect(
          () => dataSource.sendTelemetryPacket(tPacket),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              400,
            ),
          ),
        );
      },
    );

    test(
      'TC-EDS-05: sendTelemetryPacket throws ConnectionTimeoutException on timeout',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );

        expect(
          () => dataSource.sendTelemetryPacket(tPacket),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );

    test(
      'TC-EDS-06: sendTelemetryPacket throws NetworkException on connection error (port closed/refused)',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused on port 5055',
        );

        expect(
          () => dataSource.sendTelemetryPacket(tPacket),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'TC-EDS-07: probeOsmandPort returns true when port responds with HTTP 200 OK',
      () async {
        mockDio.mockStatusCode = 200;

        final reachable = await dataSource.probeOsmandPort();

        expect(reachable, isTrue);
        expect(mockDio.lastUri!.port, 5055);
        expect(mockDio.lastUri!.queryParameters['id'], 'probe_ping');
      },
    );

    test(
      'TC-EDS-08: probeOsmandPort returns true when port responds with HTTP 400 Bad Request',
      () async {
        // HTTP 400 from OsmAnd confirms Netty listener decoded the probe packet
        mockDio.mockStatusCode = 400;

        final reachable = await dataSource.probeOsmandPort();

        expect(reachable, isTrue);
      },
    );

    test(
      'TC-EDS-09: probeOsmandPort throws NetworkException on connection refused',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );

        expect(
          () => dataSource.probeOsmandPort(),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'TC-EDS-10: probeOsmandPort throws ConnectionTimeoutException on timeout',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:5055/'),
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout',
        );

        expect(
          () => dataSource.probeOsmandPort(),
          throwsA(isA<ConnectionTimeoutException>()),
        );
      },
    );
  });
}
