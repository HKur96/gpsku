import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar Trip Report entity.
/// Corresponds to [org.traccar.reports.model.TripReportItem].
@immutable
class TripReportModel {
  final int deviceId;
  final String? deviceName;
  final double distance; // In meters
  final double averageSpeed; // In knots
  final double maxSpeed; // In knots
  final double? spentFuel;
  final double? startOdometer;
  final double? endOdometer;
  final DateTime startTime;
  final DateTime endTime;
  final bool business;
  final int? startPositionId;
  final int? endPositionId;
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;
  final String? startAddress;
  final String? endAddress;
  final int duration; // In milliseconds
  final String? driverUniqueId;
  final String? driverName;

  const TripReportModel({
    required this.deviceId,
    this.deviceName,
    required this.distance,
    required this.averageSpeed,
    required this.maxSpeed,
    this.spentFuel,
    this.startOdometer,
    this.endOdometer,
    required this.startTime,
    required this.endTime,
    this.business = false,
    this.startPositionId,
    this.endPositionId,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
    this.startAddress,
    this.endAddress,
    required this.duration,
    this.driverUniqueId,
    this.driverName,
  });

  /// Average speed converted to kilometers per hour (km/h).
  /// 1 knot = 1.852 km/h.
  double get speedKmh => averageSpeed * 1.852;

  /// Maximum speed converted to kilometers per hour (km/h).
  double get maxSpeedKmh => maxSpeed * 1.852;

  /// Distance converted to kilometers (km).
  double get distanceKm => distance / 1000.0;

  /// Trip duration as a [Duration] object.
  Duration get durationTime => Duration(milliseconds: duration);

  /// Safe deserialization from Traccar REST API JSON response.
  factory TripReportModel.fromJson(Map<String, dynamic> json) {
    final rawAvgSpeed = _parseDouble(json['averageSpeed']);
    final rawMaxSpeed = _parseDouble(json['maxSpeed']);
    final rawDistance = _parseDouble(json['distance']);

    return TripReportModel(
      deviceId: _parseInt(json['deviceId']),
      deviceName: json['deviceName'] as String?,
      distance: math.max(0.0, rawDistance),
      averageSpeed: math.max(0.0, rawAvgSpeed),
      maxSpeed: math.max(0.0, rawMaxSpeed),
      spentFuel: json['spentFuel'] != null
          ? _parseDouble(json['spentFuel'])
          : null,
      startOdometer: json['startOdometer'] != null
          ? _parseDouble(json['startOdometer'])
          : null,
      endOdometer: json['endOdometer'] != null
          ? _parseDouble(json['endOdometer'])
          : null,
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
      business: json['business'] as bool? ?? false,
      startPositionId: json['startPositionId'] != null
          ? _parseInt(json['startPositionId'])
          : null,
      endPositionId: json['endPositionId'] != null
          ? _parseInt(json['endPositionId'])
          : null,
      startLat: json['startLat'] != null
          ? _parseDouble(json['startLat'])
          : null,
      startLon: json['startLon'] != null
          ? _parseDouble(json['startLon'])
          : null,
      endLat: json['endLat'] != null ? _parseDouble(json['endLat']) : null,
      endLon: json['endLon'] != null ? _parseDouble(json['endLon']) : null,
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      duration: math.max(0, _parseInt(json['duration'])),
      driverUniqueId: json['driverUniqueId'] as String?,
      driverName: json['driverName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      if (deviceName != null) 'deviceName': deviceName,
      'distance': distance,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      if (spentFuel != null) 'spentFuel': spentFuel,
      if (startOdometer != null) 'startOdometer': startOdometer,
      if (endOdometer != null) 'endOdometer': endOdometer,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'business': business,
      if (startPositionId != null) 'startPositionId': startPositionId,
      if (endPositionId != null) 'endPositionId': endPositionId,
      if (startLat != null) 'startLat': startLat,
      if (startLon != null) 'startLon': startLon,
      if (endLat != null) 'endLat': endLat,
      if (endLon != null) 'endLon': endLon,
      if (startAddress != null) 'startAddress': startAddress,
      if (endAddress != null) 'endAddress': endAddress,
      'duration': duration,
      if (driverUniqueId != null) 'driverUniqueId': driverUniqueId,
      if (driverName != null) 'driverName': driverName,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripReportModel &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          distance == other.distance &&
          averageSpeed == other.averageSpeed &&
          maxSpeed == other.maxSpeed &&
          spentFuel == other.spentFuel &&
          startOdometer == other.startOdometer &&
          endOdometer == other.endOdometer &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          business == other.business &&
          startPositionId == other.startPositionId &&
          endPositionId == other.endPositionId &&
          startLat == other.startLat &&
          startLon == other.startLon &&
          endLat == other.endLat &&
          endLon == other.endLon &&
          startAddress == other.startAddress &&
          endAddress == other.endAddress &&
          duration == other.duration &&
          driverUniqueId == other.driverUniqueId &&
          driverName == other.driverName;

  @override
  int get hashCode => Object.hashAll([
    deviceId,
    deviceName,
    distance,
    averageSpeed,
    maxSpeed,
    spentFuel,
    startOdometer,
    endOdometer,
    startTime,
    endTime,
    business,
    startPositionId,
    endPositionId,
    startLat,
    startLon,
    endLat,
    endLon,
    startAddress,
    endAddress,
    duration,
  ]);
}
