import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar Position entity.
@immutable
class PositionModel {
  final int id;
  final int deviceId;
  final String? protocol;
  final DateTime serverTime;
  final DateTime? deviceTime;
  final DateTime fixTime;
  final bool outdated;
  final bool valid;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed; // Value in knots from Traccar
  final double course;
  final String? address;
  final double? accuracy;
  final List<int> geofenceIds;
  final Map<String, dynamic> attributes;

  const PositionModel({
    required this.id,
    required this.deviceId,
    this.protocol,
    required this.serverTime,
    this.deviceTime,
    required this.fixTime,
    this.outdated = false,
    this.valid = true,
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.course = 0.0,
    this.address,
    this.accuracy,
    this.geofenceIds = const [],
    this.attributes = const {},
  });

  /// Speed converted to kilometers per hour (km/h).
  /// 1 knot = 1.852 km/h.
  double get speedKmh => speed * 1.852;

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    return PositionModel(
      id: json['id'] as int? ?? 0,
      deviceId: json['deviceId'] as int? ?? 0,
      protocol: json['protocol'] as String?,
      serverTime: json['serverTime'] != null
          ? DateTime.parse(json['serverTime'] as String)
          : DateTime.now(),
      deviceTime: json['deviceTime'] != null
          ? DateTime.tryParse(json['deviceTime'] as String)
          : null,
      fixTime: json['fixTime'] != null
          ? DateTime.parse(json['fixTime'] as String)
          : DateTime.now(),
      outdated: json['outdated'] as bool? ?? false,
      valid: json['valid'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      geofenceIds: json['geofenceIds'] is List
          ? (json['geofenceIds'] as List)
                .map((e) => (e as num).toInt())
                .toList()
          : const [],
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      if (protocol != null) 'protocol': protocol,
      'serverTime': serverTime.toIso8601String(),
      if (deviceTime != null) 'deviceTime': deviceTime!.toIso8601String(),
      'fixTime': fixTime.toIso8601String(),
      'outdated': outdated,
      'valid': valid,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'course': course,
      if (address != null) 'address': address,
      if (accuracy != null) 'accuracy': accuracy,
      'geofenceIds': geofenceIds,
      'attributes': attributes,
    };
  }

  PositionModel copyWith({
    int? id,
    int? deviceId,
    String? protocol,
    DateTime? serverTime,
    DateTime? deviceTime,
    DateTime? fixTime,
    bool? outdated,
    bool? valid,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? course,
    String? address,
    double? accuracy,
    List<int>? geofenceIds,
    Map<String, dynamic>? attributes,
  }) {
    return PositionModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      protocol: protocol ?? this.protocol,
      serverTime: serverTime ?? this.serverTime,
      deviceTime: deviceTime ?? this.deviceTime,
      fixTime: fixTime ?? this.fixTime,
      outdated: outdated ?? this.outdated,
      valid: valid ?? this.valid,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      course: course ?? this.course,
      address: address ?? this.address,
      accuracy: accuracy ?? this.accuracy,
      geofenceIds: geofenceIds ?? this.geofenceIds,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceId == other.deviceId &&
          protocol == other.protocol &&
          serverTime == other.serverTime &&
          deviceTime == other.deviceTime &&
          fixTime == other.fixTime &&
          outdated == other.outdated &&
          valid == other.valid &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude &&
          speed == other.speed &&
          course == other.course &&
          address == other.address &&
          accuracy == other.accuracy &&
          listEquals(geofenceIds, other.geofenceIds) &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode =>
      id.hashCode ^
      deviceId.hashCode ^
      protocol.hashCode ^
      serverTime.hashCode ^
      deviceTime.hashCode ^
      fixTime.hashCode ^
      outdated.hashCode ^
      valid.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      altitude.hashCode ^
      speed.hashCode ^
      course.hashCode ^
      address.hashCode ^
      accuracy.hashCode ^
      geofenceIds.hashCode ^
      attributes.hashCode;

  @override
  String toString() =>
      'PositionModel(id: $id, deviceId: $deviceId, fixTime: $fixTime, lat: $latitude, lng: $longitude)';
}
