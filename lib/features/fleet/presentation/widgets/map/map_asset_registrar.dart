import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';

/// Manages registration of vehicle marker icons and heading indicators in MapLibre style.
///
/// Generates crisp, resolution-independent vector bitmaps via [ui.Canvas] and registers them
/// with the active [MapLibreMapController] upon style loaded events.
class MapAssetRegistrar {
  const MapAssetRegistrar._();

  /// Supported vehicle categories matching Traccar entity conventions.
  static const List<String> supportedCategories = [
    'default',
    'car',
    'truck',
    'bus',
    'motorcycle',
    'bicycle',
    'person',
  ];

  /// Supported status color variants matching Traccar Web status mapping.
  static const List<String> supportedStatusColors = [
    'success', // Online (Green)
    'error', // Offline (Red)
    'neutral', // Unknown / Inactive (Grey)
    'info', // Selected / Focused (Blue)
  ];

  /// Heading directional pointer asset identifier.
  static const String directionIconId = 'direction';

  /// Generates the canonical icon identifier, e.g. 'car-success', 'truck-error'.
  static String buildIconId(String category, String statusColor) {
    final cat = supportedCategories.contains(category) ? category : 'default';
    final col = supportedStatusColors.contains(statusColor)
        ? statusColor
        : 'neutral';
    return '$cat-$col';
  }

  /// In-memory cache of pre-rendered PNG byte arrays to avoid redundant canvas painting.
  static final Map<String, Uint8List> _cachedBitmaps = {};

  /// Returns the count of cached bitmaps in memory.
  @visibleForTesting
  static int get cachedBitmapCount => _cachedBitmaps.length;

  /// Generates the PNG bytes for a category marker bitmap.
  /// Exposed for testing and deterministic raster verification.
  @visibleForTesting
  static Future<Uint8List> generateCategoryMarkerBytes({
    required String category,
    required String statusColor,
    required double pixelRatio,
  }) async {
    return _generateCategoryMarker(
      category: category,
      statusColor: statusColor,
      pixelRatio: pixelRatio,
    );
  }

  /// Generates the PNG bytes for the direction arrow pointer bitmap.
  /// Exposed for testing and deterministic raster verification.
  @visibleForTesting
  static Future<Uint8List> generateDirectionArrowBytes({
    required double pixelRatio,
  }) async {
    return _generateDirectionArrow(pixelRatio: pixelRatio);
  }

  /// Registers all 29 fleet icons (7 categories x 4 colors + 1 direction) into [controller].
  ///
  /// Safe to call on every style load or reload. Handles missing assets gracefully without
  /// crashing the map engine.
  static Future<int> registerFleetIcons(
    MapLibreMapController controller, {
    double pixelRatio = 2.0,
    bool forceRegenerate = false,
  }) async {
    if (controller.isDisposed) {
      AppLogger.warn(
        'MapAssetRegistrar: Skipped icon registration on disposed controller.',
      );
      return 0;
    }

    if (forceRegenerate) {
      _cachedBitmaps.clear();
    }

    int registeredCount = 0;

    try {
      // 1. Ensure all vehicle category-status combinations are generated
      for (final category in supportedCategories) {
        for (final status in supportedStatusColors) {
          final iconId = buildIconId(category, status);
          final bytes =
              _cachedBitmaps[iconId] ??
              await _generateCategoryMarker(
                category: category,
                statusColor: status,
                pixelRatio: pixelRatio,
              );
          _cachedBitmaps[iconId] = bytes;

          if (!controller.isDisposed) {
            await controller.addImage(iconId, bytes, false, pixelRatio);
            registeredCount++;
          }
        }
      }

      // 2. Register directional heading indicator arrow
      final directionBytes =
          _cachedBitmaps[directionIconId] ??
          await _generateDirectionArrow(pixelRatio: pixelRatio);
      _cachedBitmaps[directionIconId] = directionBytes;

      if (!controller.isDisposed) {
        await controller.addImage(
          directionIconId,
          directionBytes,
          false,
          pixelRatio,
        );
        registeredCount++;
      }

      AppLogger.info(
        'MapAssetRegistrar: Successfully registered $registeredCount vehicle icons into MapLibre style.',
      );
    } catch (e, stack) {
      AppLogger.error(
        'MapAssetRegistrar: Failed to register fleet icons into style',
        e,
        stack,
      );
    }

    return registeredCount;
  }

  /// Color mapping matching Traccar Web palette.
  static Color _resolveColor(String statusColor) {
    switch (statusColor) {
      case 'success':
        return const Color(0xFF4CAF50); // Online Green
      case 'error':
        return const Color(0xFFE53935); // Offline Red
      case 'info':
        return const Color(0xFF1E88E5); // Selected Blue
      case 'neutral':
      default:
        return const Color(0xFF757575); // Unknown Grey
    }
  }

  /// Programmatically draws a high-resolution circular vehicle marker pin.
  static Future<Uint8List> _generateCategoryMarker({
    required String category,
    required String statusColor,
    required double pixelRatio,
  }) async {
    const double baseSize = 44.0;
    final double physicalSize = baseSize * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, physicalSize, physicalSize),
    );

    final center = Offset(physicalSize / 2.0, physicalSize / 2.0);
    final radius = (physicalSize / 2.0) - (2.0 * pixelRatio);

    final color = _resolveColor(statusColor);

    // 1. Drop shadow / Outer border
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * pixelRatio);
    canvas.drawCircle(
      center.translate(0, 1.5 * pixelRatio),
      radius,
      shadowPaint,
    );

    // 2. White outer ring for contrast
    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, whiteRingPaint);

    // 3. Colored status inner circle
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - (2.5 * pixelRatio), innerPaint);

    // 4. White category glyph silhouette in the center
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0 * pixelRatio
      ..strokeCap = StrokeCap.round;

    _drawCategoryGlyph(
      canvas,
      center,
      physicalSize * 0.45,
      category,
      iconPaint,
      pixelRatio,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      physicalSize.toInt(),
      physicalSize.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Draws vector category silhouettes onto the canvas.
  static void _drawCategoryGlyph(
    Canvas canvas,
    Offset center,
    double size,
    String category,
    Paint paint,
    double pixelRatio,
  ) {
    final half = size / 2.0;

    switch (category) {
      case 'car':
        // Car chassis + roof silhouette
        final carPath = Path()
          ..moveTo(center.dx - half, center.dy + half * 0.4)
          ..lineTo(center.dx - half * 0.8, center.dy - half * 0.1)
          ..lineTo(center.dx - half * 0.4, center.dy - half * 0.6)
          ..lineTo(center.dx + half * 0.4, center.dy - half * 0.6)
          ..lineTo(center.dx + half * 0.8, center.dy - half * 0.1)
          ..lineTo(center.dx + half, center.dy + half * 0.4)
          ..close();
        canvas.drawPath(carPath, paint);
        // Wheels
        final wheelPaint = Paint()..color = const Color(0xFF212121);
        canvas.drawCircle(
          Offset(center.dx - half * 0.5, center.dy + half * 0.5),
          2.2 * pixelRatio,
          wheelPaint,
        );
        canvas.drawCircle(
          Offset(center.dx + half * 0.5, center.dy + half * 0.5),
          2.2 * pixelRatio,
          wheelPaint,
        );
        break;

      case 'truck':
        // Truck body + cab
        final truckPath = Path()
          ..moveTo(center.dx - half, center.dy + half * 0.4)
          ..lineTo(center.dx - half, center.dy - half * 0.6)
          ..lineTo(center.dx + half * 0.2, center.dy - half * 0.6)
          ..lineTo(center.dx + half * 0.2, center.dy - half * 0.2)
          ..lineTo(center.dx + half * 0.8, center.dy - half * 0.2)
          ..lineTo(center.dx + half, center.dy + half * 0.4)
          ..close();
        canvas.drawPath(truckPath, paint);
        // Wheels
        final wheelPaint = Paint()..color = const Color(0xFF212121);
        canvas.drawCircle(
          Offset(center.dx - half * 0.6, center.dy + half * 0.5),
          2.2 * pixelRatio,
          wheelPaint,
        );
        canvas.drawCircle(
          Offset(center.dx + half * 0.6, center.dy + half * 0.5),
          2.2 * pixelRatio,
          wheelPaint,
        );
        break;

      case 'bus':
        // Bus rectangular profile with rounded top corners
        final busRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: size * 0.9,
            height: size * 0.9,
          ),
          Radius.circular(3.0 * pixelRatio),
        );
        canvas.drawRRect(busRect, paint);
        // Windshield cutout
        final windowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              center.dx - half * 0.7,
              center.dy - half * 0.7,
              size * 0.7,
              size * 0.35,
            ),
            Radius.circular(1.5 * pixelRatio),
          ),
          windowPaint,
        );
        break;

      case 'motorcycle':
      case 'bicycle':
        // 2 wheels + handlebar
        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * pixelRatio;
        canvas.drawCircle(
          Offset(center.dx - half * 0.55, center.dy + half * 0.2),
          3.0 * pixelRatio,
          strokePaint,
        );
        canvas.drawCircle(
          Offset(center.dx + half * 0.55, center.dy + half * 0.2),
          3.0 * pixelRatio,
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx - half * 0.55, center.dy + half * 0.2),
          Offset(center.dx, center.dy - half * 0.3),
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx + half * 0.55, center.dy + half * 0.2),
          Offset(center.dx + half * 0.2, center.dy - half * 0.5),
          strokePaint,
        );
        break;

      case 'person':
        // Head + Torso
        canvas.drawCircle(
          Offset(center.dx, center.dy - half * 0.4),
          3.5 * pixelRatio,
          paint,
        );
        final torsoPath = Path()
          ..moveTo(center.dx - half * 0.5, center.dy + half * 0.6)
          ..lineTo(center.dx - half * 0.3, center.dy)
          ..lineTo(center.dx + half * 0.3, center.dy)
          ..lineTo(center.dx + half * 0.5, center.dy + half * 0.6)
          ..close();
        canvas.drawPath(torsoPath, paint);
        break;

      case 'default':
      default:
        // Teardrop location pin
        final pinPath = Path()
          ..moveTo(center.dx, center.dy + half * 0.7)
          ..quadraticBezierTo(
            center.dx - half * 0.7,
            center.dy - half * 0.1,
            center.dx - half * 0.5,
            center.dy - half * 0.5,
          )
          ..arcToPoint(
            Offset(center.dx + half * 0.5, center.dy - half * 0.5),
            radius: Radius.circular(half * 0.5),
          )
          ..quadraticBezierTo(
            center.dx + half * 0.7,
            center.dy - half * 0.1,
            center.dx,
            center.dy + half * 0.7,
          )
          ..close();
        canvas.drawPath(pinPath, paint);
        // Inner circle
        final innerCutout = Paint()
          ..color = const Color(0xFF212121).withValues(alpha: 0.4);
        canvas.drawCircle(
          Offset(center.dx, center.dy - half * 0.3),
          2.5 * pixelRatio,
          innerCutout,
        );
        break;
    }
  }

  /// Programmatically generates a directional heading arrow pointing North (0 degrees).
  static Future<Uint8List> _generateDirectionArrow({
    required double pixelRatio,
  }) async {
    const double baseSize = 36.0;
    final double physicalSize = baseSize * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, physicalSize, physicalSize),
    );

    final center = Offset(physicalSize / 2.0, physicalSize / 2.0);

    // Arrow pointer pointing up (North)
    final path = Path()
      ..moveTo(center.dx, 4.0 * pixelRatio) // Apex
      ..lineTo(
        physicalSize - (6.0 * pixelRatio),
        physicalSize - (6.0 * pixelRatio),
      ) // Bottom Right
      ..lineTo(center.dx, physicalSize - (12.0 * pixelRatio)) // Inner notch
      ..lineTo(
        6.0 * pixelRatio,
        physicalSize - (6.0 * pixelRatio),
      ) // Bottom Left
      ..close();

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * pixelRatio);
    canvas.drawPath(path.shift(Offset(0, 1.5 * pixelRatio)), shadowPaint);

    // White border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * pixelRatio
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Cyan / Vibrant Teal pointer fill
    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      physicalSize.toInt(),
      physicalSize.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }
}
