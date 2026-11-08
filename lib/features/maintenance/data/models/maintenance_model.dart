import 'package:flutter/foundation.dart';

/// Immutable model representing a Traccar Maintenance schedule entity.
///
/// Corresponds to backend contract `org.traccar.model.Maintenance`.
@immutable
class MaintenanceModel {
  /// Unique database primary key identifier.
  final int id;

  /// Human-readable schedule name (e.g. "Ganti Oli Mesin", "Servis Berkala").
  final String name;

  /// Parameter type: 'totalDistance', 'odometer', 'hours', or 'serverTime'/'fixTime'.
  final String type;

  /// Initial baseline value when schedule started (meters, ms, or epoch time).
  final double start;

  /// Interval period value for repeated scheduling (meters, ms, or epoch duration).
  final double period;

  /// Dynamic extensible attributes map (e.g. custom metadata).
  final Map<String, dynamic> attributes;

  const MaintenanceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.start,
    required this.period,
    this.attributes = const {},
  });

  /// True if schedule is distance-based (odometer, totalDistance, serviceOdometer).
  bool get isDistanceBased =>
      type == 'totalDistance' ||
      type == 'odometer' ||
      type == 'serviceOdometer' ||
      type == 'tripOdometer';

  /// True if schedule is engine hours-based ('hours').
  bool get isHoursBased => type == 'hours';

  /// True if schedule is time-based ('serverTime', 'fixTime', 'deviceTime').
  bool get isTimeBased => type.endsWith('Time');

  /// Start value converted from meters to kilometers.
  double get startKm => start / 1000.0;

  /// Period interval converted from meters to kilometers.
  double get periodKm => period / 1000.0;

  /// Start value converted from milliseconds to hours.
  double get startHours => start / 3600000.0;

  /// Period interval converted from milliseconds to hours.
  double get periodHours => period / 3600000.0;

  /// Start value converted from milliseconds to days.
  double get startDays => start / 86400000.0;

  /// Period interval converted from milliseconds to days.
  double get periodDays => period / 86400000.0;

  /// Factory deserializer from Traccar REST JSON map.
  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'totalDistance',
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      period: (json['period'] as num?)?.toDouble() ?? 0.0,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(json['attributes'] as Map)
          : const {},
    );
  }

  /// Serializes model to Traccar REST JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'start': start,
      'period': period,
      'attributes': attributes,
    };
  }

  /// Creates a copy with optionally modified fields.
  MaintenanceModel copyWith({
    int? id,
    String? name,
    String? type,
    double? start,
    double? period,
    Map<String, dynamic>? attributes,
  }) {
    return MaintenanceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      start: start ?? this.start,
      period: period ?? this.period,
      attributes: attributes != null
          ? Map<String, dynamic>.unmodifiable(attributes)
          : this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          start == other.start &&
          period == other.period &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode {
    int attrHash = 0;
    for (final entry in attributes.entries) {
      attrHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(id, name, type, start, period, attrHash);
  }

  @override
  String toString() =>
      'MaintenanceModel(id: $id, name: "$name", type: "$type", start: $start, period: $period)';
}
