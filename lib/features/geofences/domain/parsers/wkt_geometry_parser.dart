import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/geofence_geometry.dart';

/// Pure Dart geometry conversion and validation engine for Traccar Well-Known Text (WKT).
///
/// Traccar uses a non-standard WKT coordinate ordering dialect:
/// - POLYGON ((lat1 lon1, lat2 lon2, ...))
/// - CIRCLE (latitude longitude, radius_meters)
/// - LINESTRING (lat1 lon1, lat2 lon2, ...)
///
/// This engine validates ranges, parses geometries into typed [GeofenceGeometry] representations,
/// serializes geometries back to Traccar WKT, and provides spherical geodesy polygon approximations
/// for rendering circular perimeters in MapLibre.
class WktGeometryParser {
  const WktGeometryParser._();

  static const double earthRadiusMeters = 6371000.0;

  /// Checks if [lat] and [lon] are valid, finite, in-bounds geographic coordinates.
  static bool isValidCoordinate(double lat, double lon) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) {
      return false;
    }
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  /// Parses a Traccar WKT string into a typed [GeofenceGeometry].
  ///
  /// Throws [FormatException] if the string is empty, unknown, malformed, or contains
  /// invalid coordinates.
  static GeofenceGeometry parse(String wkt, {double polylineDistance = 25.0}) {
    final trimmed = wkt.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('WKT string cannot be empty');
    }

    final upper = trimmed.toUpperCase();

    if (upper.startsWith('CIRCLE')) {
      return _parseCircle(trimmed);
    } else if (upper.startsWith('POLYGON')) {
      return _parsePolygon(trimmed);
    } else if (upper.startsWith('LINESTRING')) {
      return _parseLineString(trimmed, polylineDistance);
    } else {
      throw FormatException('Unsupported or unknown WKT geometry type: $wkt');
    }
  }

  /// Safely parses a Traccar WKT string, returning `null` on any format or numeric failure.
  static GeofenceGeometry? tryParse(
    String? wkt, {
    double polylineDistance = 25.0,
  }) {
    if (wkt == null || wkt.trim().isEmpty) return null;
    try {
      return parse(wkt, polylineDistance: polylineDistance);
    } catch (_) {
      return null;
    }
  }

  /// Serializes a [GeofenceGeometry] to its Traccar WKT string representation.
  static String toWkt(GeofenceGeometry geometry) => geometry.toWkt();

  /// Approximates a spherical circular geofence as a closed polygon ring of [points] vertices.
  ///
  /// Uses exact spherical geodesic trigonometry (great-circle forward destination formula)
  /// to compute equidistant boundary vertices around [center] at [radiusMeters].
  /// Returns [points] + 1 coordinates where the first and last coordinate are identical,
  /// forming a closed polygon ring ready for MapLibre GeoJSON FillLayer rendering.
  static List<LatLng> circleToPolygonApproximation(
    LatLng center,
    double radiusMeters, {
    int points = 64,
  }) {
    if (radiusMeters <= 0 || radiusMeters.isNaN || radiusMeters.isInfinite) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'Radius must be a positive finite number',
      );
    }
    if (points < 4) {
      throw ArgumentError.value(
        points,
        'points',
        'Polygon circle approximation requires at least 4 vertices',
      );
    }

    final double angularDistance = radiusMeters / earthRadiusMeters;
    final double centerLatRad = center.latitude * math.pi / 180.0;
    final double centerLonRad = center.longitude * math.pi / 180.0;

    final List<LatLng> vertices = [];

    for (int i = 0; i <= points; i++) {
      final double bearingRad = (2.0 * math.pi * i) / points;

      final double latRad = math.asin(
        math.sin(centerLatRad) * math.cos(angularDistance) +
            math.cos(centerLatRad) *
                math.sin(angularDistance) *
                math.cos(bearingRad),
      );

      final double lonRad =
          centerLonRad +
          math.atan2(
            math.sin(bearingRad) *
                math.sin(angularDistance) *
                math.cos(centerLatRad),
            math.cos(angularDistance) -
                math.sin(centerLatRad) * math.sin(latRad),
          );

      final double latDeg = latRad * 180.0 / math.pi;
      final double lonDeg =
          ((lonRad * 180.0 / math.pi + 540.0) % 360.0) - 180.0;

      vertices.add(LatLng(latDeg, lonDeg));
    }

    return List.unmodifiable(vertices);
  }

  static CircleGeometry _parseCircle(String wkt) {
    final openIdx = wkt.indexOf('(');
    final closeIdx = wkt.lastIndexOf(')');
    if (openIdx == -1 || closeIdx <= openIdx) {
      throw FormatException('Malformed CIRCLE WKT: missing parentheses: $wkt');
    }

    final content = wkt.substring(openIdx + 1, closeIdx).trim();
    if (content.isEmpty) {
      throw FormatException('Malformed CIRCLE WKT: empty content: $wkt');
    }

    final commaParts = content.split(',');
    if (commaParts.length != 2) {
      throw FormatException(
        'Malformed CIRCLE WKT: expected "lat lon, radius": $wkt',
      );
    }

    final coordTokens = commaParts[0].trim().split(RegExp(r'\s+'));
    if (coordTokens.length != 2) {
      throw FormatException(
        'Malformed CIRCLE WKT: expected 2 coordinates for center: $wkt',
      );
    }

    final lat = double.tryParse(coordTokens[0]);
    final lon = double.tryParse(coordTokens[1]);
    if (lat == null || lon == null || !isValidCoordinate(lat, lon)) {
      throw FormatException(
        'Malformed CIRCLE WKT: invalid center coordinates ($lat, $lon)',
      );
    }

    final radius = double.tryParse(commaParts[1].trim());
    if (radius == null || radius <= 0 || radius.isNaN || radius.isInfinite) {
      throw FormatException(
        'Malformed CIRCLE WKT: invalid radius (${commaParts[1]}): $wkt',
      );
    }

    return CircleGeometry(center: LatLng(lat, lon), radiusMeters: radius);
  }

  static PolygonGeometry _parsePolygon(String wkt) {
    final openIdx = wkt.indexOf('((');
    final closeIdx = wkt.lastIndexOf('))');
    if (openIdx == -1 || closeIdx <= openIdx) {
      throw FormatException(
        'Malformed POLYGON WKT: missing double parentheses (( ... )): $wkt',
      );
    }

    final content = wkt.substring(openIdx + 2, closeIdx).trim();
    if (content.isEmpty) {
      throw FormatException('Malformed POLYGON WKT: empty content: $wkt');
    }

    final commaTokens = content.split(',');
    if (commaTokens.length < 3) {
      throw FormatException(
        'Malformed POLYGON WKT: polygon requires at least 3 vertices, got ${commaTokens.length}',
      );
    }

    final List<LatLng> coords = [];
    for (final rawToken in commaTokens) {
      final tokens = rawToken.trim().split(RegExp(r'\s+'));
      if (tokens.length != 2) {
        throw FormatException(
          'Malformed POLYGON WKT: expected 2 coordinates in vertex "$rawToken"',
        );
      }

      final lat = double.tryParse(tokens[0]);
      final lon = double.tryParse(tokens[1]);
      if (lat == null || lon == null || !isValidCoordinate(lat, lon)) {
        throw FormatException(
          'Malformed POLYGON WKT: invalid coordinates ($lat, $lon)',
        );
      }
      coords.add(LatLng(lat, lon));
    }

    return PolygonGeometry(List.unmodifiable(coords));
  }

  static PolylineGeometry _parseLineString(
    String wkt,
    double polylineDistance,
  ) {
    final openIdx = wkt.indexOf('(');
    final closeIdx = wkt.lastIndexOf(')');
    if (openIdx == -1 || closeIdx <= openIdx) {
      throw FormatException(
        'Malformed LINESTRING WKT: missing parentheses: $wkt',
      );
    }

    final content = wkt.substring(openIdx + 1, closeIdx).trim();
    if (content.isEmpty) {
      throw FormatException('Malformed LINESTRING WKT: empty content: $wkt');
    }

    final commaTokens = content.split(',');
    if (commaTokens.length < 2) {
      throw FormatException(
        'Malformed LINESTRING WKT: linestring requires at least 2 vertices, got ${commaTokens.length}',
      );
    }

    final List<LatLng> coords = [];
    for (final rawToken in commaTokens) {
      final tokens = rawToken.trim().split(RegExp(r'\s+'));
      if (tokens.length != 2) {
        throw FormatException(
          'Malformed LINESTRING WKT: expected 2 coordinates in vertex "$rawToken"',
        );
      }

      final lat = double.tryParse(tokens[0]);
      final lon = double.tryParse(tokens[1]);
      if (lat == null || lon == null || !isValidCoordinate(lat, lon)) {
        throw FormatException(
          'Malformed LINESTRING WKT: invalid coordinates ($lat, $lon)',
        );
      }
      coords.add(LatLng(lat, lon));
    }

    return PolylineGeometry(
      List.unmodifiable(coords),
      polylineDistance: polylineDistance,
    );
  }
}
