import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../utils/app_logger.dart';

typedef ReAuthCallback = Future<bool> Function();
typedef SessionExpiredCallback = void Function();

/// Mutex-controlled re-authentication interceptor on HTTP 401.
/// Serializes concurrent 401 failures so only one re-login attempt runs at a time.
/// Excludes login (POST /api/session) and enforces a single retry limit.
class QueuedReAuthInterceptor extends Interceptor {
  final Dio dio;
  final ReAuthCallback onReAuth;
  final SessionExpiredCallback? onSessionExpired;

  Completer<bool>? _reauthCompleter;

  bool get isReAuthInProgress => _reauthCompleter != null;

  /// Cancels in-flight re-authentication and immediately unblocks any waiting requests.
  void cancelActiveReAuth() {
    if (_reauthCompleter != null && !_reauthCompleter!.isCompleted) {
      _reauthCompleter!.complete(false);
      _reauthCompleter = null;
    }
  }

  QueuedReAuthInterceptor({
    required this.dio,
    required this.onReAuth,
    this.onSessionExpired,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final statusCode = response?.statusCode;
    final requestOptions = err.requestOptions;

    // Check if error is 401 Unauthorized
    if (statusCode != 401) {
      return handler.next(err);
    }

    // Exclude login endpoint to prevent infinite loop on wrong credentials
    final isLoginEndpoint =
        requestOptions.path.contains(ApiEndpoints.session) &&
        requestOptions.method.toUpperCase() == 'POST';
    if (isLoginEndpoint) {
      return handler.next(err);
    }

    // Enforce retry limit (max 1 retry)
    final retryCount =
        (requestOptions.extra['reauth_retry_count'] as int?) ?? 0;
    if (retryCount >= 1) {
      AppLogger.warn(
        'Re-auth retry limit exceeded for: ${requestOptions.path}',
      );
      onSessionExpired?.call();
      return handler.next(err);
    }

    // Mutex handling: if re-auth already in flight, queue behind the leader
    if (_reauthCompleter != null) {
      AppLogger.info(
        'Queuing concurrent 401 request behind active re-auth: ${requestOptions.path}',
      );
      final success = await _reauthCompleter!.future;
      if (success) {
        return await _retryRequest(requestOptions, retryCount + 1, handler);
      } else {
        return handler.next(err);
      }
    }

    // Leader request: initiate transparent re-authentication
    _reauthCompleter = Completer<bool>();
    AppLogger.info(
      'Initiating transparent re-auth mutex for 401 at: ${requestOptions.path}',
    );

    try {
      final success = await onReAuth();
      if (success) {
        _reauthCompleter?.complete(true);
        _reauthCompleter = null;
        return await _retryRequest(requestOptions, retryCount + 1, handler);
      } else {
        _reauthCompleter?.complete(false);
        _reauthCompleter = null;
        onSessionExpired?.call();
        return handler.next(err);
      }
    } catch (e, stack) {
      AppLogger.error('Transparent re-auth failed with exception', e, stack);
      _reauthCompleter?.complete(false);
      _reauthCompleter = null;
      onSessionExpired?.call();
      return handler.next(err);
    }
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    int newRetryCount,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final newExtra = Map<String, dynamic>.from(requestOptions.extra);
      newExtra['reauth_retry_count'] = newRetryCount;

      final options = Options(
        method: requestOptions.method,
        headers: Map<String, dynamic>.from(requestOptions.headers),
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveTimeout: requestOptions.receiveTimeout,
        sendTimeout: requestOptions.sendTimeout,
        extra: newExtra,
      );

      final retryResponse = await dio.request<dynamic>(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options,
      );

      return handler.resolve(retryResponse);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      return handler.next(
        DioException(requestOptions: requestOptions, error: e),
      );
    }
  }
}
