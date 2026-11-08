import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'camera_calculation_helper.dart';
import 'fleet_map_constants.dart';

/// High-level camera manager for MapLibre map controller.
///
/// Encapsulates all camera movements, bounds animations, viewport padding calculations,
/// and vertical offset shifts to ensure markers are never obscured by bottom sheets.
class FleetCameraController {
  MapLibreMapController? _controller;
  bool _isDisposed = false;

  FleetCameraController({MapLibreMapController? controller})
    : _controller = controller;

  /// Attaches or updates the active [MapLibreMapController].
  void attach(MapLibreMapController controller) {
    if (_isDisposed) {
      AppLogger.warn(
        'Attempted to attach MapLibreMapController to a disposed FleetCameraController.',
      );
      return;
    }
    _controller = controller;
  }

  /// Detaches the active controller without disposing this manager instance.
  void detach() {
    _controller = null;
  }

  /// Whether a live, non-disposed map controller is currently attached.
  bool get isReady =>
      _controller != null && !_controller!.isDisposed && !_isDisposed;

  /// Smoothly animates the camera to encompass all coordinates in [coordinates].
  ///
  /// Automatically handles:
  /// - Filtering out invalid and (0, 0) coordinates.
  /// - Falling back to [resetToDefault] if the collection is empty.
  /// - Centering on the point if exactly 1 valid coordinate exists.
  /// - Computing proportional viewport padding based on [viewportSize].
  Future<bool?> fitFleetBounds(
    Iterable<LatLng> coordinates, {
    Size? viewportSize,
    double paddingRatio = FleetMapConstants.defaultBoundsPaddingRatio,
    double minPadding = FleetMapConstants.minBoundsPadding,
    Duration? duration,
  }) async {
    if (!isReady) {
      AppLogger.warn(
        'FleetCameraController: fitFleetBounds aborted — controller not ready.',
      );
      return false;
    }

    final validCoords = CameraCalculationHelper.filterValidCoordinates(
      coordinates,
    );

    if (validCoords.isEmpty) {
      return resetToDefault(duration: duration);
    }

    if (validCoords.length == 1) {
      return animateToDevice(
        validCoords.first,
        zoom: FleetMapConstants.defaultSelectionZoom,
        duration: duration,
      );
    }

    final bounds = CameraCalculationHelper.calculateBounds(validCoords);
    if (bounds == null) {
      return resetToDefault(duration: duration);
    }

    final padding = CameraCalculationHelper.calculateViewportPadding(
      viewportSize: viewportSize ?? const Size(400, 800),
      paddingRatio: paddingRatio,
      minPadding: minPadding,
    );

    try {
      return await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
        duration: duration,
      );
    } catch (e, stack) {
      AppLogger.error(
        'FleetCameraController: Failed to fit fleet bounds',
        e,
        stack,
      );
      return false;
    }
  }

  /// Smoothly animates the camera to focus on [target] at [zoom].
  ///
  /// If [verticalOffsetPixels] > 0 (e.g. when a bottom sheet is visible),
  /// the camera center is shifted southward so that the vehicle marker remains
  /// centered in the unobstructed upper portion of the viewport.
  Future<bool?> animateToDevice(
    LatLng target, {
    double zoom = FleetMapConstants.defaultSelectionZoom,
    double verticalOffsetPixels = 0.0,
    Duration? duration,
  }) async {
    if (!isReady) {
      AppLogger.warn(
        'FleetCameraController: animateToDevice aborted — controller not ready.',
      );
      return false;
    }

    if (!CameraCalculationHelper.isValidCoordinate(
      target.latitude,
      target.longitude,
    )) {
      AppLogger.warn(
        'FleetCameraController: Invalid target coordinate (${target.latitude}, ${target.longitude}).',
      );
      return false;
    }

    final effectiveTarget = CameraCalculationHelper.calculateOffsetCenter(
      target: target,
      zoom: zoom,
      verticalOffsetPixels: verticalOffsetPixels,
    );

    try {
      return await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(effectiveTarget, zoom),
        duration: duration,
      );
    } catch (e, stack) {
      AppLogger.error(
        'FleetCameraController: Failed to animate to device',
        e,
        stack,
      );
      return false;
    }
  }

  /// Instantaneously jumps camera to [target] without animation.
  Future<bool?> moveCameraToDevice(
    LatLng target, {
    double zoom = FleetMapConstants.defaultSelectionZoom,
    double verticalOffsetPixels = 0.0,
  }) async {
    if (!isReady) {
      AppLogger.warn(
        'FleetCameraController: moveCameraToDevice aborted — controller not ready.',
      );
      return false;
    }

    if (!CameraCalculationHelper.isValidCoordinate(
      target.latitude,
      target.longitude,
    )) {
      AppLogger.warn(
        'FleetCameraController: Invalid target coordinate (${target.latitude}, ${target.longitude}).',
      );
      return false;
    }

    final effectiveTarget = CameraCalculationHelper.calculateOffsetCenter(
      target: target,
      zoom: zoom,
      verticalOffsetPixels: verticalOffsetPixels,
    );

    try {
      return await _controller!.moveCamera(
        CameraUpdate.newLatLngZoom(effectiveTarget, zoom),
      );
    } catch (e, stack) {
      AppLogger.error(
        'FleetCameraController: Failed to move camera to device',
        e,
        stack,
      );
      return false;
    }
  }

  /// Resets the map camera to the default overview position and zoom.
  Future<bool?> resetToDefault({
    LatLng? fallbackCenter,
    double defaultZoom = FleetMapConstants.defaultEmptyFleetZoom,
    Duration? duration,
  }) async {
    if (!isReady) return false;

    final target = fallbackCenter ?? FleetMapConstants.defaultFallbackCenter;

    try {
      return await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(target, defaultZoom),
        duration: duration,
      );
    } catch (e, stack) {
      AppLogger.error(
        'FleetCameraController: Failed to reset to default camera',
        e,
        stack,
      );
      return false;
    }
  }

  /// Disposes controller references and flags this instance as disposed.
  void dispose() {
    _isDisposed = true;
    _controller = null;
  }
}
