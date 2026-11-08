import 'package:flutter/foundation.dart';

/// Immutable representation of Traccar telematics and system events.
/// Dispatched in real time via WebSocket stream (`/api/socket` with `{"events": [...]}`)
/// or retrieved via `/api/reports/events`.
@immutable
class EventModel {
  final int id;
  final String type;
  final DateTime? eventTime;
  final int deviceId;
  final int positionId;
  final int geofenceId;
  final int maintenanceId;
  final Map<String, dynamic> attributes;

  // Standard Traccar Event Types
  static const String typeAllEvents = 'allEvents';
  static const String typeCommandResult = 'commandResult';
  static const String typeDeviceOnline = 'deviceOnline';
  static const String typeDeviceUnknown = 'deviceUnknown';
  static const String typeDeviceOffline = 'deviceOffline';
  static const String typeDeviceInactive = 'deviceInactive';
  static const String typeQueuedCommandSent = 'queuedCommandSent';
  static const String typeDeviceMoving = 'deviceMoving';
  static const String typeDeviceStopped = 'deviceStopped';
  static const String typeDeviceOverspeed = 'deviceOverspeed';
  static const String typeDeviceFuelDrop = 'deviceFuelDrop';
  static const String typeDeviceFuelIncrease = 'deviceFuelIncrease';
  static const String typeGeofenceEnter = 'geofenceEnter';
  static const String typeGeofenceExit = 'geofenceExit';
  static const String typeGeofenceCrossed = 'geofenceCrossed';
  static const String typeProximityEnter = 'proximityEnter';
  static const String typeProximityExit = 'proximityExit';
  static const String typeUnaccompaniedMotion = 'unaccompaniedMotion';
  static const String typeAlarm = 'alarm';
  static const String typeIgnitionOn = 'ignitionOn';
  static const String typeIgnitionOff = 'ignitionOff';
  static const String typeMaintenance = 'maintenance';
  static const String typeDriverChanged = 'driverChanged';
  static const String typeMedia = 'media';

  // Standard Traccar Alarm Attribute Values
  static const String alarmSos = 'sos';
  static const String alarmOverspeed = 'overspeed';
  static const String alarmVibration = 'vibration';
  static const String alarmPowerCut = 'powerCut';
  static const String alarmPowerRestored = 'powerRestored';
  static const String alarmLowPower = 'lowPower';
  static const String alarmLowBattery = 'lowBattery';
  static const String alarmFault = 'fault';
  static const String alarmGeofence = 'geofence';
  static const String alarmGeofenceEnter = 'geofenceEnter';
  static const String alarmGeofenceExit = 'geofenceExit';
  static const String alarmGpsAntennaCut = 'gpsAntennaCut';
  static const String alarmAccident = 'accident';
  static const String alarmTow = 'tow';
  static const String alarmIdle = 'idle';
  static const String alarmHighRpm = 'highRpm';
  static const String alarmHardAcceleration = 'hardAcceleration';
  static const String alarmHardBraking = 'hardBraking';
  static const String alarmHardCornering = 'hardCornering';
  static const String alarmLaneChange = 'laneChange';
  static const String alarmFatigueDriving = 'fatigueDriving';
  static const String alarmTamper = 'tamper';

  const EventModel({
    required this.id,
    required this.type,
    this.eventTime,
    this.deviceId = 0,
    this.positionId = 0,
    this.geofenceId = 0,
    this.maintenanceId = 0,
    this.attributes = const {},
  });

  /// Factory constructor to parse Traccar event JSON payloads.
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      eventTime: json['eventTime'] != null
          ? DateTime.tryParse(json['eventTime'] as String)
          : null,
      deviceId: (json['deviceId'] as num?)?.toInt() ?? 0,
      positionId: (json['positionId'] as num?)?.toInt() ?? 0,
      geofenceId: (json['geofenceId'] as num?)?.toInt() ?? 0,
      maintenanceId: (json['maintenanceId'] as num?)?.toInt() ?? 0,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(json['attributes'] as Map)
          : const {},
    );
  }

  /// Serializes this event into standard Traccar JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (eventTime != null) 'eventTime': eventTime!.toIso8601String(),
      'deviceId': deviceId,
      'positionId': positionId,
      'geofenceId': geofenceId,
      'maintenanceId': maintenanceId,
      'attributes': attributes,
    };
  }

  EventModel copyWith({
    int? id,
    String? type,
    DateTime? eventTime,
    int? deviceId,
    int? positionId,
    int? geofenceId,
    int? maintenanceId,
    Map<String, dynamic>? attributes,
  }) {
    return EventModel(
      id: id ?? this.id,
      type: type ?? this.type,
      eventTime: eventTime ?? this.eventTime,
      deviceId: deviceId ?? this.deviceId,
      positionId: positionId ?? this.positionId,
      geofenceId: geofenceId ?? this.geofenceId,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      attributes: attributes ?? this.attributes,
    );
  }

  /// True if this is an alarm event (`type == 'alarm'`).
  bool get isAlarm => type == typeAlarm;

  /// Specific alarm subtype stored in attributes, e.g. `'sos'`, `'overspeed'`.
  String? get alarmType => attributes['alarm'] as String?;

  /// True if this is an emergency SOS alert.
  bool get isSos => isAlarm && alarmType?.toLowerCase() == alarmSos;

  /// True if this event indicates overspeed violation.
  bool get isOverspeed =>
      type == typeDeviceOverspeed ||
      (isAlarm && alarmType?.toLowerCase() == alarmOverspeed);

  /// True if this event indicates entering, exiting, or crossing a geofence.
  bool get isGeofence =>
      type == typeGeofenceEnter ||
      type == typeGeofenceExit ||
      type == typeGeofenceCrossed;

  /// True if this event reflects a device connectivity status change.
  bool get isDeviceStatus =>
      type == typeDeviceOnline ||
      type == typeDeviceOffline ||
      type == typeDeviceUnknown ||
      type == typeDeviceInactive;

  /// Optional message payload text (e.g. command response or SMS text).
  String? get message => attributes['message'] as String?;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel &&
        other.id == id &&
        other.type == type &&
        other.eventTime == eventTime &&
        other.deviceId == deviceId &&
        other.positionId == positionId &&
        other.geofenceId == geofenceId &&
        other.maintenanceId == maintenanceId &&
        mapEquals(other.attributes, attributes);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      eventTime,
      deviceId,
      positionId,
      geofenceId,
      maintenanceId,
      Object.hashAllUnordered(
        attributes.entries.map((e) => Object.hash(e.key, e.value)),
      ),
    );
  }

  @override
  String toString() {
    return 'EventModel(id: $id, type: $type, deviceId: $deviceId, '
        'eventTime: $eventTime, alarm: $alarmType)';
  }
}
