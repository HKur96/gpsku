import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar Group entity.
///
/// Maps to Traccar backend schema (`tc_groups` table / GroupResource):
/// - [id]: Unique group database PK.
/// - [name]: Human-readable group or branch name.
/// - [groupId]: Parent group identifier for nested hierarchies (0 or null if root group).
/// - [attributes]: Arbitrary custom extension attributes.
@immutable
class GroupModel {
  final int id;
  final String name;
  final int? groupId;
  final Map<String, dynamic> attributes;

  const GroupModel({
    required this.id,
    required this.name,
    this.groupId,
    this.attributes = const {},
  });

  /// True if this group is a root-level division (no parent group).
  bool get isRoot => groupId == null || groupId == 0;

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    final rawGroupId = json['groupId'];
    int? parsedGroupId;
    if (rawGroupId is num) {
      final val = rawGroupId.toInt();
      parsedGroupId = val > 0 ? val : null;
    }

    return GroupModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      groupId: parsedGroupId,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (groupId != null) 'groupId': groupId,
      'attributes': attributes,
    };
  }

  GroupModel copyWith({
    int? id,
    String? name,
    int? groupId,
    Map<String, dynamic>? attributes,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          groupId == other.groupId &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    groupId,
    Object.hashAll(attributes.entries.map((e) => Object.hash(e.key, e.value))),
  );

  @override
  String toString() =>
      'GroupModel(id: $id, name: $name, groupId: $groupId, attributes: $attributes)';
}
