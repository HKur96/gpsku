import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Central constants for MapLibre map integration in GPSku.
@immutable
class FleetMapConstants {
  const FleetMapConstants._();

  /// Default OpenFreeMap Liberty Vector style URL (free, no API key required).
  static const String openFreeMapLibertyStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Required open-source attribution text per ODbL and OpenFreeMap terms.
  static const String attributionText =
      '© OpenStreetMap contributors, OpenFreeMap';

  /// Default camera zoom level when selecting a single vehicle or focusing on device.
  /// Matches Traccar Web default attribute preference `web.selectZoom = 10`.
  static const double defaultSelectionZoom = 10.0;

  /// Default initial zoom level when multiple devices or whole fleet is displayed.
  static const double defaultFleetOverviewZoom = 6.0;

  /// Fallback camera center when no fleet coordinates or user preferences are available.
  /// Defaults to Jakarta, Indonesia coordinates as regional telemetry anchor.
  static const LatLng defaultFallbackCenter = LatLng(-6.2088, 106.8456);

  /// Fallback zoom level when fleet collection is completely empty.
  static const double defaultEmptyFleetZoom = 2.0;

  /// Default viewport padding ratio for bounding box fitting (10% of smallest screen dimension).
  static const double defaultBoundsPaddingRatio = 0.10;

  /// Minimum bounds padding in logical pixels to prevent edge clipping.
  static const double minBoundsPadding = 48.0;

  /// Approximate height in logical pixels of the bottom vehicle detail sheet
  /// used for calculating vertical camera offset.
  static const double defaultSheetObstructionHeight = 220.0;
}
