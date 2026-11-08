import 'package:gpsku/core/utils/app_logger.dart';
import '../../data/models/geofence_model.dart';
import '../../domain/models/geofence_geometry.dart';
import '../../domain/parsers/wkt_geometry_parser.dart';

/// Builder translating domain [GeofenceModel] entities into an RFC 7946 GeoJSON
/// FeatureCollection structure for native MapLibre GL ingestion.
class GeofenceGeoJsonBuilder {
  const GeofenceGeoJsonBuilder._();

  /// Default MapLibre style source ID for geofences.
  static const String defaultSourceId = 'geofence-source';

  /// Default MapLibre fill layer ID (semi-transparent interior).
  static const String defaultFillLayerId = 'geofence-fill-layer';

  /// Default MapLibre line layer ID (solid perimeter boundary outline).
  static const String defaultLineLayerId = 'geofence-line-layer';

  /// Default MapLibre symbol layer ID (geofence title text labels).
  static const String defaultSymbolLayerId = 'geofence-symbol-layer';

  /// Fallback color hex when geofence has no defined color attribute.
  static const String fallbackColorHex = '#1E88E5';

  /// Normalizes arbitrary color formats (`#RGB`, `#RRGGBB`, `0xRRGGBB`, `0xAARRGGBB`)
  /// to a standard 6-digit `#RRGGBB` hex string recognized by MapLibre.
  static String normalizeHexColor(
    dynamic rawColor, {
    String fallback = fallbackColorHex,
  }) {
    if (rawColor == null) return fallback;
    String str = rawColor.toString().trim();
    if (str.isEmpty) return fallback;

    if (str.startsWith('0x') || str.startsWith('0X')) {
      str = str.substring(2);
      if (str.length == 8) {
        // 0xAARRGGBB -> #RRGGBB
        str = str.substring(2);
      }
      return '#$str';
    }

    if (str.startsWith('#')) {
      if (str.length == 7) return str;
      if (str.length == 9) {
        // #AARRGGBB -> #RRGGBB
        return '#${str.substring(3)}';
      }
      if (str.length == 4) {
        // #RGB -> #RRGGBB
        final r = str[1];
        final g = str[2];
        final b = str[3];
        return '#$r$r$g$g$b$b';
      }
    } else if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(str)) {
      return '#$str';
    }

    return fallback;
  }

  /// Transforms a list of [GeofenceModel] objects into an RFC 7946 GeoJSON FeatureCollection.
  ///
  /// - Coordinate order: strictly `[longitude, latitude]`.
  /// - Polygons and circles: guaranteed closed ring (`first == last`).
  /// - Malformed geometries: skipped safely with diagnostic warnings.
  static Map<String, dynamic> buildFeatureCollection(
    List<GeofenceModel> geofences,
  ) {
    final features = <Map<String, dynamic>>[];

    for (final geofence in geofences) {
      final geom = geofence.tryGeometry;
      if (geom == null) {
        AppLogger.warn(
          'GeofenceGeoJsonBuilder: Skipping malformed geofence #${geofence.id} (${geofence.name}) with area: ${geofence.area}',
        );
        continue;
      }

      final color = normalizeHexColor(geofence.color);
      final strokeWidth = (geofence.mapLineWidth ?? 2.0).toDouble();
      final fillOpacity = (geofence.mapLineOpacity ?? 0.25).toDouble().clamp(
        0.0,
        1.0,
      );

      final properties = <String, dynamic>{
        'id': geofence.id,
        'name': geofence.name,
        'color': color,
        'strokeColor': color,
        'strokeWidth': strokeWidth,
        'fillOpacity': fillOpacity,
        'area': geofence.area,
        'geomType': geom.typeName,
        if (geofence.speedLimit != null) 'speedLimit': geofence.speedLimit,
      };

      switch (geom) {
        case PolygonGeometry polygon:
          final coords = polygon.coordinates;
          if (coords.length < 3) continue;

          // Convert to [longitude, latitude]
          final ring = coords.map((c) => [c.longitude, c.latitude]).toList();
          // Ensure closed polygon ring
          if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
            ring.add(ring.first);
          }

          features.add({
            'type': 'Feature',
            'id': geofence.id,
            'geometry': {
              'type': 'Polygon',
              'coordinates': [ring],
            },
            'properties': properties,
          });

        case CircleGeometry circle:
          // Approximate circle perimeter as a 64-vertex closed polygon
          final vertices = WktGeometryParser.circleToPolygonApproximation(
            circle.center,
            circle.radiusMeters,
            points: 64,
          );

          final ring = vertices.map((c) => [c.longitude, c.latitude]).toList();

          properties['radiusMeters'] = circle.radiusMeters;

          features.add({
            'type': 'Feature',
            'id': geofence.id,
            'geometry': {
              'type': 'Polygon',
              'coordinates': [ring],
            },
            'properties': properties,
          });

        case PolylineGeometry polyline:
          final coords = polyline.coordinates;
          if (coords.length < 2) continue;

          final lineCoords = coords
              .map((c) => [c.longitude, c.latitude])
              .toList();

          properties['polylineDistance'] = polyline.polylineDistance;
          properties['fillOpacity'] = 0.0; // Polylines have no fill

          features.add({
            'type': 'Feature',
            'id': geofence.id,
            'geometry': {'type': 'LineString', 'coordinates': lineCoords},
            'properties': properties,
          });
      }
    }

    return {'type': 'FeatureCollection', 'features': features};
  }
}
