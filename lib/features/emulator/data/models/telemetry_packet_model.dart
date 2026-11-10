import 'package:flutter/foundation.dart';

/// Immutable Data Transfer Object representing simulated GPS telemetry
/// ready for transmission to Traccar's OsmAnd protocol decoder (port 5055).
@immutable
class TelemetryPacketModel {
  /// Unique identifier of the target vehicle/device (corresponds to `device.uniqueId`).
  final String id;

  /// Latitude coordinate in decimal degrees (-90.0 to 90.0).
  final double lat;

  /// Longitude coordinate in decimal degrees (-180.0 to 180.0).
  final double lon;

  /// Timestamp of the simulated position fix.
  final DateTime timestamp;

  /// Speed in knots (Traccar OsmAnd default unit).
  final double? speed;

  /// Course / heading / bearing in degrees (0.0 to 360.0).
  final double? bearing;

  /// Altitude in meters above sea level.
  final double? altitude;

  /// Battery level percentage (0.0 to 100.0, mapped to `batt` in OsmAnd).
  final double? battery;

  /// Horizontal accuracy in meters.
  final double? accuracy;

  /// Horizontal Dilution of Precision.
  final double? hdop;

  /// Whether the device is currently charging.
  final bool? charge;

  /// RFID or iButton identifier of the currently active driver.
  final String? driverUniqueId;

  /// GPS fix validity flag.
  final bool? valid;

  /// Custom telemetry attributes (e.g. `ignition`, `temp`, `fuel`).
  final Map<String, dynamic> attributes;

  TelemetryPacketModel({
    required this.id,
    required this.lat,
    required this.lon,
    DateTime? timestamp,
    this.speed,
    this.bearing,
    this.altitude,
    this.battery,
    this.accuracy,
    this.hdop,
    this.charge,
    this.driverUniqueId,
    this.valid = true,
    Map<String, dynamic>? attributes,
  }) : timestamp = timestamp ?? DateTime.now(),
       attributes = Map.unmodifiable(attributes ?? const {});

  /// Alias for [id] matching domain vocabulary.
  String get uniqueId => id;

  /// Epoch timestamp in seconds (as expected by OsmAnd `timestamp` param).
  int get epochSeconds => timestamp.millisecondsSinceEpoch ~/ 1000;

  /// Speed converted to kilometers per hour (km/h) for display.
  double? get speedKmh => speed != null ? speed! * 1.852 : null;

  /// Helper converting km/h to knots (Traccar OsmAnd default speed unit).
  static double kmhToKnots(double kmh) => kmh * 0.539957;

  /// Helper converting knots to km/h.
  static double knotsToKmh(double knots) => knots * 1.852;

  /// Serializes the packet into key-value query parameters conforming to
  /// Traccar `OsmAndProtocolDecoder` specifications.
  Map<String, String> toOsmAndParams() {
    final params = <String, String>{
      'id': id,
      'lat': lat.toString(),
      'lon': lon.toString(),
      'timestamp': epochSeconds.toString(),
    };

    if (speed != null) params['speed'] = speed.toString();
    if (bearing != null) params['bearing'] = bearing.toString();
    if (altitude != null) params['altitude'] = altitude.toString();
    if (battery != null) params['batt'] = battery.toString();
    if (accuracy != null) params['accuracy'] = accuracy.toString();
    if (hdop != null) params['hdop'] = hdop.toString();
    if (charge != null) params['charge'] = charge.toString();
    if (driverUniqueId != null && driverUniqueId!.isNotEmpty) {
      params['driverUniqueId'] = driverUniqueId!;
    }
    if (valid != null) params['valid'] = valid.toString();

    attributes.forEach((key, value) {
      if (value != null) {
        params[key] = value.toString();
      }
    });

    return Map.unmodifiable(params);
  }

  /// Encodes parameters into standard URL query string.
  String toQueryString() {
    return Uri(queryParameters: toOsmAndParams()).query;
  }

  /// Constructs target [Uri] pointing to the OsmAnd port.
  /// Defaults to plain 'http' scheme unless [scheme] is explicitly specified.
  Uri toUri(
    String baseUrl, {
    int port = 5055,
    String path = '/',
    String scheme = 'http',
  }) {
    final base = Uri.parse(baseUrl);
    return Uri(
      scheme: scheme,
      host: base.host.isEmpty ? baseUrl : base.host,
      port: port,
      path: path,
      queryParameters: toOsmAndParams(),
    );
  }

  /// Creates a copy with optionally updated fields.
  TelemetryPacketModel copyWith({
    String? id,
    double? lat,
    double? lon,
    DateTime? timestamp,
    double? speed,
    double? bearing,
    double? altitude,
    double? battery,
    double? accuracy,
    double? hdop,
    bool? charge,
    String? driverUniqueId,
    bool? valid,
    Map<String, dynamic>? attributes,
  }) {
    return TelemetryPacketModel(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      bearing: bearing ?? this.bearing,
      altitude: altitude ?? this.altitude,
      battery: battery ?? this.battery,
      accuracy: accuracy ?? this.accuracy,
      hdop: hdop ?? this.hdop,
      charge: charge ?? this.charge,
      driverUniqueId: driverUniqueId ?? this.driverUniqueId,
      valid: valid ?? this.valid,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Deserializes a [TelemetryPacketModel] from JSON representation.
  factory TelemetryPacketModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    final rawTime = json['timestamp'] ?? json['time'] ?? json['fixTime'];
    if (rawTime is int) {
      parsedTimestamp = rawTime < 2147483647
          ? DateTime.fromMillisecondsSinceEpoch(rawTime * 1000, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(rawTime, isUtc: true);
    } else if (rawTime is String) {
      parsedTimestamp = DateTime.tryParse(rawTime) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    final rawAttrs = json['attributes'];
    Map<String, dynamic>? customAttrs;
    if (rawAttrs is Map<String, dynamic>) {
      customAttrs = rawAttrs;
    } else if (rawAttrs is Map) {
      customAttrs = Map<String, dynamic>.from(rawAttrs);
    }

    return TelemetryPacketModel(
      id: (json['id'] ?? json['uniqueId'] ?? json['deviceId'] ?? '').toString(),
      lat: (json['lat'] ?? json['latitude'] ?? 0.0 as num).toDouble(),
      lon: (json['lon'] ?? json['longitude'] ?? 0.0 as num).toDouble(),
      timestamp: parsedTimestamp,
      speed: (json['speed'] as num?)?.toDouble(),
      bearing: (json['bearing'] ?? json['course'] ?? json['heading'] as num?)
          ?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      battery: (json['battery'] ?? json['batt'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      hdop: (json['hdop'] as num?)?.toDouble(),
      charge: json['charge'] is bool
          ? json['charge'] as bool
          : (json['charge'] != null
                ? json['charge'].toString().toLowerCase() == 'true'
                : null),
      driverUniqueId: json['driverUniqueId']?.toString(),
      valid: json['valid'] is bool
          ? json['valid'] as bool
          : (json['valid'] != null
                ? json['valid'].toString().toLowerCase() != 'false' &&
                      json['valid'].toString() != '0'
                : true),
      attributes: customAttrs,
    );
  }

  /// Serializes to standard JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp.toIso8601String(),
      if (speed != null) 'speed': speed,
      if (bearing != null) 'bearing': bearing,
      if (altitude != null) 'altitude': altitude,
      if (battery != null) 'battery': battery,
      if (accuracy != null) 'accuracy': accuracy,
      if (hdop != null) 'hdop': hdop,
      if (charge != null) 'charge': charge,
      if (driverUniqueId != null) 'driverUniqueId': driverUniqueId,
      if (valid != null) 'valid': valid,
      'attributes': attributes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TelemetryPacketModel &&
        other.id == id &&
        other.lat == lat &&
        other.lon == lon &&
        other.timestamp == timestamp &&
        other.speed == speed &&
        other.bearing == bearing &&
        other.altitude == altitude &&
        other.battery == battery &&
        other.accuracy == accuracy &&
        other.hdop == hdop &&
        other.charge == charge &&
        other.driverUniqueId == driverUniqueId &&
        other.valid == valid &&
        mapEquals(other.attributes, attributes);
  }

  @override
  int get hashCode {
    int attrsHash = 0;
    for (final entry in attributes.entries) {
      attrsHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      lat,
      lon,
      timestamp,
      speed,
      bearing,
      altitude,
      battery,
      accuracy,
      hdop,
      charge,
      driverUniqueId,
      valid,
      attrsHash,
    );
  }

  @override
  String toString() {
    return 'TelemetryPacketModel(id: $id, lat: $lat, lon: $lon, time: $timestamp, speed: $speed, bearing: $bearing)';
  }
}
