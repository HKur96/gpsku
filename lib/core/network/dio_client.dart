import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'cookie_interceptor.dart';
import 'queued_reauth_interceptor.dart';
import 'sanitized_requests_inspector_interceptor.dart';
import 'session_cookie_jar.dart';

/// Configured Dio client instance tailored for Traccar REST API.
class DioClient {
  late final Dio _dio;
  final AppConfig appConfig;
  final SessionCookieJar cookieJar;
  QueuedReAuthInterceptor? _reAuthInterceptor;

  DioClient({
    required this.appConfig,
    required this.cookieJar,
    ReAuthCallback? onReAuth,
    SessionExpiredCallback? onSessionExpired,
    Dio? customDio,
  }) {
    _dio =
        customDio ??
        Dio(
          BaseOptions(
            baseUrl: appConfig.baseUrl,
            connectTimeout: appConfig.connectTimeout,
            receiveTimeout: appConfig.receiveTimeout,
            sendTimeout: appConfig.sendTimeout,
            headers: {'Accept': 'application/json'},
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
        );

    // Resilient JSON transformer: Traccar backend returns text error traces on 401/404 with JSON Content-Type
    _dio.transformer = SafeJsonTransformer();

    // 1. Session Cookie Interceptor (RFC 6265)
    _dio.interceptors.add(CookieInterceptor(cookieJar: cookieJar));

    // 2. Sanitized Requests Inspector (Debug only, credentials redacted)
    _dio.interceptors.add(SanitizedRequestsInspectorInterceptor());

    // 3. Mutex Re-Auth Interceptor (if reauth callback provided)
    if (onReAuth != null) {
      _reAuthInterceptor = QueuedReAuthInterceptor(
        dio: _dio,
        onReAuth: onReAuth,
        onSessionExpired: onSessionExpired,
      );
      _dio.interceptors.add(_reAuthInterceptor!);
    }
  }

  Dio get dio => _dio;
  QueuedReAuthInterceptor? get reAuthInterceptor => _reAuthInterceptor;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

class SafeJsonTransformer extends SyncTransformer {
  SafeJsonTransformer() {
    jsonDecodeCallback = _safeJsonDecode;
  }
}

dynamic _safeJsonDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return text;
  }
}
