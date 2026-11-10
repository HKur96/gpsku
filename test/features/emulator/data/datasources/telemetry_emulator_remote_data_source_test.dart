import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/features/emulator/data/datasources/telemetry_emulator_remote_data_source.dart';
import 'package:gpsku/features/emulator/data/models/osmand_transport_diagnostics.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';

class RecordedCall {
  final String method;
  final Uri uri;
  final dynamic data;
  final Options? options;

  RecordedCall({
    required this.method,
    required this.uri,
    this.data,
    this.options,
  });
}

class MockDio extends DioMixin implements Dio {
  int mockStatusCode = 200;
  dynamic mockResponseData;
  DioException? exceptionToThrow;

  Uri? lastUri;
  dynamic lastData;
  Options? lastOptions;
  CancelToken? lastCancelToken;

  final List<RecordedCall> recordedCalls = [];
  Response<dynamic>? Function(
    String method,
    Uri uri,
    dynamic data,
    Options? options,
  )?
  onRequest;

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
    recordedCalls.add(
      RecordedCall(method: 'POST', uri: uri, data: data, options: options),
    );

    if (onRequest != null) {
      final res = onRequest!('POST', uri, data, options);
      if (res != null) {
        return Response<T>(
          requestOptions: res.requestOptions,
          data: res.data as T?,
          statusCode: res.statusCode,
        );
      }
    }

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
    recordedCalls.add(
      RecordedCall(method: 'GET', uri: uri, data: data, options: options),
    );

    if (onRequest != null) {
      final res = onRequest!('GET', uri, data, options);
      if (res != null) {
        return Response<T>(
          requestOptions: res.requestOptions,
          data: res.data as T?,
          statusCode: res.statusCode,
        );
      }
    }

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
        expect(
          dataSource.lastTransportDiagnostics?.mode,
          OsmandTransportMode.directHttpPort,
        );
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
        expect(dataSource.lastTransportDiagnostics?.httpMethod, 'GET');
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
        expect(
          dataSource.lastTransportDiagnostics?.mode,
          OsmandTransportMode.directHttpPort,
        );
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

    test(
      'TC-EDS-11: HTTPS config sends POST / with form-urlencoded body without cleartext :5055 downgrade',
      () async {
        final httpsSource = TelemetryEmulatorRemoteDataSourceImpl(
          appConfig: const AppConfig(baseUrl: 'https://gps.domainanda.com'),
          dio: mockDio,
          timeout: const Duration(seconds: 3),
        );

        final ok = await httpsSource.sendTelemetryPacket(tPacket);

        expect(ok, isTrue);
        expect(mockDio.recordedCalls.length, 1);
        final call = mockDio.recordedCalls.single;
        expect(call.method, 'POST');
        expect(call.uri.scheme, 'https');
        expect(call.uri.host, 'gps.domainanda.com');
        expect(call.uri.path, '/');
        expect(call.uri.queryParameters, isEmpty);
        expect(
          call.options?.headers?['Content-Type'],
          'application/x-www-form-urlencoded',
        );
        final form = Uri.splitQueryString(call.data as String);
        expect(form['id'], 'TRONTON-77');
        expect(form['lat'], '-6.2088');
        expect(form['lon'], '106.8456');
        expect(
          httpsSource.lastTransportDiagnostics?.mode,
          OsmandTransportMode.httpsWebProxy,
        );
        expect(
          httpsSource.lastTransportDiagnostics?.endpointUri.toString(),
          'https://gps.domainanda.com/',
        );
      },
    );

    test(
      'TC-EDS-12: HTTPS probeOsmandPort uses POST / (id=probe_ping) and rejects HTML SPA fake 200 or 405',
      () async {
        final httpsSource = TelemetryEmulatorRemoteDataSourceImpl(
          appConfig: const AppConfig(baseUrl: 'https://gps.domainanda.com'),
          dio: mockDio,
        );

        mockDio.mockStatusCode = 400;
        expect(await httpsSource.probeOsmandPort(), isTrue);
        expect(mockDio.recordedCalls.single.method, 'POST');
        expect(mockDio.recordedCalls.single.data, 'id=probe_ping');
        expect(
          httpsSource.lastTransportDiagnostics?.mode,
          OsmandTransportMode.httpsWebProxy,
        );

        // Static SPA returning HTML on POST / -> must NOT report reachable
        mockDio.mockStatusCode = 200;
        mockDio.mockResponseData =
            '<!DOCTYPE html><html><body>SPA</body></html>';
        expect(await httpsSource.probeOsmandPort(), isFalse);

        // Method not allowed 405 -> must NOT report reachable
        mockDio.mockResponseData = null;
        mockDio.mockStatusCode = 405;
        expect(await httpsSource.probeOsmandPort(), isFalse);
      },
    );

    test(
      'TC-EDS-13: HTTPS config refuses cleartext HTTP :5055 fallback on connectionError',
      () async {
        final httpsSource = TelemetryEmulatorRemoteDataSourceImpl(
          appConfig: const AppConfig(baseUrl: 'https://gps.domainanda.com'),
          dio: mockDio,
        );
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'https://gps.domainanda.com/'),
          type: DioExceptionType.connectionError,
          message: 'TLS connection refused',
        );

        await expectLater(
          () => httpsSource.sendTelemetryPacket(tPacket),
          throwsA(isA<NetworkException>()),
        );
        expect(mockDio.recordedCalls.length, 1);
        expect(mockDio.recordedCalls.single.uri.scheme, 'https');
      },
    );

    test(
      'TC-EDS-14: HTTP :5055 failure transparently falls back to POST :8082/ preserving original error and proxy diagnostics',
      () async {
        mockDio.onRequest = (method, uri, data, options) {
          if (uri.port == 5055) {
            throw DioException(
              requestOptions: RequestOptions(path: uri.toString()),
              type: DioExceptionType.connectionError,
              message: 'SocketException: Connection refused on port 5055',
            );
          }
          if (uri.port == 8082 && method == 'POST') {
            return Response<dynamic>(
              requestOptions: RequestOptions(path: uri.toString()),
              statusCode: 200,
              data: '',
            );
          }
          throw StateError('Unexpected call: $method $uri');
        };

        final ok = await dataSource.sendTelemetryPacket(tPacket);

        expect(ok, isTrue);
        expect(mockDio.recordedCalls.length, 2);
        expect(mockDio.recordedCalls[0].uri.port, 5055);
        expect(mockDio.recordedCalls[1].method, 'POST');
        expect(
          mockDio.recordedCalls[1].uri.toString(),
          'http://10.0.2.2:8082/',
        );
        expect(
          Uri.splitQueryString(mockDio.recordedCalls[1].data as String)['id'],
          'TRONTON-77',
        );

        final diag = dataSource.lastTransportDiagnostics;
        expect(diag, isNotNull);
        expect(diag!.mode, OsmandTransportMode.httpWebProxyFallback);
        expect(diag.isFallbackProxy, isTrue);
        expect(diag.isDirectMode, isFalse);
        expect(diag.endpointUri.toString(), 'http://10.0.2.2:8082/');
        expect(diag.httpMethod, 'POST');
        expect(
          diag.initialDirectFailureReason,
          contains('Connection refused on port 5055'),
        );
      },
    );

    test(
      'TC-EDS-15: HTTP probe falls back to POST :8082/ when :5055 refuses and flags fallback diagnostics',
      () async {
        mockDio.onRequest = (method, uri, data, options) {
          if (uri.port == 5055) {
            throw DioException(
              requestOptions: RequestOptions(path: uri.toString()),
              type: DioExceptionType.connectionError,
              message: 'Port 5055 not published in Docker Compose',
            );
          }
          if (uri.port == 8082 && method == 'POST' && data == 'id=probe_ping') {
            return Response<dynamic>(
              requestOptions: RequestOptions(path: uri.toString()),
              statusCode: 400,
              data: '',
            );
          }
          throw StateError('Unexpected probe call: $method $uri');
        };

        final reachable = await dataSource.probeOsmandPort();

        expect(reachable, isTrue);
        expect(mockDio.recordedCalls.length, 2);
        expect(mockDio.recordedCalls[0].method, 'GET');
        expect(mockDio.recordedCalls[0].uri.port, 5055);
        expect(mockDio.recordedCalls[1].method, 'POST');
        expect(mockDio.recordedCalls[1].uri.port, 8082);

        final diag = dataSource.lastTransportDiagnostics!;
        expect(diag.mode, OsmandTransportMode.httpWebProxyFallback);
        expect(diag.endpointUri.port, 8082);
        expect(
          diag.initialDirectFailureReason,
          contains('Port 5055 not published in Docker Compose'),
        );
      },
    );

    test(
      'TC-EDS-16: Custom host/port override bypasses HTTP proxy fallback on connectionError',
      () async {
        mockDio.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: 'http://192.168.1.50:5056/'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );

        await expectLater(
          () => dataSource.sendTelemetryPacket(
            tPacket,
            customHost: '192.168.1.50',
            customPort: 5056,
          ),
          throwsA(isA<NetworkException>()),
        );
        expect(mockDio.recordedCalls.length, 1);
        expect(mockDio.recordedCalls.single.uri.port, 5056);
      },
    );
  });
}
