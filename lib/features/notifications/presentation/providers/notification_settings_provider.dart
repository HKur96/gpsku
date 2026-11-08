import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/notification_type_model.dart';
import '../../domain/repositories/notifications_repository.dart';

/// State management provider for Traccar notification rules and delivery channels configuration.
class NotificationSettingsProvider extends ChangeNotifier {
  final NotificationsRepository repository;

  List<NotificationModel> _notifications = [];
  List<NotificationTypeModel> _types = [];
  List<NotificationTypeModel> _notificators = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _testingNotificator;
  String? _errorMessage;

  NotificationSettingsProvider({required this.repository});

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  List<NotificationTypeModel> get types => List.unmodifiable(_types);
  List<NotificationTypeModel> get notificators =>
      List.unmodifiable(_notificators);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get testingNotificator => _testingNotificator;
  String? get errorMessage => _errorMessage;

  /// Default telematics event types when backend types are not yet fetched or empty.
  static const List<NotificationTypeModel> defaultTypes = [
    NotificationTypeModel(type: 'alarm', name: 'Alarm / Darurat'),
    NotificationTypeModel(type: 'deviceOnline', name: 'Unit Online'),
    NotificationTypeModel(type: 'deviceOffline', name: 'Unit Offline'),
    NotificationTypeModel(type: 'deviceMoving', name: 'Unit Bergerak'),
    NotificationTypeModel(type: 'deviceStopped', name: 'Unit Berhenti'),
    NotificationTypeModel(type: 'geofenceEnter', name: 'Masuk Geofence'),
    NotificationTypeModel(type: 'geofenceExit', name: 'Keluar Geofence'),
    NotificationTypeModel(type: 'overspeed', name: 'Batas Kecepatan'),
    NotificationTypeModel(type: 'ignitionOn', name: 'Kontak ON'),
    NotificationTypeModel(type: 'ignitionOff', name: 'Kontak OFF'),
    NotificationTypeModel(type: 'maintenance', name: 'Jadwal Pemeliharaan'),
    NotificationTypeModel(type: 'driverChanged', name: 'Pengemudi Berganti'),
  ];

  /// Default notification channels supported by Traccar.
  static const List<NotificationTypeModel> defaultNotificators = [
    NotificationTypeModel(type: 'web', name: 'Web / In-App'),
    NotificationTypeModel(type: 'firebase', name: 'Push FCM'),
    NotificationTypeModel(type: 'mail', name: 'Email'),
    NotificationTypeModel(type: 'sms', name: 'SMS'),
    NotificationTypeModel(type: 'telegram', name: 'Telegram'),
  ];

  /// Formats raw event type code into human-readable label.
  static String formatEventType(String type) {
    switch (type) {
      case 'alarm':
        return 'Alarm / Darurat';
      case 'deviceOnline':
        return 'Unit Online';
      case 'deviceOffline':
        return 'Unit Offline';
      case 'deviceMoving':
        return 'Unit Bergerak';
      case 'deviceStopped':
        return 'Unit Berhenti';
      case 'geofenceEnter':
        return 'Masuk Geofence';
      case 'geofenceExit':
        return 'Keluar Geofence';
      case 'geofenceCrossed':
        return 'Melintasi Geofence';
      case 'ignitionOn':
        return 'Kontak ON';
      case 'ignitionOff':
        return 'Kontak OFF';
      case 'overspeed':
        return 'Batas Kecepatan';
      case 'maintenance':
        return 'Jadwal Pemeliharaan';
      case 'driverChanged':
        return 'Pengemudi Berganti';
      case 'commandResult':
        return 'Hasil Perintah';
      default:
        return type;
    }
  }

  /// Formats notificator channel code into human-readable label.
  static String formatChannelName(String channel) {
    switch (channel.toLowerCase()) {
      case 'web':
        return 'Web / In-App';
      case 'firebase':
        return 'Push FCM';
      case 'mail':
        return 'Email';
      case 'sms':
        return 'SMS';
      case 'telegram':
        return 'Telegram';
      case 'whatsapp':
        return 'WhatsApp';
      case 'traccar':
        return 'Traccar';
      case 'pushover':
        return 'Pushover';
      default:
        return channel;
    }
  }

  /// Fetches notification rules, supported event types, and delivery channels from Traccar server.
  Future<void> fetchSettings({bool refresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getNotifications(refresh: refresh),
        repository.getNotificationTypes(),
        repository.getNotificators(),
      ]);

      final notifResult = results[0];
      final typesResult = results[1];
      final notificatorsResult = results[2];

      notifResult.fold(
        (failure) {
          _errorMessage = failure.message;
          AppLogger.error(
            'NotificationSettingsProvider: Failed fetching notifications: ${failure.message}',
          );
        },
        (data) {
          _notifications = List<NotificationModel>.from(
            data as List<NotificationModel>,
          );
        },
      );

      typesResult.fold((_) => _types = List.from(defaultTypes), (data) {
        final fetched = data as List<NotificationTypeModel>;
        _types = fetched.isNotEmpty ? fetched : List.from(defaultTypes);
      });

      notificatorsResult.fold(
        (_) => _notificators = List.from(defaultNotificators),
        (data) {
          final fetched = data as List<NotificationTypeModel>;
          _notificators = fetched.isNotEmpty
              ? fetched
              : List.from(defaultNotificators);
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      AppLogger.error(
        'NotificationSettingsProvider: Unexpected error fetching settings: $e',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new notification rule on Traccar backend.
  Future<bool> createNotification(NotificationModel notification) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.createNotification(notification);

    return result.fold(
      (failure) {
        _isSaving = false;
        _errorMessage = failure.message;
        AppLogger.error(
          'NotificationSettingsProvider: Failed creating notification: ${failure.message}',
        );
        notifyListeners();
        return false;
      },
      (created) {
        _isSaving = false;
        _notifications = [..._notifications, created];
        AppLogger.info(
          'NotificationSettingsProvider: Notification created #${created.id} (${created.type})',
        );
        notifyListeners();
        return true;
      },
    );
  }

  /// Updates an existing notification rule on Traccar backend.
  Future<bool> updateNotification(NotificationModel notification) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.updateNotification(notification);

    return result.fold(
      (failure) {
        _isSaving = false;
        _errorMessage = failure.message;
        AppLogger.error(
          'NotificationSettingsProvider: Failed updating notification #${notification.id}: ${failure.message}',
        );
        notifyListeners();
        return false;
      },
      (updated) {
        _isSaving = false;
        _notifications = _notifications
            .map((n) => n.id == updated.id ? updated : n)
            .toList();
        AppLogger.info(
          'NotificationSettingsProvider: Notification updated #${updated.id}',
        );
        notifyListeners();
        return true;
      },
    );
  }

  /// Deletes a notification rule by [id] on Traccar backend.
  Future<bool> deleteNotification(int id) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.deleteNotification(id);

    return result.fold(
      (failure) {
        _isSaving = false;
        _errorMessage = failure.message;
        AppLogger.error(
          'NotificationSettingsProvider: Failed deleting notification #$id: ${failure.message}',
        );
        notifyListeners();
        return false;
      },
      (_) {
        _isSaving = false;
        _notifications = _notifications.where((n) => n.id != id).toList();
        AppLogger.info(
          'NotificationSettingsProvider: Notification deleted #$id',
        );
        notifyListeners();
        return true;
      },
    );
  }

  /// Dispatches a test message across a specific notification channel.
  Future<bool> testNotificator(String notificator) async {
    _testingNotificator = notificator;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.testNotificationChannel(notificator);

    _testingNotificator = null;
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'NotificationSettingsProvider: Failed testing channel $notificator: ${failure.message}',
        );
        notifyListeners();
        return false;
      },
      (_) {
        AppLogger.info(
          'NotificationSettingsProvider: Test message successfully sent to channel $notificator',
        );
        notifyListeners();
        return true;
      },
    );
  }

  /// Clears in-memory cache and state for user logout / session reset.
  void clearSettings() {
    _notifications = [];
    _types = [];
    _notificators = [];
    _errorMessage = null;
    _isLoading = false;
    _isSaving = false;
    _testingNotificator = null;
    notifyListeners();
  }
}
