import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';

/// Pure engine for converting Traccar historical route positions into
/// strict RFC 7946 GeoJSON representations.
class RouteGeoJsonBuilder {
  const RouteGeoJsonBuilder._();

  static const String defaultSourceId = 'route-history-source';
  static const String defaultLayerId = 'route-history-line-layer';

  /// Extracts only mathematically and geographically valid [LatLng] coordinates from [positions].
  /// Filters out null, NaN, out-of-range, and (0.0, 0.0) coordinates.
  static List<LatLng> extractValidCoordinates(List<PositionModel> positions) {
    final valid = <LatLng>[];
    for (final pos in positions) {
      if (CameraCalculationHelper.isValidCoordinate(
        pos.latitude,
        pos.longitude,
      )) {
        valid.add(LatLng(pos.latitude, pos.longitude));
      }
    }
    return List.unmodifiable(valid);
  }

  /// Converts [positions] into a strict RFC 7946 GeoJSON FeatureCollection.
  ///
  /// Important rules:
  /// 1. Coordinate pairs must strictly be [longitude, latitude].
  /// 2. If fewer than 2 valid points exist, returns an empty FeatureCollection
  ///    to prevent MapLibre native crashes on invalid LineStrings.
  static Map<String, dynamic> buildLineStringFeatureCollection(
    List<PositionModel> positions, {
    Map<String, dynamic>? properties,
  }) {
    final validCoordinates = <List<double>>[];

    for (final pos in positions) {
      if (CameraCalculationHelper.isValidCoordinate(
        pos.latitude,
        pos.longitude,
      )) {
        // Strict GeoJSON RFC 7946: [longitude, latitude]
        validCoordinates.add([pos.longitude, pos.latitude]);
      }
    }

    if (validCoordinates.length < 2) {
      return {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': properties ?? <String, dynamic>{},
          'geometry': {'type': 'LineString', 'coordinates': validCoordinates},
        },
      ],
    };
  }
}
