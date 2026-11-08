import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'fleet_map_constants.dart';

/// Pure mathematical and geographic calculation engine for map camera operations.
/// Completely decoupled from native platform channels and MapLibre controllers
/// to ensure 100% deterministic unit testing without mocks.
class CameraCalculationHelper {
  const CameraCalculationHelper._();

  /// Validates geographic latitude and longitude coordinates.
  ///
  /// Enforces:
  /// 1. Non-null values.
  /// 2. Non-NaN and finite floating-point numbers.
  /// 3. Valid latitude bounds: [-90.0, 90.0].
  /// 4. Valid longitude bounds: [-180.0, 180.0].
  /// 5. Rejection of the (0.0, 0.0) "Null Island" coordinate per P7.3.0 policy.
  static bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return false;
    }

    if (latitude.isNaN ||
        latitude.isInfinite ||
        longitude.isNaN ||
        longitude.isInfinite) {
      return false;
    }

    if (latitude < -90.0 || latitude > 90.0) {
      return false;
    }

    if (longitude < -180.0 || longitude > 180.0) {
      return false;
    }

    // Reject exact (0.0, 0.0) "Null Island" default uninitialized GPS coordinate
    // per Traccar FilterHandler.java and P7.3.0 policy.
    // Handles both 0.0 and -0.0 in IEEE 754. Legitimate near-zero coordinates
    // (e.g. 0.0000005, 0.0000005) are preserved.
    if (latitude == 0.0 && longitude == 0.0) {
      return false;
    }

    return true;
  }

  /// Filters an iterable of [LatLng] points, returning only those that satisfy [isValidCoordinate].
  static List<LatLng> filterValidCoordinates(Iterable<LatLng> coordinates) {
    return coordinates
        .where((c) => isValidCoordinate(c.latitude, c.longitude))
        .toList(growable: false);
  }

  /// Computes the minimal [LatLngBounds] encompassing all valid coordinates.
  ///
  /// Returns `null` if the input is empty or contains zero valid coordinates.
  /// Returns a degenerate bound (`southwest == northeast`) for a single coordinate.
  static LatLngBounds? calculateBounds(Iterable<LatLng> coordinates) {
    final validCoords = filterValidCoordinates(coordinates);
    if (validCoords.isEmpty) {
      return null;
    }

    double minLat = validCoords.first.latitude;
    double maxLat = validCoords.first.latitude;
    double minLng = validCoords.first.longitude;
    double maxLng = validCoords.first.longitude;

    for (int i = 1; i < validCoords.length; i++) {
      final point = validCoords[i];
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Computes symmetrical viewport padding for bounding box fitting.
  ///
  /// Defaults to 10% of the smallest screen dimension, clamped by [minPadding].
  /// Safely falls back to [minPadding] if the viewport has non-positive dimensions.
  static EdgeInsets calculateViewportPadding({
    required Size viewportSize,
    double paddingRatio = FleetMapConstants.defaultBoundsPaddingRatio,
    double minPadding = FleetMapConstants.minBoundsPadding,
  }) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return EdgeInsets.all(minPadding);
    }

    final minDimension = math.min(viewportSize.width, viewportSize.height);
    final calculated = minDimension * paddingRatio;
    final padding = math.max(calculated, minPadding);

    return EdgeInsets.all(padding);
  }

  /// Calculates an offset camera center coordinate to prevent bottom-sheet obstruction.
  ///
  /// When a bottom sheet covers [verticalOffsetPixels] at the bottom of the viewport,
  /// shifting the camera target southward moves the vehicle marker northward into the
  /// visible upper half of the viewport.
  static LatLng calculateOffsetCenter({
    required LatLng target,
    required double zoom,
    required double verticalOffsetPixels,
  }) {
    if (verticalOffsetPixels <= 0.0) {
      return target;
    }

    // World map dimension in pixels at zoom Z
    final worldDimension = 256.0 * math.pow(2.0, zoom);

    // Radians conversion for latitude cosine dampening
    final latRad = target.latitude * math.pi / 180.0;
    final cosLat = math.cos(latRad).abs();

    // Degrees latitude per pixel at target latitude
    final degreesPerPixel = (360.0 * cosLat) / worldDimension;

    // Shift camera center southward by half the obstructed height
    final latDelta = (verticalOffsetPixels / 2.0) * degreesPerPixel;
    final offsetLatitude = math.max(-90.0, target.latitude - latDelta);

    return LatLng(offsetLatitude, target.longitude);
  }

  /// Pure helper determining the target [CameraPosition] for a collection of points
  /// without interacting with platform channels.
  static CameraPosition calculateTargetCamera({
    required Iterable<LatLng> coordinates,
    double defaultSelectionZoom = FleetMapConstants.defaultSelectionZoom,
    LatLng fallbackCenter = FleetMapConstants.defaultFallbackCenter,
    double fallbackZoom = FleetMapConstants.defaultEmptyFleetZoom,
  }) {
    final validCoords = filterValidCoordinates(coordinates);

    if (validCoords.isEmpty) {
      return CameraPosition(target: fallbackCenter, zoom: fallbackZoom);
    }

    if (validCoords.length == 1) {
      return CameraPosition(
        target: validCoords.first,
        zoom: defaultSelectionZoom,
      );
    }

    final bounds = calculateBounds(validCoords)!;
    final centerLat =
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2.0;
    final centerLng =
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2.0;

    return CameraPosition(
      target: LatLng(centerLat, centerLng),
      zoom: FleetMapConstants.defaultFleetOverviewZoom,
    );
  }
}
