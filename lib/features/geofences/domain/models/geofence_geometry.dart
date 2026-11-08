import 'package:maplibre_gl/maplibre_gl.dart';

/// Formats a geographic coordinate to remove binary floating-point representation artifacts
/// (such as 106.80000000000001 or 106.84559999999999 from LatLng modulo arithmetic).
String formatGeographicCoordinate(double val) {
  final rounded = (val * 1e7).round() / 1e7;
  if (rounded % 1 == 0) return rounded.toInt().toString();
  return rounded.toString().replaceAll(RegExp(r'\.?0+$'), '');
}

/// Sealed domain model representing parsed geometric perimeter structures
/// for Traccar Geofences.
///
/// Traccar uses a specialized Well-Known Text (WKT) dialect:
/// - POLYGON ((latitude longitude, ...))
/// - CIRCLE (latitude longitude, radius_meters)
/// - LINESTRING (latitude longitude, ...)
sealed class GeofenceGeometry {
  const GeofenceGeometry();

  /// Geometry type identifier ('POLYGON', 'CIRCLE', 'LINESTRING').
  String get typeName;

  /// Serializes geometry back to Traccar-compliant WKT format.
  String toWkt();
}

/// Polygon geofence geometry with an ordered list of boundary vertices.
class PolygonGeometry extends GeofenceGeometry {
  /// Ordered list of vertex coordinates in [LatLng] (latitude, longitude).
  final List<LatLng> coordinates;

  const PolygonGeometry(this.coordinates);

  @override
  String get typeName => 'POLYGON';

  @override
  String toWkt() {
    final coordsStr = coordinates
        .map(
          (c) =>
              '${formatGeographicCoordinate(c.latitude)} ${formatGeographicCoordinate(c.longitude)}',
        )
        .join(', ');
    return 'POLYGON (($coordsStr))';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PolygonGeometry) return false;
    if (coordinates.length != other.coordinates.length) return false;
    for (int i = 0; i < coordinates.length; i++) {
      if ((coordinates[i].latitude - other.coordinates[i].latitude).abs() >
              1e-6 ||
          (coordinates[i].longitude - other.coordinates[i].longitude).abs() >
              1e-6) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
    coordinates.map(
      (c) =>
          Object.hash((c.latitude * 1e6).round(), (c.longitude * 1e6).round()),
    ),
  );

  @override
  String toString() => 'PolygonGeometry(vertices: ${coordinates.length})';
}

/// Circular geofence geometry centered at [center] with radius [radiusMeters].
class CircleGeometry extends GeofenceGeometry {
  /// Center coordinate of the circle in [LatLng] (latitude, longitude).
  final LatLng center;

  /// Radius in meters.
  final double radiusMeters;

  const CircleGeometry({required this.center, required this.radiusMeters});

  @override
  String get typeName => 'CIRCLE';

  @override
  String toWkt() {
    final radiusStr = (radiusMeters % 1 == 0)
        ? radiusMeters.toInt().toString()
        : radiusMeters.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return 'CIRCLE (${formatGeographicCoordinate(center.latitude)} ${formatGeographicCoordinate(center.longitude)}, $radiusStr)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleGeometry &&
          (center.latitude - other.center.latitude).abs() <= 1e-6 &&
          (center.longitude - other.center.longitude).abs() <= 1e-6 &&
          radiusMeters == other.radiusMeters;

  @override
  int get hashCode => Object.hash(
    (center.latitude * 1e6).round(),
    (center.longitude * 1e6).round(),
    radiusMeters,
  );

  @override
  String toString() =>
      'CircleGeometry(center: (${center.latitude}, ${center.longitude}), radius: ${radiusMeters}m)';
}

/// Polyline corridor geofence geometry with an ordered list of vertices
/// and a corridor buffer distance [polylineDistance] in meters.
class PolylineGeometry extends GeofenceGeometry {
  /// Ordered list of corridor waypoint coordinates in [LatLng].
  final List<LatLng> coordinates;

  /// Corridor buffer distance in meters (defaults to 25.0).
  final double polylineDistance;

  const PolylineGeometry(this.coordinates, {this.polylineDistance = 25.0});

  @override
  String get typeName => 'LINESTRING';

  @override
  String toWkt() {
    final coordsStr = coordinates
        .map(
          (c) =>
              '${formatGeographicCoordinate(c.latitude)} ${formatGeographicCoordinate(c.longitude)}',
        )
        .join(', ');
    return 'LINESTRING ($coordsStr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PolylineGeometry) return false;
    if (polylineDistance != other.polylineDistance) return false;
    if (coordinates.length != other.coordinates.length) return false;
    for (int i = 0; i < coordinates.length; i++) {
      if ((coordinates[i].latitude - other.coordinates[i].latitude).abs() >
              1e-6 ||
          (coordinates[i].longitude - other.coordinates[i].longitude).abs() >
              1e-6) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    polylineDistance,
    Object.hashAll(
      coordinates.map(
        (c) => Object.hash(
          (c.latitude * 1e6).round(),
          (c.longitude * 1e6).round(),
        ),
      ),
    ),
  );

  @override
  String toString() =>
      'PolylineGeometry(points: ${coordinates.length}, distance: ${polylineDistance}m)';
}
