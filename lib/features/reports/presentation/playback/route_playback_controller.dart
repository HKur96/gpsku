import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/reports/domain/models/playback_state.dart';
import 'route_geodesic_helper.dart';

/// Interactive state machine and animation ticker driving historical route playback.
///
/// Responsibilities:
/// 1. Interpolates intermediate vehicle coordinates and headings between discrete GPS fixes.
/// 2. Manages playback states: [PlaybackStatus.idle], [playing], [paused], [completed].
/// 3. Supports speed multipliers (1x, 2x, 4x, 8x).
/// 4. Handles safe scrubbing on the timeline without race conditions.
/// 5. Dispatches real-time position updates to MapLibre moving marker and camera follower.
class RoutePlaybackController extends ChangeNotifier {
  List<PositionModel> _positions = const [];
  List<double> _cumulativeDistances = const [];

  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackSpeed _speed = PlaybackSpeed.speed1x;

  double _currentIndex = 0.0;
  bool _isCameraFollowEnabled = false;
  bool _wasPlayingBeforeScrub = false;
  bool _isDisposed = false;

  Timer? _tickerTimer;
  static const Duration tickInterval = Duration(milliseconds: 50);

  /// Callback fired on each tick / scrub with the simulated coordinate and bearing.
  void Function(LatLng coordinate, double bearing)? onPositionUpdated;

  RoutePlaybackController({List<PositionModel> initialPositions = const []}) {
    if (initialPositions.isNotEmpty) {
      loadRoute(initialPositions);
    }
  }

  // --- Getters ---

  List<PositionModel> get positions => _positions;
  PlaybackStatus get status => _status;
  PlaybackSpeed get speed => _speed;
  double get currentIndex => _currentIndex;
  bool get isCameraFollowEnabled => _isCameraFollowEnabled;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isPaused => _status == PlaybackStatus.paused;
  bool get isCompleted => _status == PlaybackStatus.completed;

  /// Progress along the route from 0.0 (start) to 1.0 (finish).
  double get currentProgress {
    if (_positions.length <= 1) return 0.0;
    return (_currentIndex / (_positions.length - 1)).clamp(0.0, 1.0);
  }

  /// Discrete index of the nearest previous GPS fix.
  int get currentFloorIndex {
    if (_positions.isEmpty) return 0;
    return _currentIndex.floor().clamp(0, _positions.length - 1);
  }

  /// Active discrete GPS fix model at current playback head.
  PositionModel? get currentPositionModel {
    if (_positions.isEmpty) return null;
    return _positions[currentFloorIndex];
  }

  /// Total distance of the route in meters.
  double get totalDistance {
    if (_cumulativeDistances.isEmpty) return 0.0;
    return _cumulativeDistances.last;
  }

  /// Total distance of the route in kilometers.
  double get totalDistanceKm => totalDistance / 1000.0;

  /// Distance traveled from start up to current playback head in meters.
  double get currentDistanceTraveled {
    if (_positions.length <= 1 || _cumulativeDistances.isEmpty) return 0.0;

    final floorIdx = currentFloorIndex;
    if (floorIdx >= _positions.length - 1) return totalDistance;

    final baseDist = _cumulativeDistances[floorIdx];
    final segDist = _cumulativeDistances[floorIdx + 1] - baseDist;
    final fraction = _currentIndex - floorIdx;

    return baseDist + (segDist * fraction);
  }

  /// Distance traveled in kilometers.
  double get currentDistanceTraveledKm => currentDistanceTraveled / 1000.0;

  /// Smoothly interpolated coordinate at current playback head.
  LatLng? get currentInterpolatedCoordinate {
    if (_positions.isEmpty) return null;
    if (_positions.length == 1) {
      return LatLng(_positions.first.latitude, _positions.first.longitude);
    }

    final floorIdx = currentFloorIndex;
    if (floorIdx >= _positions.length - 1) {
      return LatLng(_positions.last.latitude, _positions.last.longitude);
    }

    final p1 = LatLng(
      _positions[floorIdx].latitude,
      _positions[floorIdx].longitude,
    );
    final p2 = LatLng(
      _positions[floorIdx + 1].latitude,
      _positions[floorIdx + 1].longitude,
    );
    final fraction = _currentIndex - floorIdx;

    return RouteGeodesicHelper.interpolateCoordinate(p1, p2, fraction);
  }

  /// Smoothly interpolated vehicle heading/bearing in degrees [0, 360).
  double get currentBearing {
    if (_positions.isEmpty) return 0.0;
    if (_positions.length == 1) return _positions.first.course;

    final floorIdx = currentFloorIndex;
    final p1 = LatLng(
      _positions[floorIdx].latitude,
      _positions[floorIdx].longitude,
    );

    if (floorIdx >= _positions.length - 1) {
      if (_positions.last.course > 0.0) return _positions.last.course;
      final prev = LatLng(
        _positions[floorIdx - 1].latitude,
        _positions[floorIdx - 1].longitude,
      );
      return RouteGeodesicHelper.calculateBearing(prev, p1);
    }

    final p2 = LatLng(
      _positions[floorIdx + 1].latitude,
      _positions[floorIdx + 1].longitude,
    );

    final b1 = _positions[floorIdx].course > 0.0
        ? _positions[floorIdx].course
        : RouteGeodesicHelper.calculateBearing(p1, p2);

    final b2 = _positions[floorIdx + 1].course > 0.0
        ? _positions[floorIdx + 1].course
        : RouteGeodesicHelper.calculateBearing(p1, p2);

    final fraction = _currentIndex - floorIdx;
    return RouteGeodesicHelper.interpolateBearing(b1, b2, fraction);
  }

  /// Speed at current playback head in km/h.
  double get currentSpeedKmh {
    if (_positions.isEmpty) return 0.0;
    if (_positions.length == 1) return _positions.first.speedKmh;

    final floorIdx = currentFloorIndex;
    if (floorIdx >= _positions.length - 1) return _positions.last.speedKmh;

    final s1 = _positions[floorIdx].speedKmh;
    final s2 = _positions[floorIdx + 1].speedKmh;
    final fraction = _currentIndex - floorIdx;

    return s1 + (s2 - s1) * fraction;
  }

  /// Whether vehicle ignition ACC is active at current point.
  bool get isIgnitionOn {
    final pos = currentPositionModel;
    if (pos == null) return false;
    return pos.attributes['ignition'] == true;
  }

  // --- Route Loading & Reset ---

  /// Loads historical positions, pre-computes cumulative distances, and resets playback head.
  void loadRoute(List<PositionModel> positions) {
    _stopTicker();
    _positions = List.unmodifiable(positions);
    _currentIndex = 0.0;

    if (_positions.isEmpty) {
      _cumulativeDistances = const [];
      _status = PlaybackStatus.idle;
    } else {
      _computeCumulativeDistances();
      _status = PlaybackStatus.paused;
    }

    _notifyPositionUpdate();
    notifyListeners();
  }

  void _computeCumulativeDistances() {
    final distances = List<double>.filled(_positions.length, 0.0);
    double accumulated = 0.0;

    for (int i = 1; i < _positions.length; i++) {
      final p1 = LatLng(
        _positions[i - 1].latitude,
        _positions[i - 1].longitude,
      );
      final p2 = LatLng(_positions[i].latitude, _positions[i].longitude);
      if (CameraCalculationHelper.isValidCoordinate(
            p1.latitude,
            p1.longitude,
          ) &&
          CameraCalculationHelper.isValidCoordinate(
            p2.latitude,
            p2.longitude,
          )) {
        accumulated += RouteGeodesicHelper.distanceBetween(p1, p2);
      }
      distances[i] = accumulated;
    }

    _cumulativeDistances = List.unmodifiable(distances);
  }

  // --- Playback State Machine Actions ---

  /// Starts or resumes playback animation.
  void play() {
    if (_positions.length <= 1) return;

    if (_status == PlaybackStatus.completed) {
      _currentIndex = 0.0;
    }

    _status = PlaybackStatus.playing;
    _startTicker();
    notifyListeners();
  }

  /// Pauses active playback.
  void pause() {
    _stopTicker();
    _status = PlaybackStatus.paused;
    notifyListeners();
  }

  /// Toggles between play and pause states.
  void togglePlayPause() {
    if (_status == PlaybackStatus.playing) {
      pause();
    } else {
      play();
    }
  }

  /// Replays the route from the beginning.
  void restart() {
    seekToProgress(0.0);
    play();
  }

  /// Advances playback by a fixed delta in seconds, scaled by speed multiplier.
  void tick(double deltaSeconds) {
    if (_status != PlaybackStatus.playing || _positions.length <= 1) return;

    // Base pace: 1 segment fix per second at 1x
    final step = deltaSeconds * _speed.multiplier;
    final maxIndex = (_positions.length - 1).toDouble();
    _currentIndex += step;

    if (_currentIndex >= maxIndex) {
      _currentIndex = maxIndex;
      _stopTicker();
      _status = PlaybackStatus.completed;
    }

    _notifyPositionUpdate();
    notifyListeners();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(tickInterval, (_) {
      tick(tickInterval.inMilliseconds / 1000.0);
    });
  }

  void _stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  // --- Scrubbing & Seeking ---

  /// Sets playback head directly by fractional progress [0.0, 1.0].
  void seekToProgress(double progress) {
    if (_positions.length <= 1) return;

    final clamped = progress.clamp(0.0, 1.0);
    _currentIndex = clamped * (_positions.length - 1);

    if (_currentIndex >= _positions.length - 1) {
      _status = PlaybackStatus.completed;
      _stopTicker();
    } else if (_status == PlaybackStatus.completed) {
      _status = PlaybackStatus.paused;
    }

    _notifyPositionUpdate();
    notifyListeners();
  }

  /// Seeks directly to discrete fix index.
  void seekToIndex(int index) {
    if (_positions.isEmpty) return;
    final clamped = index.clamp(0, _positions.length - 1);
    final progress = _positions.length > 1
        ? clamped / (_positions.length - 1)
        : 0.0;
    seekToProgress(progress);
  }

  /// Steps forward to next discrete GPS point.
  void stepForward() {
    seekToIndex(currentFloorIndex + 1);
  }

  /// Steps backward to previous discrete GPS point.
  void stepBackward() {
    seekToIndex(currentFloorIndex - 1);
  }

  /// User started dragging the scrub slider.
  void onScrubStart() {
    if (_status == PlaybackStatus.playing) {
      _wasPlayingBeforeScrub = true;
      pause();
    } else {
      _wasPlayingBeforeScrub = false;
    }
  }

  /// User is actively dragging slider.
  void onScrubUpdate(double progress) {
    seekToProgress(progress);
  }

  /// User released scrub slider.
  void onScrubEnd() {
    if (_wasPlayingBeforeScrub && _status != PlaybackStatus.completed) {
      _wasPlayingBeforeScrub = false;
      play();
    }
  }

  // --- Speed & Camera Follow ---

  /// Sets the playback speed multiplier.
  void setSpeed(PlaybackSpeed speed) {
    _speed = speed;
    notifyListeners();
  }

  /// Toggles camera follow mode.
  void toggleCameraFollow() {
    _isCameraFollowEnabled = !_isCameraFollowEnabled;
    notifyListeners();
  }

  void _notifyPositionUpdate() {
    final coord = currentInterpolatedCoordinate;
    if (coord != null) {
      onPositionUpdated?.call(coord, currentBearing);
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stopTicker();
    super.dispose();
  }
}
