import 'package:flutter/foundation.dart';

/// Immutable model representing a Driver in the Traccar system.
/// Maps to the Traccar `org.traccar.model.Driver` entity.
@immutable
class DriverModel {
  final int id;
  final String name;
  final String uniqueId;
  final Map<String, dynamic> attributes;

  const DriverModel({
    required this.id,
    required this.name,
    required this.uniqueId,
    this.attributes = const <String, dynamic>{},
  });

  /// Optional telephone contact from attributes.
  String? get phone => attributes['phone']?.toString();

  /// Optional driver contact information from attributes.
  String? get contact => attributes['contact']?.toString();

  /// Optional driver's license number from attributes (checks 'license' and 'driverLicense').
  String? get license =>
      attributes['license']?.toString() ??
      attributes['driverLicense']?.toString();

  /// Creates a [DriverModel] from a JSON map returned by the Traccar API.
  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      uniqueId: (json['uniqueId'] as String?)?.trim() ?? '',
      attributes: json['attributes'] != null && json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(json['attributes'] as Map)
          : const <String, dynamic>{},
    );
  }

  /// Serializes this [DriverModel] to a JSON map compatible with the Traccar API.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'id': id, 'name': name, 'uniqueId': uniqueId};
    if (attributes.isNotEmpty) {
      map['attributes'] = attributes;
    }
    return map;
  }

  /// Returns a copy of this [DriverModel] with the specified fields replaced.
  DriverModel copyWith({
    int? id,
    String? name,
    String? uniqueId,
    Map<String, dynamic>? attributes,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      uniqueId: uniqueId ?? this.uniqueId,
      attributes: attributes != null
          ? Map<String, dynamic>.unmodifiable(attributes)
          : this.attributes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriverModel) return false;
    if (id != other.id || name != other.name || uniqueId != other.uniqueId) {
      return false;
    }
    if (attributes.length != other.attributes.length) return false;
    for (final key in attributes.keys) {
      if (!other.attributes.containsKey(key) ||
          attributes[key] != other.attributes[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    int attrHash = 0;
    for (final entry in attributes.entries) {
      attrHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(id, name, uniqueId, attrHash);
  }

  @override
  String toString() {
    return 'DriverModel(id: $id, name: "$name", uniqueId: "$uniqueId", attributes: $attributes)';
  }
}
