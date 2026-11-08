import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar Stop Report entity.
/// Corresponds to [org.traccar.reports.model.StopReportItem].
@immutable
class StopReportModel {
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
  final int? positionId;
  final double latitude;
  final double longitude;
  final String? address;
  final int duration; // In milliseconds
  final int engineHours; // In milliseconds

  const StopReportModel({
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
    this.positionId,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.duration,
    required this.engineHours,
  });

  /// Distance converted to kilometers (km).
  double get distanceKm => distance / 1000.0;

  /// Stop duration as a [Duration] object.
  Duration get durationTime => Duration(milliseconds: duration);

  /// Engine hours during stop as a [Duration] object.
  Duration get engineHoursTime => Duration(milliseconds: engineHours);

  /// Safe deserialization from Traccar REST API JSON response.
  factory StopReportModel.fromJson(Map<String, dynamic> json) {
    final rawDistance = _parseDouble(json['distance']);
    final rawAvgSpeed = _parseDouble(json['averageSpeed']);
    final rawMaxSpeed = _parseDouble(json['maxSpeed']);

    return StopReportModel(
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
      positionId: json['positionId'] != null
          ? _parseInt(json['positionId'])
          : null,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      address: json['address'] as String?,
      duration: math.max(0, _parseInt(json['duration'])),
      engineHours: math.max(0, _parseInt(json['engineHours'])),
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
      if (positionId != null) 'positionId': positionId,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      'duration': duration,
      'engineHours': engineHours,
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
      other is StopReportModel &&
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
          positionId == other.positionId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          address == other.address &&
          duration == other.duration &&
          engineHours == other.engineHours;

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
    positionId,
    latitude,
    longitude,
    address,
    duration,
    engineHours,
  ]);
}
