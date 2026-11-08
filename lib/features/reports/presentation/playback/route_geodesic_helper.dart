import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Pure mathematical engine for geographic calculations, geodesic distance,
/// forward bearing azimuth, and smooth intermediate coordinate/angle interpolations.
class RouteGeodesicHelper {
  const RouteGeodesicHelper._();

  static const double earthRadiusMeters = 6371000.0;

  /// Computes the great-circle geodesic distance in meters between [a] and [b]
  /// using the Haversine formula.
  static double distanceBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lon1 = a.longitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final lon2 = b.longitude * math.pi / 180.0;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final sinHalfDLat = math.sin(dLat / 2.0);
    final sinHalfDLon = math.sin(dLon / 2.0);

    final h =
        sinHalfDLat * sinHalfDLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfDLon * sinHalfDLon;

    final c = 2.0 * math.asin(math.sqrt(math.min(1.0, math.max(0.0, h))));
    return earthRadiusMeters * c;
  }

  /// Computes initial forward azimuth / bearing in degrees [0.0, 360.0) from [start] to [end].
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180.0;
    final lon1 = start.longitude * math.pi / 180.0;
    final lat2 = end.latitude * math.pi / 180.0;
    final lon2 = end.longitude * math.pi / 180.0;

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  /// Linearly interpolates between coordinate [a] and [b] with factor [fraction] in [0.0, 1.0].
  static LatLng interpolateCoordinate(LatLng a, LatLng b, double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    final lat = a.latitude + (b.latitude - a.latitude) * clamped;
    final lon = a.longitude + (b.longitude - a.longitude) * clamped;
    return LatLng(lat, lon);
  }

  /// Smoothly interpolates an angular heading (bearing in degrees) from [from] to [to]
  /// via the shortest angular path across 0°/360° discontinuity.
  static double interpolateBearing(double from, double to, double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    double diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (from + diff * clamped + 360.0) % 360.0;
  }
}
