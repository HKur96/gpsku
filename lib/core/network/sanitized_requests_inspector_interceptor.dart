import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:requests_inspector/requests_inspector.dart';

/// Interceptor that feeds requests and responses into RequestsInspector
/// with strict sanitization of security-sensitive tokens, cookies, and credentials.
/// Automatically disabled in kReleaseMode.
class SanitizedRequestsInspectorInterceptor extends Interceptor {
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-csrf-token',
  };

  static const Set<String> _sensitiveBodyKeys = {
    'password',
    'token',
    'secret',
    'salt',
    'totp',
    'credential',
    'credentials',
    'refreshtoken',
    'accesstoken',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kReleaseMode) {
      return super.onRequest(options, handler);
    }
    options.extra['startTime'] = DateTime.now();
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kReleaseMode) {
      return super.onResponse(response, handler);
    }

    final sentTime =
        response.requestOptions.extra['startTime'] as DateTime? ??
        DateTime.now();
    final receivedTime = DateTime.now();
    final urlAndQuery = _extractUrl(response.requestOptions);

    final method = _parseMethod(response.requestOptions.method);

    InspectorController().addNewRequest(
      RequestDetails(
        requestMethod: method,
        url: urlAndQuery.key,
        statusCode: response.statusCode ?? 0,
        headers: _sanitizeHeaders(response.requestOptions.headers),
        queryParameters: _sanitizeMap(response.requestOptions.queryParameters),
        requestBody: _sanitizePayload(response.requestOptions.data),
        responseBody: _sanitizePayload(response.data),
        sentTime: sentTime,
        receivedTime: receivedTime,
      ),
    );

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kReleaseMode) {
      return super.onError(err, handler);
    }

    final sentTime =
        err.requestOptions.extra['startTime'] as DateTime? ?? DateTime.now();
    final receivedTime = DateTime.now();
    final urlAndQuery = _extractUrl(err.requestOptions);
    final method = _parseMethod(err.requestOptions.method);

    InspectorController().addNewRequest(
      RequestDetails(
        requestMethod: method,
        url: urlAndQuery.key,
        statusCode: err.response?.statusCode ?? 0,
        headers: _sanitizeHeaders(err.requestOptions.headers),
        queryParameters: _sanitizeMap(err.requestOptions.queryParameters),
        requestBody: _sanitizePayload(err.requestOptions.data),
        responseBody: _sanitizePayload(err.response?.data ?? err.message),
        sentTime: sentTime,
        receivedTime: receivedTime,
      ),
    );

    super.onError(err, handler);
  }

  RequestMethod _parseMethod(String method) {
    return RequestMethod.values.firstWhere(
      (e) => e.name.toUpperCase() == method.toUpperCase(),
      orElse: () => RequestMethod.GET,
    );
  }

  MapEntry<String, Map<String, dynamic>> _extractUrl(
    RequestOptions requestOptions,
  ) {
    final splitUrl = requestOptions.uri.toString().split('?');
    final queryParameters = Uri.splitQueryString(
      splitUrl.length > 1 ? splitUrl[1] : '',
    );
    return MapEntry(splitUrl[0], queryParameters);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic>? headers) {
    if (headers == null) return {};
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      if (_sensitiveHeaders.contains(entry.key.toLowerCase())) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  dynamic _sanitizePayload(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(data));
    } else if (data is List) {
      return data.map((item) => _sanitizePayload(item)).toList();
    } else if (data is String) {
      // Check if it's JSON
      if (data.trim().startsWith('{') && data.trim().endsWith('}')) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            return jsonEncode(_sanitizeMap(decoded));
          }
        } catch (_) {}
      }
      // Check if form-urlencoded (e.g. email=...&password=...)
      if (data.contains('=') &&
          (data.contains('&') || data.contains('password'))) {
        try {
          final parsed = Uri.splitQueryString(data);
          final sanitized = _sanitizeMap(parsed);
          return sanitized.entries.map((e) => '${e.key}=${e.value}').join('&');
        } catch (_) {}
      }
      return data;
    }
    return data;
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final keyLower = entry.key.toLowerCase();
      if (_sensitiveBodyKeys.any((k) => keyLower.contains(k))) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is Map) {
        sanitized[entry.key] = _sanitizeMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else if (entry.value is List) {
        sanitized[entry.key] = (entry.value as List)
            .map((i) => _sanitizePayload(i))
            .toList();
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}
