import 'package:flutter/material.dart';

/// Configuration styling for geofence polygons, outlines, labels, and viewport framing.
@immutable
class GeofenceMapStyleConfig {
  /// Data-driven or static fill color property (defaults to GeoJSON property `color`).
  final dynamic fillColor;

  /// Data-driven or static fill opacity property (defaults to GeoJSON property `fillOpacity`).
  final dynamic fillOpacity;

  /// Data-driven or static outline stroke color (defaults to GeoJSON property `strokeColor`).
  final dynamic lineColor;

  /// Data-driven or static stroke line width in physical pixels (defaults to `strokeWidth`).
  final dynamic lineWidth;

  /// Line opacity factor between 0.0 and 1.0 (defaults to 0.8).
  final double lineOpacity;

  /// Whether to display geofence name text labels on the map canvas.
  final bool showLabels;

  /// Text field expression for name labels (defaults to GeoJSON property `name`).
  final dynamic labelField;

  /// Font size for label text in points (defaults to 12.0).
  final double labelSize;

  /// Label font color hex (defaults to deep indigo `#0D47A1`).
  final String labelColor;

  /// Label text outline halo color (defaults to white `#FFFFFF`).
  final String labelHaloColor;

  /// Label text halo outline thickness in points (defaults to 1.5).
  final double labelHaloWidth;

  /// Optional layer ID below which geofence spatial layers will be injected.
  /// Used to ensure vehicle markers render visually above geofence fills.
  final String? belowLayerId;

  /// Viewport padding when animating camera bounds to fit a geofence.
  final EdgeInsets boundsPadding;

  const GeofenceMapStyleConfig({
    this.fillColor = const ['get', 'color'],
    this.fillOpacity = const ['get', 'fillOpacity'],
    this.lineColor = const ['get', 'strokeColor'],
    this.lineWidth = const ['get', 'strokeWidth'],
    this.lineOpacity = 0.8,
    this.showLabels = true,
    this.labelField = const ['get', 'name'],
    this.labelSize = 12.0,
    this.labelColor = '#0D47A1',
    this.labelHaloColor = '#FFFFFF',
    this.labelHaloWidth = 1.5,
    this.belowLayerId,
    this.boundsPadding = const EdgeInsets.all(50.0),
  });
}
