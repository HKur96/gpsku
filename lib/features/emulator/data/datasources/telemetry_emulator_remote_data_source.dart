import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/telemetry_packet_model.dart';

/// Contract for transmitting simulated telemetry packets to Traccar's
/// OsmAnd protocol listener (Netty TrackerServer on port 5055).
abstract class TelemetryEmulatorRemoteDataSource {
  /// Transmits a mock telemetry packet to Traccar OsmAnd ingestion port (default: 5055).
  ///
  /// Can use HTTP POST (default) or HTTP GET.
  /// Throws [ServerException], [NetworkException], [ConnectionTimeoutException].
  Future<bool> sendTelemetryPacket(
    TelemetryPacketModel packet, {
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  });

  /// Probes the OsmAnd port reachability to verify the protocol listener is active.
  /// Returns `true` if port responds with HTTP 200 or HTTP 400.
  Future<bool> probeOsmandPort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [TelemetryEmulatorRemoteDataSource] utilizing
/// short-timeout HTTP calls specifically tuned for emulator responsiveness.
class TelemetryEmulatorRemoteDataSourceImpl
    implements TelemetryEmulatorRemoteDataSource {
  final AppConfig appConfig;
  final Dio _dio;
  final Duration timeout;
  final int defaultPort;

  TelemetryEmulatorRemoteDataSourceImpl({
    required this.appConfig,
    Dio? dio,
    this.timeout = const Duration(seconds: 4),
    this.defaultPort = 5055,
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

  String _resolveScheme([String? customScheme]) {
    if (customScheme != null && customScheme.isNotEmpty) {
      return customScheme;
    }
    // Netty TrackerServer on OsmAnd port 5055 is a plain HTTP socket.
    // Always default to 'http' to prevent SSL HandshakeException even when REST API uses 'https'.
    return 'http';
  }

  /// Builds a target [Uri] targeting the OsmAnd listener.
  Uri buildOsmandUri({
    String? host,
    int? port,
    Map<String, String>? queryParameters,
  }) {
    return Uri(
      scheme: _resolveScheme(),
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
    try {
      final uri = buildOsmandUri(
        host: customHost,
        port: customPort,
        queryParameters: packet.toOsmAndParams(),
      );

      final response = usePost
          ? await _dio.postUri<dynamic>(
              uri,
              cancelToken: cancelToken,
              options: Options(
                sendTimeout: timeout,
                receiveTimeout: timeout,
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              ),
            )
          : await _dio.getUri<dynamic>(
              uri,
              cancelToken: cancelToken,
              options: Options(sendTimeout: timeout, receiveTimeout: timeout),
            );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
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
      _handleDioException(e, packet.id);
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
    try {
      final uri = buildOsmandUri(
        host: customHost,
        port: customPort,
        queryParameters: const {'id': 'probe_ping'},
      );

      final response = await _dio.getUri<dynamic>(
        uri,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (status) => status != null,
        ),
      );

      final status = response.statusCode ?? 0;
      // HTTP 200 OK or 400 (unknown device probe_ping) proves port 5055 is active and decoded the request
      return status == 200 || status == 400;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ConnectionTimeoutException(
          'Probe port OsmAnd timeout: Server tidak merespons dalam ${timeout.inSeconds} detik',
          e.response?.statusCode,
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          'Port OsmAnd ($defaultPort) tidak dapat dihubungi atau dinonaktifkan di server Traccar',
          e.response?.statusCode,
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Never _handleDioException(DioException e, String deviceId) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 400) {
      throw ServerException(
        'ID perangkat "$deviceId" tidak dikenali di server Traccar (HTTP 400)',
        400,
      );
    } else if (statusCode == 401) {
      throw const AuthException('Autentikasi ditolak pada port telemetri', 401);
    } else if (statusCode == 403) {
      throw const ForbiddenException(
        'Akses ditolak pada port telemetri Traccar',
        403,
      );
    } else if (statusCode == 404) {
      throw ServerException(
        'Endpoint atau port telemetri tidak ditemukan (HTTP 404)',
        404,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        'Koneksi ke port OsmAnd timeout (${timeout.inSeconds} detik). Pastikan port terbuka.',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        'Gagal terhubung ke port OsmAnd Traccar ($defaultPort). Pastikan server aktif dan firewall mengizinkan port $defaultPort.',
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
