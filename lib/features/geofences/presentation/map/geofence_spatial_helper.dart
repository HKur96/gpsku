import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/models/geofence_geometry.dart';

/// Pure mathematical helper for computing spatial centroids, bounding boxes,
/// and camera bounds for geofence geometries.
class GeofenceSpatialHelper {
  const GeofenceSpatialHelper._();

  static const double metersPerLatDegree = 111195.0;

  /// Computes the representative center point ([LatLng]) for [geometry].
  static LatLng calculateCentroid(GeofenceGeometry geometry) {
    switch (geometry) {
      case CircleGeometry circle:
        return circle.center;

      case PolygonGeometry polygon:
        final coords = polygon.coordinates;
        if (coords.isEmpty) {
          throw ArgumentError('Cannot calculate centroid of empty polygon');
        }
        // Exclude duplicate closing vertex if present
        final count = (coords.length > 3 && coords.first == coords.last)
            ? coords.length - 1
            : coords.length;

        double sumLat = 0.0;
        double sumLon = 0.0;
        for (int i = 0; i < count; i++) {
          sumLat += coords[i].latitude;
          sumLon += coords[i].longitude;
        }
        return LatLng(sumLat / count, sumLon / count);

      case PolylineGeometry polyline:
        final coords = polyline.coordinates;
        if (coords.isEmpty) {
          throw ArgumentError('Cannot calculate centroid of empty polyline');
        }
        double sumLat = 0.0;
        double sumLon = 0.0;
        for (final c in coords) {
          sumLat += c.latitude;
          sumLon += c.longitude;
        }
        return LatLng(sumLat / coords.length, sumLon / coords.length);
    }
  }

  /// Computes the bounding envelope ([LatLngBounds]) enclosing [geometry].
  static LatLngBounds calculateBounds(GeofenceGeometry geometry) {
    switch (geometry) {
      case CircleGeometry circle:
        final latRad = circle.center.latitude * math.pi / 180.0;
        final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);

        final deltaLat = circle.radiusMeters / metersPerLatDegree;
        final deltaLon = circle.radiusMeters / (metersPerLatDegree * cosLat);

        final south = (circle.center.latitude - deltaLat).clamp(-90.0, 90.0);
        final north = (circle.center.latitude + deltaLat).clamp(-90.0, 90.0);
        final west = (circle.center.longitude - deltaLon).clamp(-180.0, 180.0);
        final east = (circle.center.longitude + deltaLon).clamp(-180.0, 180.0);

        return LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        );

      case PolygonGeometry polygon:
        final coords = polygon.coordinates;
        if (coords.isEmpty) {
          throw ArgumentError('Cannot calculate bounds of empty polygon');
        }
        return _boundsFromCoordinates(coords);

      case PolylineGeometry polyline:
        final coords = polyline.coordinates;
        if (coords.isEmpty) {
          throw ArgumentError('Cannot calculate bounds of empty polyline');
        }
        // Expand bounds by polyline buffer distance in meters
        final baseBounds = _boundsFromCoordinates(coords);
        final latRad = baseBounds.southwest.latitude * math.pi / 180.0;
        final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);

        final deltaLat = polyline.polylineDistance / metersPerLatDegree;
        final deltaLon =
            polyline.polylineDistance / (metersPerLatDegree * cosLat);

        return LatLngBounds(
          southwest: LatLng(
            (baseBounds.southwest.latitude - deltaLat).clamp(-90.0, 90.0),
            (baseBounds.southwest.longitude - deltaLon).clamp(-180.0, 180.0),
          ),
          northeast: LatLng(
            (baseBounds.northeast.latitude + deltaLat).clamp(-90.0, 90.0),
            (baseBounds.northeast.longitude + deltaLon).clamp(-180.0, 180.0),
          ),
        );
    }
  }

  /// Computes a cumulative [LatLngBounds] enclosing an entire list of [geometries].
  /// Returns `null` if the list is empty.
  static LatLngBounds? calculateCollectionBounds(
    Iterable<GeofenceGeometry> geometries,
  ) {
    if (geometries.isEmpty) return null;

    double? minLat;
    double? maxLat;
    double? minLon;
    double? maxLon;

    for (final geom in geometries) {
      final b = calculateBounds(geom);
      minLat = math.min(minLat ?? b.southwest.latitude, b.southwest.latitude);
      maxLat = math.max(maxLat ?? b.northeast.latitude, b.northeast.latitude);
      minLon = math.min(minLon ?? b.southwest.longitude, b.southwest.longitude);
      maxLon = math.max(maxLon ?? b.northeast.longitude, b.northeast.longitude);
    }

    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  static LatLngBounds _boundsFromCoordinates(List<LatLng> coords) {
    double minLat = coords.first.latitude;
    double maxLat = coords.first.latitude;
    double minLon = coords.first.longitude;
    double maxLon = coords.first.longitude;

    for (int i = 1; i < coords.length; i++) {
      final c = coords[i];
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLon) minLon = c.longitude;
      if (c.longitude > maxLon) maxLon = c.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }
}
