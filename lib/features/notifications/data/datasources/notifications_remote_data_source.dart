import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/notification_model.dart';
import '../models/notification_type_model.dart';

/// Contract for interacting with Traccar Notifications REST API.
abstract class NotificationsRemoteDataSource {
  /// Fetches notification rules from Traccar REST API.
  /// Endpoint: GET `/api/notifications`
  /// Query params: optional [all], [userId], [deviceId], [groupId], [refresh].
  Future<List<NotificationModel>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  });

  /// Creates a new notification rule.
  /// Endpoint: POST `/api/notifications`
  Future<NotificationModel> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  });

  /// Updates an existing notification rule.
  /// Endpoint: PUT `/api/notifications/{id}`
  Future<NotificationModel> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  });

  /// Deletes a notification rule by [id].
  /// Endpoint: DELETE `/api/notifications/{id}`
  Future<void> deleteNotification(int id, {CancelToken? cancelToken});

  /// Fetches list of all supported event types that can trigger notifications.
  /// Endpoint: GET `/api/notifications/types`
  Future<List<NotificationTypeModel>> getNotificationTypes({
    CancelToken? cancelToken,
  });

  /// Fetches list of available delivery channels (web, mail, firebase, etc.).
  /// Endpoint: GET `/api/notifications/notificators`
  Future<List<NotificationTypeModel>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  });

  /// Dispatches a test message across a specific notification channel.
  /// Endpoint: POST `/api/notifications/test/{notificator}`
  Future<void> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  });

  /// Dispatches test messages across all supported notification channels.
  /// Endpoint: POST `/api/notifications/test`
  Future<void> testAllNotificationChannels({CancelToken? cancelToken});

  /// Updates user properties (specifically attributes for FCM token registration).
  /// Endpoint: PUT `/api/users/{id}`
  Future<UserModel> updateUser(UserModel user, {CancelToken? cancelToken});
}

/// Production implementation of [NotificationsRemoteDataSource] using [DioClient].
/// Reuses existing authentication, RFC 6265 cookies, and security interceptors.
class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final DioClient dioClient;

  NotificationsRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<NotificationModel>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (all != null) queryParams['all'] = all;
      if (userId != null) queryParams['userId'] = userId;
      if (deviceId != null) queryParams['deviceId'] = deviceId;
      if (groupId != null) queryParams['groupId'] = groupId;
      if (refresh != null) queryParams['refresh'] = refresh;

      final response = await dioClient.get<dynamic>(
        ApiEndpoints.notifications,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) => NotificationModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/get');
    }
  }

  @override
  Future<NotificationModel> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.post<dynamic>(
        ApiEndpoints.notifications,
        data: notification.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map) {
        return NotificationModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ServerException(
        'Invalid response body received from server on create notification',
        500,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/create');
    }
  }

  @override
  Future<NotificationModel> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        '${ApiEndpoints.notifications}/${notification.id}',
        data: notification.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map) {
        return NotificationModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ServerException(
        'Invalid response body received from server on update notification',
        500,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/update');
    }
  }

  @override
  Future<void> deleteNotification(int id, {CancelToken? cancelToken}) async {
    try {
      await dioClient.delete<dynamic>(
        '${ApiEndpoints.notifications}/$id',
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/delete');
    }
  }

  @override
  Future<List<NotificationTypeModel>> getNotificationTypes({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.notificationsTypes,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) => NotificationTypeModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/types');
    }
  }

  @override
  Future<List<NotificationTypeModel>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (announcement != null) queryParams['announcement'] = announcement;

      final response = await dioClient.get<dynamic>(
        ApiEndpoints.notificationsNotificators,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) => NotificationTypeModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/notificators');
    }
  }

  @override
  Future<void> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.notificationTest(notificator),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/test/$notificator');
    }
  }

  @override
  Future<void> testAllNotificationChannels({CancelToken? cancelToken}) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.notificationTestAll,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'notifications/test');
    }
  }

  @override
  Future<UserModel> updateUser(
    UserModel user, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        '${ApiEndpoints.users}/${user.id}',
        data: user.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ServerException(
        'Invalid response body received from server on update user',
        500,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'users/update');
    }
  }

  Never _handleDioException(DioException e, String resourceName) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      throw const AuthException('Session expired or unauthorized', 401);
    } else if (statusCode == 403) {
      throw ForbiddenException(
        'Forbidden: Access denied to notification resource ($resourceName)',
        403,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Notification request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Notification request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on notification resource ($resourceName)',
        statusCode,
      );
    }
  }
}
