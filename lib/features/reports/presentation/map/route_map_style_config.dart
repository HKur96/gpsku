import 'package:flutter/material.dart';

/// Configuration styling for route polyline and waypoint markers on MapLibre.
@immutable
class RouteMapStyleConfig {
  /// Hex color code for the route path (e.g. '#1E88E5').
  final String lineColor;

  /// Width of the route polyline in physical points.
  final double lineWidth;

  /// Opacity factor of the polyline between 0.0 and 1.0.
  final double lineOpacity;

  /// Stroke ending cap style ('round', 'butt', 'square').
  final String lineCap;

  /// Stroke joint connection style ('round', 'bevel', 'miter').
  final String lineJoin;

  /// Background color for the Start waypoint pin.
  final Color startMarkerColor;

  /// Background color for the End / Current waypoint pin.
  final Color endMarkerColor;

  /// Background color for Stop / Idling waypoint pins.
  final Color stopMarkerColor;

  /// Viewport edge padding when fitting camera bounds to the route.
  final EdgeInsets boundsPadding;

  const RouteMapStyleConfig({
    this.lineColor = '#1E88E5',
    this.lineWidth = 4.5,
    this.lineOpacity = 0.9,
    this.lineCap = 'round',
    this.lineJoin = 'round',
    this.startMarkerColor = const Color(0xFF2E7D32), // Emerald Green
    this.endMarkerColor = const Color(0xFFC62828), // Crimson Red
    this.stopMarkerColor = const Color(0xFFEF6C00), // Amber Orange
    this.boundsPadding = const EdgeInsets.only(
      top: 90.0,
      bottom: 140.0,
      left: 50.0,
      right: 50.0,
    ),
  });
}
