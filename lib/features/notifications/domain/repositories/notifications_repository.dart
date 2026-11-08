import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/notification_type_model.dart';

/// Domain contract for Traccar Notifications, Event rules, and Channel testing.
abstract class NotificationsRepository {
  /// Fetches notification rules from Traccar server.
  Future<Either<Failure, List<NotificationModel>>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  });

  /// Creates a new notification rule.
  Future<Either<Failure, NotificationModel>> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  });

  /// Updates an existing notification rule.
  Future<Either<Failure, NotificationModel>> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  });

  /// Deletes a notification rule by [id].
  Future<Either<Failure, void>> deleteNotification(
    int id, {
    CancelToken? cancelToken,
  });

  /// Fetches supported event types.
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificationTypes({
    CancelToken? cancelToken,
  });

  /// Fetches available delivery channels (web, mail, firebase, etc.).
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  });

  /// Dispatches a test message across a specific notification channel.
  Future<Either<Failure, void>> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  });

  /// Dispatches test messages across all supported channels.
  Future<Either<Failure, void>> testAllNotificationChannels({
    CancelToken? cancelToken,
  });

  /// Registers an FCM token onto [currentUser] safely using [FcmTokenMerger]
  /// and updates Traccar via `PUT /api/users/{id}` without clobbering other attributes.
  Future<Either<Failure, UserModel>> registerNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  });

  /// Unregisters an FCM token from [currentUser] safely and updates Traccar.
  Future<Either<Failure, UserModel>> unregisterNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  });
}
