import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar supported notification/event types or notificator channels.
/// Returned by `/api/notifications/types` and `/api/notifications/notificators`.
@immutable
class NotificationTypeModel {
  final String type;
  final String? name;

  const NotificationTypeModel({required this.type, this.name});

  factory NotificationTypeModel.fromJson(Map<String, dynamic> json) {
    return NotificationTypeModel(
      type: json['type'] as String? ?? '',
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, if (name != null) 'name': name};
  }

  NotificationTypeModel copyWith({String? type, String? name}) {
    return NotificationTypeModel(
      type: type ?? this.type,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationTypeModel &&
        other.type == type &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(type, name);

  @override
  String toString() => 'NotificationTypeModel(type: $type, name: $name)';
}
