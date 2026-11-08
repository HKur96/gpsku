import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar User entity.
@immutable
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? login;
  final String? phone;
  final bool readonly;
  final bool administrator;
  final String? map;
  final double? latitude;
  final double? longitude;
  final int? zoom;
  final String? coordinateFormat;
  final bool disabled;
  final DateTime? expirationTime;
  final int? deviceLimit;
  final int? userLimit;
  final bool deviceReadonly;
  final bool limitCommands;
  final bool disableReports;
  final bool fixedEmail;
  final String? poiLayer;
  final Map<String, dynamic> attributes;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.login,
    this.phone,
    this.readonly = false,
    this.administrator = false,
    this.map,
    this.latitude,
    this.longitude,
    this.zoom,
    this.coordinateFormat,
    this.disabled = false,
    this.expirationTime,
    this.deviceLimit,
    this.userLimit,
    this.deviceReadonly = false,
    this.limitCommands = false,
    this.disableReports = false,
    this.fixedEmail = false,
    this.poiLayer,
    this.attributes = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      login: json['login'] as String?,
      phone: json['phone'] as String?,
      readonly: json['readonly'] as bool? ?? false,
      administrator: json['administrator'] as bool? ?? false,
      map: json['map'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      zoom: json['zoom'] as int?,
      coordinateFormat: json['coordinateFormat'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      expirationTime: json['expirationTime'] != null
          ? DateTime.tryParse(json['expirationTime'] as String)
          : null,
      deviceLimit: json['deviceLimit'] as int?,
      userLimit: json['userLimit'] as int?,
      deviceReadonly: json['deviceReadonly'] as bool? ?? false,
      limitCommands: json['limitCommands'] as bool? ?? false,
      disableReports: json['disableReports'] as bool? ?? false,
      fixedEmail: json['fixedEmail'] as bool? ?? false,
      poiLayer: json['poiLayer'] as String?,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (login != null) 'login': login,
      if (phone != null) 'phone': phone,
      'readonly': readonly,
      'administrator': administrator,
      if (map != null) 'map': map,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (zoom != null) 'zoom': zoom,
      if (coordinateFormat != null) 'coordinateFormat': coordinateFormat,
      'disabled': disabled,
      if (expirationTime != null)
        'expirationTime': expirationTime!.toIso8601String(),
      if (deviceLimit != null) 'deviceLimit': deviceLimit,
      if (userLimit != null) 'userLimit': userLimit,
      'deviceReadonly': deviceReadonly,
      'limitCommands': limitCommands,
      'disableReports': disableReports,
      'fixedEmail': fixedEmail,
      if (poiLayer != null) 'poiLayer': poiLayer,
      'attributes': attributes,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? login,
    String? phone,
    bool? readonly,
    bool? administrator,
    String? map,
    double? latitude,
    double? longitude,
    int? zoom,
    String? coordinateFormat,
    bool? disabled,
    DateTime? expirationTime,
    int? deviceLimit,
    int? userLimit,
    bool? deviceReadonly,
    bool? limitCommands,
    bool? disableReports,
    bool? fixedEmail,
    String? poiLayer,
    Map<String, dynamic>? attributes,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      login: login ?? this.login,
      phone: phone ?? this.phone,
      readonly: readonly ?? this.readonly,
      administrator: administrator ?? this.administrator,
      map: map ?? this.map,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      coordinateFormat: coordinateFormat ?? this.coordinateFormat,
      disabled: disabled ?? this.disabled,
      expirationTime: expirationTime ?? this.expirationTime,
      deviceLimit: deviceLimit ?? this.deviceLimit,
      userLimit: userLimit ?? this.userLimit,
      deviceReadonly: deviceReadonly ?? this.deviceReadonly,
      limitCommands: limitCommands ?? this.limitCommands,
      disableReports: disableReports ?? this.disableReports,
      fixedEmail: fixedEmail ?? this.fixedEmail,
      poiLayer: poiLayer ?? this.poiLayer,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          login == other.login &&
          phone == other.phone &&
          readonly == other.readonly &&
          administrator == other.administrator &&
          map == other.map &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          zoom == other.zoom &&
          coordinateFormat == other.coordinateFormat &&
          disabled == other.disabled &&
          expirationTime == other.expirationTime &&
          deviceLimit == other.deviceLimit &&
          userLimit == other.userLimit &&
          deviceReadonly == other.deviceReadonly &&
          limitCommands == other.limitCommands &&
          disableReports == other.disableReports &&
          fixedEmail == other.fixedEmail &&
          poiLayer == other.poiLayer &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      login.hashCode ^
      phone.hashCode ^
      readonly.hashCode ^
      administrator.hashCode ^
      map.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      zoom.hashCode ^
      coordinateFormat.hashCode ^
      disabled.hashCode ^
      expirationTime.hashCode ^
      deviceLimit.hashCode ^
      userLimit.hashCode ^
      deviceReadonly.hashCode ^
      limitCommands.hashCode ^
      disableReports.hashCode ^
      fixedEmail.hashCode ^
      poiLayer.hashCode ^
      attributes.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, admin: $administrator)';
}
