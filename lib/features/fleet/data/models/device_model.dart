import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar Device entity.
@immutable
class DeviceModel {
  final int id;
  final String name;
  final String uniqueId;
  final String status;
  final DateTime? lastUpdate;
  final int? positionId;
  final int? groupId;
  final String? phone;
  final String? model;
  final String? contact;
  final String? category;
  final bool disabled;
  final Map<String, dynamic> attributes;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.uniqueId,
    this.status = 'offline',
    this.lastUpdate,
    this.positionId,
    this.groupId,
    this.phone,
    this.model,
    this.contact,
    this.category,
    this.disabled = false,
    this.attributes = const {},
  });

  bool get isOnline => status.toLowerCase() == 'online';

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      uniqueId: json['uniqueId'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.tryParse(json['lastUpdate'] as String)
          : null,
      positionId: json['positionId'] as int?,
      groupId: json['groupId'] as int?,
      phone: json['phone'] as String?,
      model: json['model'] as String?,
      contact: json['contact'] as String?,
      category: json['category'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uniqueId': uniqueId,
      'status': status,
      if (lastUpdate != null) 'lastUpdate': lastUpdate!.toIso8601String(),
      if (positionId != null) 'positionId': positionId,
      if (groupId != null) 'groupId': groupId,
      if (phone != null) 'phone': phone,
      if (model != null) 'model': model,
      if (contact != null) 'contact': contact,
      if (category != null) 'category': category,
      'disabled': disabled,
      'attributes': attributes,
    };
  }

  DeviceModel copyWith({
    int? id,
    String? name,
    String? uniqueId,
    String? status,
    DateTime? lastUpdate,
    int? positionId,
    int? groupId,
    String? phone,
    String? model,
    String? contact,
    String? category,
    bool? disabled,
    Map<String, dynamic>? attributes,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      uniqueId: uniqueId ?? this.uniqueId,
      status: status ?? this.status,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      positionId: positionId ?? this.positionId,
      groupId: groupId ?? this.groupId,
      phone: phone ?? this.phone,
      model: model ?? this.model,
      contact: contact ?? this.contact,
      category: category ?? this.category,
      disabled: disabled ?? this.disabled,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          uniqueId == other.uniqueId &&
          status == other.status &&
          lastUpdate == other.lastUpdate &&
          positionId == other.positionId &&
          groupId == other.groupId &&
          phone == other.phone &&
          model == other.model &&
          contact == other.contact &&
          category == other.category &&
          disabled == other.disabled &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      uniqueId.hashCode ^
      status.hashCode ^
      lastUpdate.hashCode ^
      positionId.hashCode ^
      groupId.hashCode ^
      phone.hashCode ^
      model.hashCode ^
      contact.hashCode ^
      category.hashCode ^
      disabled.hashCode ^
      attributes.hashCode;

  @override
  String toString() => 'DeviceModel(id: $id, name: $name, status: $status)';
}
