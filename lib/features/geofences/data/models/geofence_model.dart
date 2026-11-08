import 'package:flutter/foundation.dart';
import '../../domain/models/geofence_geometry.dart';
import '../../domain/parsers/wkt_geometry_parser.dart';

/// Immutable model representing a Traccar Geofence entity.
///
/// Corresponds to backend contract `org.traccar.model.Geofence`.
class GeofenceModel {
  /// Unique database primary key identifier.
  final int id;

  /// Human-readable geofence name (e.g. "Gudang Cakung", "Rest Area KM 57").
  final String name;

  /// Optional description or notes for the geofence perimeter.
  final String? description;

  /// Raw Traccar WKT geometry string (e.g. "POLYGON ((...))", "CIRCLE (...)").
  final String area;

  /// Optional Traccar calendar schedule reference ID.
  final int? calendarId;

  /// Extensible key-value attributes (e.g. `color`, `speedLimit`, `polylineDistance`).
  final Map<String, dynamic> attributes;

  const GeofenceModel({
    required this.id,
    required this.name,
    this.description,
    required this.area,
    this.calendarId,
    this.attributes = const {},
  });

  /// Hex color code for map perimeter rendering (e.g. `#1E88E5`, `#E53935`).
  String? get color => attributes['color'] as String?;

  /// Speed limit enforced within this geofence (in knots or km/h).
  double? get speedLimit => (attributes['speedLimit'] as num?)?.toDouble();

  /// Buffer corridor distance in meters for LINESTRING geofences.
  double? get polylineDistance =>
      (attributes['polylineDistance'] as num?)?.toDouble();

  /// Line width in pixels for boundary drawing on the map.
  num? get mapLineWidth =>
      (attributes['mapLineWidth'] as num?) ??
      (attributes['map.lineWidth'] as num?);

  /// Line / fill opacity (0.0 to 1.0).
  double? get mapLineOpacity =>
      (attributes['mapLineOpacity'] as num?)?.toDouble() ??
      (attributes['map.lineOpacity'] as num?)?.toDouble();

  /// Indicates whether this geofence has a POLYGON geometry.
  bool get isPolygon => area.trim().toUpperCase().startsWith('POLYGON');

  /// Indicates whether this geofence has a CIRCLE geometry.
  bool get isCircle => area.trim().toUpperCase().startsWith('CIRCLE');

  /// Indicates whether this geofence has a LINESTRING polyline geometry.
  bool get isPolyline => area.trim().toUpperCase().startsWith('LINESTRING');

  /// Parsed geometric representation. Throws [FormatException] if [area] is malformed.
  GeofenceGeometry get geometry =>
      WktGeometryParser.parse(area, polylineDistance: polylineDistance ?? 25.0);

  /// Safely parsed geometric representation, returning `null` if [area] cannot be parsed.
  GeofenceGeometry? get tryGeometry => WktGeometryParser.tryParse(
    area,
    polylineDistance: polylineDistance ?? 25.0,
  );

  /// Creates a [GeofenceModel] from a JSON map returned by Traccar `/api/geofences`.
  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    return GeofenceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      area: json['area'] as String? ?? '',
      calendarId: (json['calendarId'] as num?)?.toInt(),
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(json['attributes'] as Map),
            )
          : const {},
    );
  }

  /// Serializes this geofence to JSON for Traccar REST API requests (POST / PUT).
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name, 'area': area};
    if (id > 0) {
      map['id'] = id;
    }
    if (description != null) {
      map['description'] = description;
    }
    if (calendarId != null && calendarId! > 0) {
      map['calendarId'] = calendarId;
    }
    if (attributes.isNotEmpty) {
      map['attributes'] = attributes;
    }
    return map;
  }

  /// Creates a copy of this geofence with optional overridden properties.
  GeofenceModel copyWith({
    int? id,
    String? name,
    String? description,
    String? area,
    int? calendarId,
    Map<String, dynamic>? attributes,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      area: area ?? this.area,
      calendarId: calendarId ?? this.calendarId,
      attributes: attributes != null
          ? Map<String, dynamic>.unmodifiable(attributes)
          : this.attributes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceModel &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          area == other.area &&
          calendarId == other.calendarId &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode {
    int attrHash = 0;
    for (final entry in attributes.entries) {
      attrHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(id, name, description, area, calendarId, attrHash);
  }

  @override
  String toString() =>
      'GeofenceModel(id: $id, name: $name, area: ${area.length > 25 ? "${area.substring(0, 22)}..." : area})';
}
