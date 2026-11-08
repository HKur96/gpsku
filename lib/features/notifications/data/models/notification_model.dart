import 'package:flutter/foundation.dart';

/// Immutable representation of a Traccar notification rule entity.
/// Manages configuration for how and when telematics events trigger notifications
/// across channels (`web`, `mail`, `sms`, `firebase`, etc.).
@immutable
class NotificationModel {
  final int id;
  final String type;
  final String? description;
  final bool always;
  final String notificators;
  final int calendarId;
  final int commandId;
  final Map<String, dynamic> attributes;

  // Standard Notificator Channel Identifiers
  static const String notificatorWeb = 'web';
  static const String notificatorMail = 'mail';
  static const String notificatorSms = 'sms';
  static const String notificatorFirebase = 'firebase';
  static const String notificatorTelegram = 'telegram';
  static const String notificatorWhatsapp = 'whatsapp';
  static const String notificatorTraccar = 'traccar';
  static const String notificatorPushover = 'pushover';
  static const String notificatorCommand = 'command';

  const NotificationModel({
    required this.id,
    required this.type,
    this.description,
    this.always = false,
    this.notificators = '',
    this.calendarId = 0,
    this.commandId = 0,
    this.attributes = const {},
  });

  /// Factory constructor to parse notification entity from JSON.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      description: json['description'] as String?,
      always: json['always'] as bool? ?? false,
      notificators: json['notificators'] as String? ?? '',
      calendarId: (json['calendarId'] as num?)?.toInt() ?? 0,
      commandId: (json['commandId'] as num?)?.toInt() ?? 0,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(json['attributes'] as Map)
          : const {},
    );
  }

  /// Serializes this notification rule into standard Traccar JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (description != null) 'description': description,
      'always': always,
      'notificators': notificators,
      'calendarId': calendarId,
      'commandId': commandId,
      'attributes': attributes,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? type,
    String? description,
    bool? always,
    String? notificators,
    int? calendarId,
    int? commandId,
    Map<String, dynamic>? attributes,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      always: always ?? this.always,
      notificators: notificators ?? this.notificators,
      calendarId: calendarId ?? this.calendarId,
      commandId: commandId ?? this.commandId,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Returns parsed, trimmed list of configured notification channels.
  List<String> get notificatorList {
    if (notificators.trim().isEmpty) return const [];
    return List<String>.unmodifiable(
      notificators.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty),
    );
  }

  /// Checks if a specific channel is enabled on this notification.
  bool hasNotificator(String channel) {
    final needle = channel.trim().toLowerCase();
    return notificatorList.any((n) => n.toLowerCase() == needle);
  }

  /// True if Web channel is active.
  bool get hasWeb => hasNotificator(notificatorWeb);

  /// True if Firebase Push notification channel is active.
  bool get hasFirebase => hasNotificator(notificatorFirebase);

  /// True if Mail channel is active.
  bool get hasMail => hasNotificator(notificatorMail);

  /// True if SMS channel is active.
  bool get hasSms => hasNotificator(notificatorSms);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel &&
        other.id == id &&
        other.type == type &&
        other.description == description &&
        other.always == always &&
        other.notificators == notificators &&
        other.calendarId == calendarId &&
        other.commandId == commandId &&
        mapEquals(other.attributes, attributes);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      description,
      always,
      notificators,
      calendarId,
      commandId,
      Object.hashAllUnordered(
        attributes.entries.map((e) => Object.hash(e.key, e.value)),
      ),
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, '
        'notificators: $notificators, always: $always)';
  }
}
