import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/osmand_transport_diagnostics.dart';
import '../models/telemetry_packet_model.dart';

/// Contract for transmitting simulated telemetry packets to Traccar's
/// OsmAnd protocol listener (direct port 5055 or WebServer `POST /` proxy).
abstract class TelemetryEmulatorRemoteDataSource {
  /// Transmits a mock telemetry packet to Traccar OsmAnd ingestion endpoint.
  ///
  /// Throws [ServerException], [NetworkException], [ConnectionTimeoutException].
  Future<bool> sendTelemetryPacket(
    TelemetryPacketModel packet, {
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  });

  /// Probes the OsmAnd endpoint reachability to verify the protocol listener is active.
  /// Returns `true` if endpoint responds with HTTP 200 (non-HTML) or HTTP 400.
  Future<bool> probeOsmandPort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [TelemetryEmulatorRemoteDataSource] with scheme-aware
/// resolution:
/// 1. HTTPS base URLs (without custom port/host overrides) use Traccar's built-in
///    WebServer `POST /` proxy over TLS (`application/x-www-form-urlencoded`).
/// 2. HTTP base URLs / explicit overrides attempt direct port 5055 first, and
///    transparently fall back to HTTP proxy `POST http://host:webPort/` if 5055 refuses
///    connection (recording diagnostics cleanly without masking direct failure).
class TelemetryEmulatorRemoteDataSourceImpl
    implements
        TelemetryEmulatorRemoteDataSource,
        OsmandTransportDiagnosticsProvider {
  final AppConfig appConfig;
  final Dio _dio;
  final Duration timeout;
  final int defaultPort;
  final bool allowWebProxyFallback;

  OsmandTransportDiagnostics? _lastTransportDiagnostics;

  @override
  OsmandTransportDiagnostics? get lastTransportDiagnostics =>
      _lastTransportDiagnostics;

  TelemetryEmulatorRemoteDataSourceImpl({
    required this.appConfig,
    Dio? dio,
    this.timeout = const Duration(seconds: 4),
    this.defaultPort = 5055,
    this.allowWebProxyFallback = true,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               receiveTimeout: timeout,
               sendTimeout: timeout,
               validateStatus: (status) =>
                   status != null && status >= 200 && status < 300,
             ),
           );

  String _resolveHost(String? customHost) {
    if (customHost != null && customHost.trim().isNotEmpty) {
      return customHost.trim();
    }
    try {
      final parsed = Uri.parse(appConfig.baseUrl);
      if (parsed.host.isNotEmpty) return parsed.host;
    } catch (_) {}
    return '10.0.2.2';
  }

  bool _hasExplicitOverride(String? customHost, int? customPort) {
    return (customHost != null && customHost.trim().isNotEmpty) ||
        customPort != null;
  }

  bool _shouldUseHttpsProxy(String? customHost, int? customPort) {
    return appConfig.isHttps && !_hasExplicitOverride(customHost, customPort);
  }

  bool _shouldAttemptHttpProxyFallback(
    String? customHost,
    int? customPort,
    DioException error,
  ) {
    if (!allowWebProxyFallback ||
        appConfig.isHttps ||
        _hasExplicitOverride(customHost, customPort)) {
      return false;
    }

    final directBase = _stripQuery(buildOsmandUri());
    final proxyBase = _stripQuery(appConfig.getOsmandProxyUri());
    if (directBase == proxyBase) {
      return false;
    }

    return error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown && error.response == null);
  }

  Uri _stripQuery(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.isEmpty ? '/' : uri.path,
    );
  }

  bool _looksLikeHtmlResponse(dynamic data) {
    if (data is! String) return false;
    final trimmed = data.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  /// Builds a direct [Uri] targeting the Netty OsmAnd listener (HTTP).
  Uri buildOsmandUri({
    String? host,
    int? port,
    Map<String, String>? queryParameters,
  }) {
    return Uri(
      scheme: 'http',
      host: _resolveHost(host),
      port: port ?? defaultPort,
      path: '/',
      queryParameters: queryParameters,
    );
  }

  @override
  Future<bool> sendTelemetryPacket(
    TelemetryPacketModel packet, {
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  }) async {
    if (_shouldUseHttpsProxy(customHost, customPort)) {
      return _sendViaProxy(
        packet,
        proxyUri: appConfig.getOsmandProxyUri(),
        mode: OsmandTransportMode.httpsWebProxy,
        cancelToken: cancelToken,
      );
    }

    final directUri = buildOsmandUri(
      host: customHost,
      port: customPort,
      queryParameters: packet.toOsmAndParams(),
    );

    try {
      final response = usePost
          ? await _dio.postUri<dynamic>(
              directUri,
              cancelToken: cancelToken,
              options: Options(
                sendTimeout: timeout,
                receiveTimeout: timeout,
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              ),
            )
          : await _dio.getUri<dynamic>(
              directUri,
              cancelToken: cancelToken,
              options: Options(sendTimeout: timeout, receiveTimeout: timeout),
            );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        _lastTransportDiagnostics = OsmandTransportDiagnostics(
          mode: OsmandTransportMode.directHttpPort,
          endpointUri: _stripQuery(directUri),
          httpMethod: usePost ? 'POST' : 'GET',
          statusCode: statusCode,
          timestamp: DateTime.now(),
        );
        return true;
      }

      if (statusCode == 400) {
        throw ServerException(
          'ID perangkat "${packet.id}" tidak dikenali atau belum terdaftar di Traccar (HTTP 400)',
          400,
        );
      }

      throw ServerException(
        'Server mengembalikan kode status $statusCode saat mengirim paket telemetri OsmAnd',
        statusCode,
      );
    } on DioException catch (e) {
      if (_shouldAttemptHttpProxyFallback(customHost, customPort, e)) {
        final directReason = _describeDioFailure(e);
        return _sendViaProxy(
          packet,
          proxyUri: appConfig.getOsmandProxyUri(),
          mode: OsmandTransportMode.httpWebProxyFallback,
          initialDirectFailureReason: directReason,
          cancelToken: cancelToken,
        );
      }
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: OsmandTransportMode.directHttpPort,
        endpointUri: _stripQuery(directUri),
        httpMethod: usePost ? 'POST' : 'GET',
        statusCode: e.response?.statusCode,
        timestamp: DateTime.now(),
      );
      _handleDioException(e, packet.id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<bool> _sendViaProxy(
    TelemetryPacketModel packet, {
    required Uri proxyUri,
    required OsmandTransportMode mode,
    String? initialDirectFailureReason,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.postUri<dynamic>(
        proxyUri,
        data: packet.toQueryString(),
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        if (_looksLikeHtmlResponse(response.data)) {
          _lastTransportDiagnostics = OsmandTransportDiagnostics(
            mode: mode,
            endpointUri: proxyUri,
            httpMethod: 'POST',
            statusCode: statusCode,
            initialDirectFailureReason: initialDirectFailureReason,
            timestamp: DateTime.now(),
          );
          throw ServerException(
            'Endpoint $proxyUri mengembalikan halaman HTML bukan listener OsmAnd WebServer proxy',
            statusCode,
          );
        }

        _lastTransportDiagnostics = OsmandTransportDiagnostics(
          mode: mode,
          endpointUri: proxyUri,
          httpMethod: 'POST',
          statusCode: statusCode,
          initialDirectFailureReason: initialDirectFailureReason,
          timestamp: DateTime.now(),
        );
        return true;
      }

      if (statusCode == 400) {
        throw ServerException(
          'ID perangkat "${packet.id}" tidak dikenali atau belum terdaftar di Traccar (HTTP 400)',
          400,
        );
      }

      throw ServerException(
        'Proxy $proxyUri mengembalikan kode status $statusCode saat mengirim paket OsmAnd',
        statusCode,
      );
    } on DioException catch (e) {
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: mode,
        endpointUri: proxyUri,
        httpMethod: 'POST',
        statusCode: e.response?.statusCode,
        initialDirectFailureReason: initialDirectFailureReason,
        timestamp: DateTime.now(),
      );
      _handleDioException(
        e,
        packet.id,
        mode: mode,
        endpointUri: proxyUri,
        initialDirectFailureReason: initialDirectFailureReason,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> probeOsmandPort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  }) async {
    if (_shouldUseHttpsProxy(customHost, customPort)) {
      return _probeViaProxy(
        proxyUri: appConfig.getOsmandProxyUri(),
        mode: OsmandTransportMode.httpsWebProxy,
        cancelToken: cancelToken,
      );
    }

    final directUri = buildOsmandUri(
      host: customHost,
      port: customPort,
      queryParameters: const {'id': 'probe_ping'},
    );

    try {
      final response = await _dio.getUri<dynamic>(
        directUri,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (status) => status != null,
        ),
      );

      final status = response.statusCode ?? 0;
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: OsmandTransportMode.directHttpPort,
        endpointUri: _stripQuery(directUri),
        httpMethod: 'GET',
        statusCode: status,
        timestamp: DateTime.now(),
      );
      // HTTP 200 OK (non-HTML) or 400 confirms Netty listener decoded the probe packet
      return (status == 200 && !_looksLikeHtmlResponse(response.data)) ||
          status == 400;
    } on DioException catch (e) {
      if (_shouldAttemptHttpProxyFallback(customHost, customPort, e)) {
        final directReason = _describeDioFailure(e);
        return _probeViaProxy(
          proxyUri: appConfig.getOsmandProxyUri(),
          mode: OsmandTransportMode.httpWebProxyFallback,
          initialDirectFailureReason: directReason,
          cancelToken: cancelToken,
        );
      }
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: OsmandTransportMode.directHttpPort,
        endpointUri: _stripQuery(directUri),
        httpMethod: 'GET',
        statusCode: e.response?.statusCode,
        timestamp: DateTime.now(),
      );
      return _rethrowProbeException(e, endpointUri: _stripQuery(directUri));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeViaProxy({
    required Uri proxyUri,
    required OsmandTransportMode mode,
    String? initialDirectFailureReason,
    CancelToken? cancelToken,
  }) async {
    try {
      // WebServer.initClientProxy ONLY intercepts `POST /` (not `GET /` which serves web SPA HTML).
      final response = await _dio.postUri<dynamic>(
        proxyUri,
        data: 'id=probe_ping',
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          validateStatus: (status) => status != null,
        ),
      );

      final status = response.statusCode ?? 0;
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: mode,
        endpointUri: proxyUri,
        httpMethod: 'POST',
        statusCode: status,
        initialDirectFailureReason: initialDirectFailureReason,
        timestamp: DateTime.now(),
      );

      return (status == 200 && !_looksLikeHtmlResponse(response.data)) ||
          status == 400;
    } on DioException catch (e) {
      _lastTransportDiagnostics = OsmandTransportDiagnostics(
        mode: mode,
        endpointUri: proxyUri,
        httpMethod: 'POST',
        statusCode: e.response?.statusCode,
        initialDirectFailureReason: initialDirectFailureReason,
        timestamp: DateTime.now(),
      );
      return _rethrowProbeException(
        e,
        mode: mode,
        endpointUri: proxyUri,
        initialDirectFailureReason: initialDirectFailureReason,
      );
    } catch (_) {
      return false;
    }
  }

  String _describeDioFailure(DioException e) {
    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!.trim();
    }
    return 'Direct port $defaultPort error (${e.type.name})';
  }

  bool _rethrowProbeException(
    DioException e, {
    OsmandTransportMode mode = OsmandTransportMode.directHttpPort,
    required Uri endpointUri,
    String? initialDirectFailureReason,
  }) {
    final fallbackSuffix = initialDirectFailureReason != null
        ? ' [Direct :$defaultPort error: $initialDirectFailureReason]'
        : '';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        'Probe OsmAnd (${mode.name}) timeout di $endpointUri dalam ${timeout.inSeconds} detik$fallbackSuffix',
        e.response?.statusCode,
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      throw NetworkException(
        'Endpoint OsmAnd ($endpointUri) tidak dapat dihubungi atau dinonaktifkan di server Traccar$fallbackSuffix',
        e.response?.statusCode,
      );
    }
    return false;
  }

  Never _handleDioException(
    DioException e,
    String deviceId, {
    OsmandTransportMode mode = OsmandTransportMode.directHttpPort,
    Uri? endpointUri,
    String? initialDirectFailureReason,
  }) {
    final statusCode = e.response?.statusCode;
    final targetLabel = endpointUri?.toString() ?? 'port $defaultPort';
    final fallbackSuffix = initialDirectFailureReason != null
        ? ' [via Fallback Proxy $targetLabel; Direct :$defaultPort error: $initialDirectFailureReason]'
        : '';

    if (statusCode == 400) {
      throw ServerException(
        'ID perangkat "$deviceId" tidak dikenali di server Traccar (HTTP 400)$fallbackSuffix',
        400,
      );
    } else if (statusCode == 401) {
      throw AuthException(
        'Autentikasi ditolak pada endpoint telemetri$fallbackSuffix',
        401,
      );
    } else if (statusCode == 403) {
      throw ForbiddenException(
        'Akses ditolak pada endpoint telemetri Traccar$fallbackSuffix',
        403,
      );
    } else if (statusCode == 404 || statusCode == 405) {
      throw ServerException(
        'Endpoint atau metode OsmAnd tidak didukung ($targetLabel, HTTP $statusCode)$fallbackSuffix',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        'Koneksi ke OsmAnd ($targetLabel) timeout (${timeout.inSeconds} detik). Pastikan endpoint aktif.$fallbackSuffix',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError ||
        (e.type == DioExceptionType.unknown && e.response == null)) {
      throw NetworkException(
        'Gagal terhubung ke OsmAnd Traccar ($targetLabel). Pastikan server aktif, hostname valid, dan transport diizinkan.$fallbackSuffix',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Pengiriman paket telemetri dibatalkan',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Terjadi kesalahan saat mentransmisikan paket telemetri OsmAnd',
        statusCode,
      );
    }
  }
}
