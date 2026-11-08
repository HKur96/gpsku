import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'map_route_controller.dart';

/// Generates and registers crisp vector-rasterized waypoint icons for route playback:
/// - [startIconId]: Green circular pin for route starting point.
/// - [endIconId]: Red circular pin for route terminus.
/// - [stopIconId]: Amber circular pin for route stops/idling locations.
class RouteMapAssetRegistrar {
  const RouteMapAssetRegistrar._();

  static const String startIconId = 'route-start-pin';
  static const String endIconId = 'route-end-pin';
  static const String stopIconId = 'route-stop-pin';

  static final Map<String, Uint8List> _cachedBitmaps = {};

  @visibleForTesting
  static int get cachedBitmapCount => _cachedBitmaps.length;

  /// Generates the PNG byte array for the specified waypoint pin type.
  static Future<Uint8List> generateWaypointMarkerBytes({
    required String iconId,
    required Color color,
    required String label,
    double pixelRatio = 2.0,
  }) async {
    final cached = _cachedBitmaps[iconId];
    if (cached != null) return cached;

    const double baseSize = 40.0;
    final double physicalSize = baseSize * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, physicalSize, physicalSize),
    );

    final center = Offset(physicalSize / 2.0, physicalSize / 2.0);
    final radius = (physicalSize / 2.0) - (2.0 * pixelRatio);

    // 1. Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * pixelRatio);
    canvas.drawCircle(
      center.translate(0, 2.0 * pixelRatio),
      radius,
      shadowPaint,
    );

    // 2. White outer ring for contrast
    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, whiteRingPaint);

    // 3. Colored inner core
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - (2.5 * pixelRatio), innerPaint);

    // 4. White text label in center ('S', 'F', 'P')
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.0 * pixelRatio,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2.0),
        center.dy - (textPainter.height / 2.0),
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      physicalSize.toInt(),
      physicalSize.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = byteData!.buffer.asUint8List();
    _cachedBitmaps[iconId] = bytes;
    return bytes;
  }

  /// Registers all route waypoint icons into the active [controller].
  static Future<int> registerRouteIcons(
    MapRouteController controller, {
    double pixelRatio = 2.0,
    bool forceRegenerate = false,
  }) async {
    if (controller.isDisposed) {
      AppLogger.warn(
        'RouteMapAssetRegistrar: Skipped icon registration on disposed controller.',
      );
      return 0;
    }

    if (forceRegenerate) {
      _cachedBitmaps.clear();
    }

    int count = 0;
    try {
      final icons = [
        (startIconId, const Color(0xFF2E7D32), 'S'),
        (endIconId, const Color(0xFFC62828), 'F'),
        (stopIconId, const Color(0xFFEF6C00), 'P'),
      ];

      for (final (id, color, label) in icons) {
        final bytes = await generateWaypointMarkerBytes(
          iconId: id,
          color: color,
          label: label,
          pixelRatio: pixelRatio,
        );

        if (!controller.isDisposed) {
          await controller.addImage(id, bytes, false, pixelRatio);
          count++;
        }
      }

      AppLogger.info(
        'RouteMapAssetRegistrar: Successfully registered $count route waypoint icons into MapLibre.',
      );
    } catch (e, stack) {
      AppLogger.error(
        'RouteMapAssetRegistrar: Failed to register waypoint icons',
        e,
        stack,
      );
    }

    return count;
  }
}
