import 'package:flutter/foundation.dart';

/// Immutable model representing a Computed Attribute in Traccar (Feature F-38).
/// Maps to Traccar `org.traccar.model.Attribute` entity.
@immutable
class ComputedAttributeModel {
  final int id;
  final String description;
  final String attribute;
  final String expression;
  final String type;
  final int priority;
  final Map<String, dynamic> attributes;

  const ComputedAttributeModel({
    required this.id,
    required this.description,
    required this.attribute,
    required this.expression,
    this.type = 'number',
    this.priority = 0,
    this.attributes = const <String, dynamic>{},
  });

  /// Strictly supported data types in Traccar schema.
  static const List<String> supportedTypes = ['number', 'string', 'boolean'];

  /// Normalizes type to one of 'number', 'string', or 'boolean' (defaulting to 'number').
  static String normalizeType(String? rawType) {
    final lower = (rawType ?? '').trim().toLowerCase();
    if (supportedTypes.contains(lower)) {
      return lower;
    }
    return 'number';
  }

  /// Convenient type checks
  bool get isNumber => type == 'number';
  bool get isString => type == 'string';
  bool get isBoolean => type == 'boolean';

  /// Creates a [ComputedAttributeModel] from JSON returned by Traccar REST API.
  factory ComputedAttributeModel.fromJson(Map<String, dynamic> json) {
    return ComputedAttributeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?)?.trim() ?? '',
      attribute: (json['attribute'] as String?)?.trim() ?? '',
      expression: (json['expression'] as String?)?.trim() ?? '',
      type: normalizeType(json['type'] as String?),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      attributes: json['attributes'] != null && json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(json['attributes'] as Map)
          : const <String, dynamic>{},
    );
  }

  /// Serializes to a JSON map compatible with Traccar REST API.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'description': description,
      'attribute': attribute,
      'expression': expression,
      'type': type,
      'priority': priority,
    };
    if (attributes.isNotEmpty) {
      map['attributes'] = attributes;
    }
    return map;
  }

  /// Returns a copy of this [ComputedAttributeModel] with the specified fields replaced.
  ComputedAttributeModel copyWith({
    int? id,
    String? description,
    String? attribute,
    String? expression,
    String? type,
    int? priority,
    Map<String, dynamic>? attributes,
  }) {
    return ComputedAttributeModel(
      id: id ?? this.id,
      description: description ?? this.description,
      attribute: attribute ?? this.attribute,
      expression: expression ?? this.expression,
      type: type != null ? normalizeType(type) : this.type,
      priority: priority ?? this.priority,
      attributes: attributes != null
          ? Map<String, dynamic>.unmodifiable(attributes)
          : this.attributes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComputedAttributeModel &&
        other.id == id &&
        other.description == description &&
        other.attribute == attribute &&
        other.expression == expression &&
        other.type == type &&
        other.priority == priority &&
        mapEquals(other.attributes, attributes);
  }

  @override
  int get hashCode => Object.hash(
    id,
    description,
    attribute,
    expression,
    type,
    priority,
    Object.hashAll(attributes.entries.map((e) => Object.hash(e.key, e.value))),
  );

  @override
  String toString() {
    return 'ComputedAttributeModel(id: $id, description: "$description", attribute: "$attribute", expression: "$expression", type: "$type", priority: $priority)';
  }
}
