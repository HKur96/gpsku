import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'fleet_camera_controller.dart';
import 'fleet_map_constants.dart';
import 'map_asset_registrar.dart';

/// Reusable production MapLibre widget for GPSku.
///
/// Encapsulates map lifecycle, native OpenGL/Vulkan surface binding,
/// OpenFreeMap Liberty vector tile loading, automatic vehicle asset preloading,
/// and attribution display while remaining completely decoupled from WebSocket and Repository layers.
class FleetMapWidget extends StatefulWidget {
  final CameraPosition initialCameraPosition;
  final String styleString;
  final void Function(
    MapLibreMapController controller,
    FleetCameraController cameraController,
  )?
  onMapReady;
  final void Function(MapLibreMapController controller)? onStyleLoaded;
  final void Function(Point<double> point, LatLng coordinates)? onMapClick;
  final void Function(CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final bool compassEnabled;
  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool zoomGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool trackCameraPosition;
  final bool showAttribution;
  final Widget? placeholder;
  final Widget Function(
    BuildContext context,
    String error,
    VoidCallback onRetry,
  )?
  errorBuilder;

  const FleetMapWidget({
    super.key,
    this.initialCameraPosition = const CameraPosition(
      target: FleetMapConstants.defaultFallbackCenter,
      zoom: FleetMapConstants.defaultSelectionZoom,
    ),
    this.styleString = FleetMapConstants.openFreeMapLibertyStyle,
    this.onMapReady,
    this.onStyleLoaded,
    this.onMapClick,
    this.onCameraMove,
    this.onCameraIdle,
    this.compassEnabled = true,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled =
        false, // Disabled by default for telematics par axial clarity
    this.trackCameraPosition = true,
    this.showAttribution = true,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  State<FleetMapWidget> createState() => _FleetMapWidgetState();
}

class _FleetMapWidgetState extends State<FleetMapWidget> {
  late final FleetCameraController _cameraController;
  MapLibreMapController? _controller;
  Timer? _styleLoadTimer;
  static const Duration _styleLoadTimeout = Duration(seconds: 15);

  bool _isMapReady = false;
  bool _isStyleLoaded = false;
  bool _hasStyleError = false;
  String? _styleErrorMessage;
  int _styleLoadSequence = 0;

  @override
  void initState() {
    super.initState();
    _cameraController = FleetCameraController();
  }

  void _startStyleLoadTimeout() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(_styleLoadTimeout, () {
      if (mounted && !_isStyleLoaded && !_hasStyleError) {
        AppLogger.warn(
          'FleetMapWidget: Style loading timed out after ${_styleLoadTimeout.inSeconds}s.',
        );
        setState(() {
          _hasStyleError = true;
          _styleErrorMessage =
              'Waktu memuat gaya peta telah habis. Periksa koneksi internet Anda.';
        });
      }
    });
  }

  /// Handles initial native surface creation and controller acquisition.
  void _onMapCreated(MapLibreMapController controller) {
    if (!mounted) {
      controller.dispose();
      return;
    }

    _controller = controller;
    _cameraController.attach(controller);
    setState(() {
      _isMapReady = true;
    });

    _startStyleLoadTimeout();

    AppLogger.info(
      'FleetMapWidget: MapLibre native surface created successfully.',
    );
    widget.onMapReady?.call(controller, _cameraController);
  }

  /// Handles MapLibre style loaded lifecycle event.
  /// Automatically registers the 29 vehicle marker bitmaps into the style.
  Future<void> _onStyleLoadedCallback() async {
    _styleLoadTimer?.cancel();
    if (!mounted || _controller == null || _controller!.isDisposed) {
      return;
    }

    final currentSequence = ++_styleLoadSequence;
    AppLogger.info(
      'FleetMapWidget: Style loaded event received (sequence #$currentSequence).',
    );

    try {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;

      // Register vehicle marker assets into the newly loaded style
      final registered = await MapAssetRegistrar.registerFleetIcons(
        _controller!,
        pixelRatio: pixelRatio,
      );

      if (!mounted || currentSequence != _styleLoadSequence) {
        return;
      }

      setState(() {
        _isStyleLoaded = true;
        _hasStyleError = false;
        _styleErrorMessage = null;
      });

      AppLogger.info(
        'FleetMapWidget: Preloaded $registered marker assets into style #$currentSequence.',
      );
      widget.onStyleLoaded?.call(_controller!);
    } catch (e, stack) {
      AppLogger.error(
        'FleetMapWidget: Error during style loaded processing',
        e,
        stack,
      );
      if (mounted) {
        setState(() {
          _hasStyleError = true;
          _styleErrorMessage = e.toString();
        });
      }
    }
  }

  /// Retries loading map style upon failure.
  void _retryLoadStyle() {
    if (_controller != null && !_controller!.isDisposed) {
      setState(() {
        _hasStyleError = false;
        _styleErrorMessage = null;
        _isStyleLoaded = false;
      });
      _startStyleLoadTimeout();
      _controller!.setStyle(widget.styleString);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Native MapLibre Surface
        MapLibreMap(
          initialCameraPosition: widget.initialCameraPosition,
          styleString: widget.styleString,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoadedCallback,
          onMapClick: widget.onMapClick,
          onCameraMove: widget.onCameraMove,
          onCameraIdle: widget.onCameraIdle,
          compassEnabled: widget.compassEnabled,
          rotateGesturesEnabled: widget.rotateGesturesEnabled,
          scrollGesturesEnabled: widget.scrollGesturesEnabled,
          zoomGesturesEnabled: widget.zoomGesturesEnabled,
          tiltGesturesEnabled: widget.tiltGesturesEnabled,
          trackCameraPosition: widget.trackCameraPosition,
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
        ),

        // 2. Loading Placeholder before Map Surface & Vector Style are Ready
        if (!_isMapReady || !_isStyleLoaded)
          widget.placeholder ??
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFFF5F5F5),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

        // 3. Graceful Error Boundary Overlay
        if (_hasStyleError)
          Positioned.fill(
            child:
                widget.errorBuilder?.call(
                  context,
                  _styleErrorMessage ?? 'Map Style Error',
                  _retryLoadStyle,
                ) ??
                _DefaultErrorOverlay(
                  errorMessage:
                      _styleErrorMessage ?? 'Gagal memuat gaya peta vektor.',
                  onRetry: _retryLoadStyle,
                ),
          ),

        // 4. Attribution Banner per ODbL & OpenFreeMap requirements
        if (widget.showAttribution && !_hasStyleError)
          const Positioned(left: 8.0, bottom: 8.0, child: _AttributionBadge()),
      ],
    );
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    _cameraController.detach();
    _cameraController.dispose();
    _controller = null;
    super.dispose();
  }
}

/// Subtle, non-intrusive attribution banner required by OpenFreeMap & OpenStreetMap.
class _AttributionBadge extends StatelessWidget {
  const _AttributionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        FleetMapConstants.attributionText,
        style: TextStyle(
          fontSize: 9.5,
          color: Color(0xFF424242),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Fallback error overlay with clean retry button.
class _DefaultErrorOverlay extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _DefaultErrorOverlay({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, color: Colors.amber, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Gagal Memuat Peta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
