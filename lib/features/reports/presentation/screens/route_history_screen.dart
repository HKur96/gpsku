import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_map_widget.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';
import 'package:gpsku/features/reports/domain/helpers/report_date_range_helper.dart';
import 'package:gpsku/features/reports/domain/repositories/reports_repository.dart';
import '../map/map_route_controller.dart';
import '../map/route_map_asset_registrar.dart';
import '../map/route_map_renderer.dart';
import '../playback/route_playback_controller.dart';
import '../widgets/filter/route_date_preset_bar.dart';
import '../widgets/playback/route_playback_sheet.dart';
import '../widgets/sheet/route_summary_panel.dart';

/// Production Route History & Playback Screen for GPSku.
///
/// Integrates:
/// 1. Preset & Custom Date Range filtering.
/// 2. Spatial MapLibre route polyline, terminus pins, and stop markers.
/// 3. Tabbed summary panel (Trips & Stops).
/// 4. Interactive telematics simulation & playback sheet with throttled camera follow.
/// 5. Graceful PopScope lifecycle management.
class RouteHistoryScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;
  final ReportsRepository? reportsRepository;
  final MapRouteController? testMapRouteController;
  final ReportDateRange? initialDateRange;

  const RouteHistoryScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.reportsRepository,
    this.testMapRouteController,
    this.initialDateRange,
  });

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  late ReportDateRange _dateRange;
  late final RoutePlaybackController _playbackController;
  late final RouteMapRenderer _renderer;
  MapRouteController? _mapRouteController;

  bool _isPlaybackMode = false;
  bool _isLoading = true;
  String? _errorMessage;

  List<PositionModel> _positions = const [];
  List<TripReportModel> _trips = const [];
  List<StopReportModel> _stops = const [];

  CancelToken? _cancelToken;
  DateTime _lastCameraFollowTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isStyleLoaded = false;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange ?? ReportDateRange.today();
    _playbackController = RoutePlaybackController();
    _renderer = RouteMapRenderer();

    _playbackController.onPositionUpdated = _handlePositionUpdated;

    // Attach test controller immediately if running in headless test
    if (widget.testMapRouteController != null) {
      _mapRouteController = widget.testMapRouteController;
      _renderer.attach(_mapRouteController!);
      _isStyleLoaded = true;
    }

    _fetchRouteData();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('RouteHistoryScreen disposed');
    _playbackController.dispose();
    _renderer.dispose();
    super.dispose();
  }

  void _handlePositionUpdated(LatLng coord, double bearing) {
    if (!mounted) return;
    _renderer.updatePlaybackMarker(coordinate: coord, bearing: bearing);

    // Throttled Camera Follow mode (>= 600ms) to prevent GPU overload on MapLibre
    if (_playbackController.isCameraFollowEnabled &&
        _mapRouteController != null) {
      final now = DateTime.now();
      if (now.difference(_lastCameraFollowTime).inMilliseconds >= 600) {
        _lastCameraFollowTime = now;
        _mapRouteController!.animateCamera(CameraUpdate.newLatLng(coord));
      }
    }
  }

  Future<void> _fetchRouteData() async {
    _cancelToken?.cancel('Date range changed or new request initiated');
    _cancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = widget.reportsRepository ?? context.read<ReportsRepository>();

    try {
      final results = await Future.wait([
        repo.getRouteReport(
          deviceId: widget.deviceId,
          from: _dateRange.from,
          to: _dateRange.to,
          cancelToken: _cancelToken,
        ),
        repo.getTripReport(
          deviceId: widget.deviceId,
          from: _dateRange.from,
          to: _dateRange.to,
          cancelToken: _cancelToken,
        ),
        repo.getStopReport(
          deviceId: widget.deviceId,
          from: _dateRange.from,
          to: _dateRange.to,
          cancelToken: _cancelToken,
        ),
      ]);

      if (!mounted) return;

      final routeResult = results[0];
      final tripsResult = results[1];
      final stopsResult = results[2];

      List<PositionModel> newPositions = [];
      List<TripReportModel> newTrips = [];
      List<StopReportModel> newStops = [];
      String? error;

      routeResult.fold(
        (failure) => error = failure.message,
        (data) => newPositions = data as List<PositionModel>,
      );

      tripsResult.fold(
        (failure) => error ??= failure.message,
        (data) => newTrips = data as List<TripReportModel>,
      );

      stopsResult.fold(
        (failure) => error ??= failure.message,
        (data) => newStops = data as List<StopReportModel>,
      );

      setState(() {
        _isLoading = false;
        _positions = newPositions;
        _trips = newTrips;
        _stops = newStops;
        _errorMessage = error;
      });

      // Update Playback Controller
      _playbackController.loadRoute(newPositions);

      // Render spatial layers if map style is ready
      if (_isStyleLoaded && _mapRouteController != null) {
        await _renderer.renderRoute(positions: newPositions, stops: newStops);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data riwayat perjalanan: $e';
      });
    }
  }

  void _onDateRangeChanged(ReportDateRange newRange) {
    if (_dateRange == newRange) return;

    if (_isPlaybackMode) {
      _playbackController.pause();
      setState(() => _isPlaybackMode = false);
    }

    _renderer.clearRoute();
    setState(() {
      _dateRange = newRange;
    });

    _fetchRouteData();
  }

  void _onTripSelected(TripReportModel trip) {
    if (_mapRouteController == null) return;
    if (trip.startLat != null &&
        trip.startLon != null &&
        trip.endLat != null &&
        trip.endLon != null) {
      final bounds = CameraCalculationHelper.calculateBounds([
        LatLng(trip.startLat!, trip.startLon!),
        LatLng(trip.endLat!, trip.endLon!),
      ]);
      if (bounds != null) {
        _mapRouteController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50.0,
            right: 50.0,
            top: 80.0,
            bottom: 300.0,
          ),
        );
      }
    }
  }

  void _onStopSelected(StopReportModel stop) {
    if (_mapRouteController == null) return;
    if (CameraCalculationHelper.isValidCoordinate(
      stop.latitude,
      stop.longitude,
    )) {
      _mapRouteController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(stop.latitude, stop.longitude), 15.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isPlaybackMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isPlaybackMode) {
          _playbackController.pause();
          setState(() => _isPlaybackMode = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.deviceName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Riwayat: ${_dateRange.preset.label}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          actions: [
            if (_positions.isNotEmpty && !_isPlaybackMode)
              IconButton(
                key: const Key('route_history_playback_toggle_button'),
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Buka Pemutaran',
                onPressed: () {
                  setState(() => _isPlaybackMode = true);
                  _playbackController.play();
                },
              ),
            if (_isPlaybackMode)
              IconButton(
                key: const Key('route_history_close_playback_button'),
                icon: const Icon(Icons.close),
                tooltip: 'Tutup Pemutaran',
                onPressed: () {
                  _playbackController.pause();
                  setState(() => _isPlaybackMode = false);
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // Preset & Custom Date Range Bar
            RouteDatePresetBar(
              selectedRange: _dateRange,
              onRangeChanged: _onDateRangeChanged,
            ),

            // Map Viewport with Stacked Panels
            Expanded(
              child: Stack(
                children: [
                  // Map Canvas
                  Positioned.fill(
                    child: widget.testMapRouteController != null
                        ? Container(
                            key: const Key('route_history_test_map_canvas'),
                            color: Colors.blueGrey.shade50,
                            child: const Center(
                              child: Text(
                                'Map Viewport (Headless Test Canvas)',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ),
                          )
                        : FleetMapWidget(
                            onMapReady: (controller, cameraController) {
                              _mapRouteController = MapLibreRouteAdapter(
                                controller,
                              );
                              _renderer.attach(_mapRouteController!);
                            },
                            onStyleLoaded: (controller) async {
                              _isStyleLoaded = true;
                              await RouteMapAssetRegistrar.registerRouteIcons(
                                MapLibreRouteAdapter(controller),
                              );
                              if (_positions.isNotEmpty) {
                                await _renderer.renderRoute(
                                  positions: _positions,
                                  stops: _stops,
                                );
                              }
                            },
                          ),
                  ),

                  // Loading Overlay
                  if (_isLoading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x22000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  // Error Banner
                  if (_errorMessage != null && !_isLoading)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8.0),
                        color: const Color(0xFFFEE2E2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Empty State Floating Badge
                  if (!_isLoading &&
                      _positions.isEmpty &&
                      _errorMessage == null)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Material(
                        elevation: 2.0,
                        borderRadius: BorderRadius.circular(8.0),
                        color: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 10.0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF1E88E5),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tidak ada riwayat rute pada periode ini.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom Sheets: Summary Mode vs Playback Mode
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _isPlaybackMode
                        ? RoutePlaybackSheet(
                            controller: _playbackController,
                            onClose: () {
                              _playbackController.pause();
                              setState(() => _isPlaybackMode = false);
                            },
                          )
                        : RouteSummaryPanel(
                            trips: _trips,
                            stops: _stops,
                            positionsCount: _positions.length,
                            isLoading: _isLoading,
                            onStartPlayback: () {
                              setState(() => _isPlaybackMode = true);
                              _playbackController.play();
                            },
                            onTripSelected: _onTripSelected,
                            onStopSelected: _onStopSelected,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
