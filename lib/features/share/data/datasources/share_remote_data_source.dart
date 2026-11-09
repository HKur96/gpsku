import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';

/// Contract for managing public vehicle & fleet share links via Traccar REST API.
abstract class ShareRemoteDataSource {
  /// Generates a temporary access token for a single specific vehicle.
  ///
  /// Endpoint: `POST /api/share/device`
  /// Content-Type: `application/x-www-form-urlencoded`
  /// Parameters: [deviceId], [expiration] (ISO 8601 UTC string).
  Future<String> createDeviceShareToken({
    required int deviceId,
    required DateTime expiration,
    CancelToken? cancelToken,
  });

  /// Generates a temporary access token for an entire fleet group.
  ///
  /// Endpoint: `POST /api/share/group`
  /// Content-Type: `application/x-www-form-urlencoded`
  /// Parameters: [groupId], [expiration] (ISO 8601 UTC string).
  Future<String> createGroupShareToken({
    required int groupId,
    required DateTime expiration,
    CancelToken? cancelToken,
  });

  /// Generates a temporary user session token.
  ///
  /// Endpoint: `POST /api/session/token`
  /// Content-Type: `application/x-www-form-urlencoded`
  /// Parameters: [expiration] (ISO 8601 UTC string).
  Future<String> createUserSessionToken({
    required DateTime expiration,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [ShareRemoteDataSource] using [DioClient].
///
/// Sends form-urlencoded requests to Traccar backend matching Traccar Web's
/// `SharePage.jsx` and OpenAPI specification.
class ShareRemoteDataSourceImpl implements ShareRemoteDataSource {
  final DioClient dioClient;

  ShareRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
  };

  @override
  Future<String> createDeviceShareToken({
    required int deviceId,
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    _validateExpiration(expiration);

    try {
      final formData = {
        'deviceId': deviceId,
        'expiration': expiration.toUtc().toIso8601String(),
      };

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.shareDevice,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
          responseType: ResponseType.plain,
        ),
        cancelToken: cancelToken,
      );

      final token = response.data?.toString().trim();
      if (token == null || token.isEmpty) {
        throw const ServerException(
          'Token tautan berbagi kosong diterima dari server Traccar',
        );
      }
      return token;
    } on DioException catch (e) {
      _handleDioException(e, 'share/device');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> createGroupShareToken({
    required int groupId,
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    _validateExpiration(expiration);

    try {
      final formData = {
        'groupId': groupId,
        'expiration': expiration.toUtc().toIso8601String(),
      };

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.shareGroup,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
          responseType: ResponseType.plain,
        ),
        cancelToken: cancelToken,
      );

      final token = response.data?.toString().trim();
      if (token == null || token.isEmpty) {
        throw const ServerException(
          'Token tautan berbagi grup kosong diterima dari server Traccar',
        );
      }
      return token;
    } on DioException catch (e) {
      _handleDioException(e, 'share/group');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> createUserSessionToken({
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    _validateExpiration(expiration);

    try {
      final formData = {'expiration': expiration.toUtc().toIso8601String()};

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.sessionToken,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
          responseType: ResponseType.plain,
        ),
        cancelToken: cancelToken,
      );

      final token = response.data?.toString().trim();
      if (token == null || token.isEmpty) {
        throw const ServerException(
          'Token sesi kosong diterima dari server Traccar',
        );
      }
      return token;
    } on DioException catch (e) {
      _handleDioException(e, 'session/token');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  void _validateExpiration(DateTime expiration) {
    if (expiration.isBefore(DateTime.now())) {
      throw const ServerException(
        'Waktu kedaluwarsa tidak boleh di masa lalu',
        400,
      );
    }
  }

  Never _handleDioException(DioException e, String resourceName) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      throw AuthException(
        'Sesi telah berakhir atau tidak terautentikasi ($resourceName)',
        401,
      );
    } else if (statusCode == 403) {
      throw ForbiddenException(
        'Fitur berbagi publik dinonaktifkan oleh administrator server atau akun sementara ($resourceName)',
        403,
      );
    } else if (statusCode == 409) {
      throw ConflictException(
        'Tautan berbagi aktif untuk entitas ini sudah terdaftar di server ($resourceName)',
        409,
      );
    } else if (statusCode == 404) {
      throw ServerException(
        'Perangkat atau grup tidak ditemukan di server ($resourceName)',
        404,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Permintaan pembuatan tautan berbagi tidak valid ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Koneksi ke server Traccar timeout ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ??
            'Gagal terhubung ke jaringan server Traccar ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Permintaan pembuatan tautan dibatalkan oleh pemanggil ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Terjadi kesalahan server saat membuat tautan ($resourceName)',
        statusCode,
      );
    }
  }
}
