import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../../reports/presentation/playback/route_geodesic_helper.dart';
import '../../data/models/osmand_transport_diagnostics.dart';
import '../../data/models/telemetry_packet_model.dart';
import '../../domain/repositories/telemetry_emulator_repository.dart';

/// Status of the active telemetry simulation session.
enum EmulatorSimulationStatus { idle, sendingSingleFix, simulating, paused }

/// Status of the Traccar OsmAnd endpoint reachability probe.
enum OsmandPortStatus {
  unknown,
  probing,
  reachable,
  reachableViaFallback,
  unreachable,
}

/// State management for the GPS Telemetry Emulator and Route Simulator Engine.
class TelemetryEmulatorProvider extends ChangeNotifier {
  final TelemetryEmulatorRepository repository;
  final AuthProvider? authProvider;

  TelemetryEmulatorProvider({required this.repository, this.authProvider}) {
    authProvider?.addListener(_onAuthChanged);
  }

  /// Validates WGS-84 geographic coordinates without rejecting (0.0, 0.0).
  /// Rejects NaN, Infinity, |lat| > 90, and |lon| > 180.
  static bool isValidCoordinate(double lat, double lon) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) {
      return false;
    }
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  bool get isDeveloperAuthorized =>
      authProvider == null ? true : authProvider!.canAccessDeveloperTools;

  EmulatorSimulationStatus _simulationStatus = EmulatorSimulationStatus.idle;
  EmulatorSimulationStatus get simulationStatus => _simulationStatus;

  OsmandPortStatus _portStatus = OsmandPortStatus.unknown;
  OsmandPortStatus get portStatus => _portStatus;

  bool get isPortConnected =>
      _portStatus == OsmandPortStatus.reachable ||
      _portStatus == OsmandPortStatus.reachableViaFallback;

  OsmandTransportDiagnostics? _lastTransportDiagnostics;
  OsmandTransportDiagnostics? get lastTransportDiagnostics =>
      _lastTransportDiagnostics;

  bool _isMapPickMode = false;
  bool get isMapPickMode => _isMapPickMode;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  int? _lastStatusCode;
  int? get lastStatusCode => _lastStatusCode;

  DateTime? _lastTransmissionTime;
  DateTime? get lastTransmissionTime => _lastTransmissionTime;

  int _transmissionSuccessCount = 0;
  int get transmissionSuccessCount => _transmissionSuccessCount;

  int _transmissionFailureCount = 0;
  int get transmissionFailureCount => _transmissionFailureCount;

  // Active packet telemetry parameters
  String _targetUniqueId = '';
  String get targetUniqueId => _targetUniqueId;

  String? _targetDeviceName;
  String? get targetDeviceName => _targetDeviceName;

  double _currentLat = -6.2088; // Default center (Jakarta)
  double get currentLat => _currentLat;

  double _currentLon = 106.8456;
  double get currentLon => _currentLon;

  double _currentSpeed = 20.0; // km/h
  double get currentSpeed => _currentSpeed;

  double _currentBearing = 90.0; // degrees (0.0 to 360.0)
  double get currentBearing => _currentBearing;

  double _currentAltitude = 25.0; // meters
  double get currentAltitude => _currentAltitude;

  double _currentBattery = 85.0; // %
  double get currentBattery => _currentBattery;

  bool _isIgnitionOn = true;
  bool get isIgnitionOn => _isIgnitionOn;

  final double _currentAccuracy = 3.0; // meters
  double get currentAccuracy => _currentAccuracy;

  final double _currentHdop = 1.0;
  double get currentHdop => _currentHdop;

  final bool _isValid = true;
  bool get isValid => _isValid;

  String? _driverUniqueId;
  String? get driverUniqueId => _driverUniqueId;

  // Simulation engine settings
  Duration _simulationInterval = const Duration(seconds: 2);
  Duration get simulationInterval => _simulationInterval;

  Timer? _simulationTimer;
  CancelToken? _activeCancelToken;
  bool _isTransmittingStep = false;
  bool _isDisposed = false;
  String? _activeCustomHost;
  int? _activeCustomPort;
  List<LatLng> _simulationWaypoints = [];
  List<LatLng> get simulationWaypoints =>
      List.unmodifiable(_simulationWaypoints);
  int _currentWaypointIndex = 0;
  int get currentWaypointIndex => _currentWaypointIndex;

  bool get isSimulating =>
      _simulationStatus == EmulatorSimulationStatus.simulating;
  bool get isPaused => _simulationStatus == EmulatorSimulationStatus.paused;
  bool get isBusy =>
      _simulationStatus == EmulatorSimulationStatus.sendingSingleFix;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    if (!isDeveloperAuthorized) {
      if (_isMapPickMode ||
          isSimulating ||
          isPaused ||
          _targetUniqueId.isNotEmpty ||
          _lastTransportDiagnostics != null) {
        clearState();
      }
    }
  }

  OsmandTransportDiagnostics? _readRepositoryDiagnostics() {
    if (repository case final OsmandTransportDiagnosticsProvider diagProvider) {
      return diagProvider.lastTransportDiagnostics;
    }
    return null;
  }

  void _cancelActiveRequests() {
    if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
      _activeCancelToken!.cancel('Telemetry emulator operation cancelled');
    }
    _activeCancelToken = null;
  }

  /// Toggles interactive map-tap coordinate picking mode.
  /// Enforces developer authorization before enabling.
  bool setMapPickMode(bool enabled) {
    if (enabled && !isDeveloperAuthorized) {
      _lastErrorMessage =
          'Akses Mode Pengembang ditolak: hanya Administrator aktif (non-readonly) yang diizinkan.';
      _safeNotify();
      return false;
    }
    _isMapPickMode = enabled;
    if (enabled) {
      _lastErrorMessage = null;
    }
    _safeNotify();
    return true;
  }

  /// Injects coordinates from a map tap into emulator state WITHOUT transmitting telemetry.
  /// Accepts valid WGS-84 coordinates including (0.0, 0.0), while rejecting NaN/Infinity/out-of-range.
  bool setMapPickedCoordinates(double lat, double lon) {
    if (!isDeveloperAuthorized) {
      _lastErrorMessage =
          'Akses Mode Pengembang ditolak: hanya Administrator aktif (non-readonly) yang diizinkan.';
      _safeNotify();
      return false;
    }
    if (!isValidCoordinate(lat, lon)) {
      _lastErrorMessage =
          'Koordinat peta tidak valid (Latitude -90..90, Longitude -180..180, bukan NaN/Infinity).';
      _safeNotify();
      return false;
    }
    _currentLat = lat;
    _currentLon = lon;
    _lastErrorMessage = null;
    _safeNotify();
    return true;
  }

  /// Prefills active target parameters from selected [device] and optional [lastPosition].
  /// Enforces mapping [device.uniqueId] (IMEI/Serial), NOT integer [device.id].
  void setTargetDevice(DeviceModel device, [PositionModel? lastPosition]) {
    _targetUniqueId = device.uniqueId;
    _targetDeviceName = device.name;
    if (lastPosition != null) {
      if (isValidCoordinate(lastPosition.latitude, lastPosition.longitude)) {
        _currentLat = lastPosition.latitude;
        _currentLon = lastPosition.longitude;
      }
      _currentSpeed = (lastPosition.speed * 1.852).clamp(
        0.0,
        160.0,
      ); // knots to km/h, safely bounded to UI slider max
      _currentBearing = (lastPosition.course % 360.0 + 360.0) % 360.0;
      _currentAltitude = lastPosition.altitude;
      if (lastPosition.attributes.containsKey('ignition')) {
        _isIgnitionOn = lastPosition.attributes['ignition'] == true;
      }
      final rawBatt =
          lastPosition.attributes['batteryLevel'] ??
          lastPosition.attributes['battery'];
      if (rawBatt is num) {
        _currentBattery = rawBatt.toDouble().clamp(0.0, 100.0);
      }
    }
    _safeNotify();
  }

  /// Sets manual target unique ID.
  void setTargetUniqueId(String uniqueId, [String? deviceName]) {
    _targetUniqueId = uniqueId.trim();
    if (deviceName != null) _targetDeviceName = deviceName;
    _safeNotify();
  }

  static double _normalizeLongitude(double lon) {
    if (lon >= -180.0 && lon <= 180.0) return lon;
    return ((lon + 540.0) % 360.0) - 180.0;
  }

  /// Updates current simulation coordinate (guards against NaN/Infinity).
  void updateCoordinates({required double lat, required double lon}) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) {
      return;
    }
    _currentLat = lat.clamp(-90.0, 90.0);
    _currentLon = _normalizeLongitude(lon);
    _safeNotify();
  }

  /// Updates current vehicle speed in km/h.
  void updateSpeed(double speedKmh) {
    _currentSpeed = speedKmh.clamp(0.0, 200.0);
    _safeNotify();
  }

  /// Updates vehicle heading / bearing in degrees [0, 360).
  void updateBearing(double bearing) {
    _currentBearing = (bearing % 360.0 + 360.0) % 360.0;
    _safeNotify();
  }

  /// Updates vehicle altitude in meters.
  void updateAltitude(double altitude) {
    _currentAltitude = altitude;
    _safeNotify();
  }

  /// Updates vehicle battery percentage [0, 100].
  void updateBattery(double battery) {
    _currentBattery = battery.clamp(0.0, 100.0);
    _safeNotify();
  }

  /// Sets vehicle engine ignition contact switch state.
  void setIgnition(bool ignition) {
    _isIgnitionOn = ignition;
    _safeNotify();
  }

  /// Sets active simulation timer step interval (e.g. 1s, 2s, 5s).
  void setSimulationInterval(Duration interval) {
    if (interval.inMilliseconds <= 0) return;
    _simulationInterval = interval;
    if (isSimulating) {
      _startTimer(customHost: _activeCustomHost, customPort: _activeCustomPort);
    }
    _safeNotify();
  }

  /// Sets custom waypoint route path for simulation.
  void setWaypoints(List<LatLng> waypoints) {
    _simulationWaypoints = List.of(waypoints);
    _currentWaypointIndex = 0;
    if (waypoints.isNotEmpty &&
        isValidCoordinate(
          waypoints.first.latitude,
          waypoints.first.longitude,
        )) {
      _currentLat = waypoints.first.latitude;
      _currentLon = waypoints.first.longitude;
      if (waypoints.length > 1) {
        _currentBearing = RouteGeodesicHelper.calculateBearing(
          waypoints[0],
          waypoints[1],
        );
      }
    }
    _safeNotify();
  }

  /// Clears waypoints path, falling back to constant-bearing vector simulation.
  void clearWaypoints() {
    _simulationWaypoints = [];
    _currentWaypointIndex = 0;
    _safeNotify();
  }

  /// Probes reachability of the OsmAnd endpoint (direct port 5055, HTTPS proxy, or fallback 8082).
  Future<bool> probePort({String? customHost, int? customPort}) async {
    if (!isDeveloperAuthorized) {
      _portStatus = OsmandPortStatus.unreachable;
      _lastErrorMessage =
          'Akses Mode Pengembang ditolak: hanya Administrator aktif (non-readonly) yang diizinkan.';
      _safeNotify();
      return false;
    }

    _portStatus = OsmandPortStatus.probing;
    _lastErrorMessage = null;
    _safeNotify();

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    final result = await repository.probePort(
      customHost: customHost,
      customPort: customPort,
      cancelToken: cancelToken,
    );

    if (_isDisposed) return false;

    _lastTransportDiagnostics = _readRepositoryDiagnostics();

    return result.fold(
      (failure) {
        _portStatus = OsmandPortStatus.unreachable;
        _lastErrorMessage = failure.message;
        _safeNotify();
        return false;
      },
      (reachable) {
        if (!reachable) {
          _portStatus = OsmandPortStatus.unreachable;
          _safeNotify();
          return false;
        }
        final isFallback = _lastTransportDiagnostics?.isFallbackProxy ?? false;
        _portStatus = isFallback
            ? OsmandPortStatus.reachableViaFallback
            : OsmandPortStatus.reachable;
        _safeNotify();
        return true;
      },
    );
  }

  /// Constructs [TelemetryPacketModel] from currently configured provider parameters.
  TelemetryPacketModel buildCurrentPacket() {
    return TelemetryPacketModel(
      id: _targetUniqueId,
      lat: _currentLat,
      lon: _currentLon,
      timestamp: DateTime.now(),
      speed: TelemetryPacketModel.kmhToKnots(_currentSpeed),
      bearing: _currentBearing,
      altitude: _currentAltitude,
      battery: _currentBattery,
      accuracy: _currentAccuracy,
      hdop: _currentHdop,
      charge: _isIgnitionOn,
      driverUniqueId: _driverUniqueId,
      valid: _isValid,
      attributes: {'ignition': _isIgnitionOn},
    );
  }

  /// Transmits a single telemetry fix coordinate to Traccar OsmAnd endpoint.
  Future<bool> sendSingleFix({String? customHost, int? customPort}) async {
    if (!isDeveloperAuthorized) {
      _lastErrorMessage =
          'Akses Mode Pengembang ditolak: hanya Administrator aktif (non-readonly) yang diizinkan.';
      _safeNotify();
      return false;
    }
    if (_targetUniqueId.isEmpty) {
      _lastErrorMessage = 'Unique ID perangkat target belum dipilih';
      _safeNotify();
      return false;
    }

    _simulationStatus = EmulatorSimulationStatus.sendingSingleFix;
    _lastErrorMessage = null;
    _safeNotify();

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    final packet = buildCurrentPacket();
    final result = await repository.sendTelemetry(
      packet: packet,
      customHost: customHost,
      customPort: customPort,
      cancelToken: cancelToken,
    );

    if (_isDisposed) return false;

    _simulationStatus = EmulatorSimulationStatus.idle;
    _lastTransmissionTime = DateTime.now();
    _lastTransportDiagnostics = _readRepositoryDiagnostics();

    return result.fold(
      (failure) {
        _transmissionFailureCount++;
        _lastErrorMessage = failure.message;
        _lastStatusCode = failure.statusCode ?? 500;
        _safeNotify();
        return false;
      },
      (success) {
        _transmissionSuccessCount++;
        _lastStatusCode = 200;
        final isFallback = _lastTransportDiagnostics?.isFallbackProxy ?? false;
        _portStatus = isFallback
            ? OsmandPortStatus.reachableViaFallback
            : OsmandPortStatus.reachable;
        _safeNotify();
        return true;
      },
    );
  }

  /// Starts or resumes the automated periodic path simulation engine.
  bool startSimulation({String? customHost, int? customPort}) {
    if (!isDeveloperAuthorized) {
      _lastErrorMessage =
          'Akses Mode Pengembang ditolak: hanya Administrator aktif (non-readonly) yang diizinkan.';
      _safeNotify();
      return false;
    }
    if (_targetUniqueId.isEmpty) {
      _lastErrorMessage =
          'Pilih perangkat target sebelum memulai simulasi rute';
      _safeNotify();
      return false;
    }
    if (isSimulating) return true;

    _activeCustomHost = customHost;
    _activeCustomPort = customPort;
    _simulationStatus = EmulatorSimulationStatus.simulating;
    _lastErrorMessage = null;
    _startTimer(customHost: customHost, customPort: customPort);
    _safeNotify();
    return true;
  }

  void _startTimer({String? customHost, int? customPort}) {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(_simulationInterval, (_) async {
      await _advanceAndTransmit(customHost: customHost, customPort: customPort);
    });
  }

  Future<void> _advanceAndTransmit({
    String? customHost,
    int? customPort,
  }) async {
    if (_isDisposed ||
        !isDeveloperAuthorized ||
        _simulationStatus != EmulatorSimulationStatus.simulating ||
        _isTransmittingStep) {
      return;
    }

    _isTransmittingStep = true;
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    try {
      _advancePosition();
      final packet = buildCurrentPacket();
      final result = await repository.sendTelemetry(
        packet: packet,
        customHost: customHost,
        customPort: customPort,
        cancelToken: cancelToken,
      );

      if (_isDisposed ||
          _simulationStatus != EmulatorSimulationStatus.simulating) {
        return;
      }

      _lastTransmissionTime = DateTime.now();
      _lastTransportDiagnostics = _readRepositoryDiagnostics();
      result.fold(
        (failure) {
          _transmissionFailureCount++;
          _lastErrorMessage = failure.message;
          _lastStatusCode = failure.statusCode ?? 500;
        },
        (success) {
          _transmissionSuccessCount++;
          _lastStatusCode = 200;
          final isFallback =
              _lastTransportDiagnostics?.isFallbackProxy ?? false;
          _portStatus = isFallback
              ? OsmandPortStatus.reachableViaFallback
              : OsmandPortStatus.reachable;
        },
      );
      _safeNotify();
    } finally {
      _isTransmittingStep = false;
    }
  }

  void _advancePosition() {
    if (_simulationWaypoints.length > 1) {
      // Waypoint following mode
      final nextIndex =
          (_currentWaypointIndex + 1) % _simulationWaypoints.length;
      final targetWaypoint = _simulationWaypoints[nextIndex];
      final currentPos = LatLng(_currentLat, _currentLon);

      final distToTarget = RouteGeodesicHelper.distanceBetween(
        currentPos,
        targetWaypoint,
      );
      final stepDistance =
          (_currentSpeed * 1000 / 3600) *
          (_simulationInterval.inMilliseconds / 1000);

      if (distToTarget <= stepDistance || distToTarget < 5.0) {
        _currentLat = targetWaypoint.latitude;
        _currentLon = targetWaypoint.longitude;
        _currentWaypointIndex = nextIndex;
        final followingIndex = (nextIndex + 1) % _simulationWaypoints.length;
        _currentBearing = RouteGeodesicHelper.calculateBearing(
          targetWaypoint,
          _simulationWaypoints[followingIndex],
        );
      } else {
        final fraction = (stepDistance / distToTarget).clamp(0.0, 1.0);
        final nextCoord = RouteGeodesicHelper.interpolateCoordinate(
          currentPos,
          targetWaypoint,
          fraction,
        );
        _currentLat = nextCoord.latitude;
        _currentLon = nextCoord.longitude;
        _currentBearing = RouteGeodesicHelper.calculateBearing(
          currentPos,
          targetWaypoint,
        );
      }
    } else {
      // Constant bearing & speed vector projection
      final stepDistance =
          (_currentSpeed * 1000 / 3600) *
          (_simulationInterval.inMilliseconds / 1000);
      final nextCoord = computeNextCoordinate(
        LatLng(_currentLat, _currentLon),
        stepDistance,
        _currentBearing,
      );
      _currentLat = nextCoord.latitude;
      _currentLon = nextCoord.longitude;
    }
  }

  /// Calculates next coordinate from [start] along [bearingDegrees] by [distanceMeters].
  static LatLng computeNextCoordinate(
    LatLng start,
    double distanceMeters,
    double bearingDegrees,
  ) {
    if (distanceMeters <= 0.0) return start;
    const earthRadius = RouteGeodesicHelper.earthRadiusMeters;
    final distRatio = distanceMeters / earthRadius;
    final bearingRad = bearingDegrees * math.pi / 180.0;
    final lat1 = start.latitude * math.pi / 180.0;
    final lon1 = start.longitude * math.pi / 180.0;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(distRatio) +
          math.cos(lat1) * math.sin(distRatio) * math.cos(bearingRad),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearingRad) * math.sin(distRatio) * math.cos(lat1),
          math.cos(distRatio) - math.sin(lat1) * math.sin(lat2),
        );

    final latDeg = (lat2 * 180.0 / math.pi).clamp(-90.0, 90.0);
    final lonDeg = _normalizeLongitude(lon2 * 180.0 / math.pi);
    return LatLng(latDeg, lonDeg);
  }

  /// Pauses automated path simulation without clearing coordinates.
  void pauseSimulation() {
    if (!isSimulating) return;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _cancelActiveRequests();
    _simulationStatus = EmulatorSimulationStatus.paused;
    _safeNotify();
  }

  /// Stops automated path simulation and resets status to idle.
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _cancelActiveRequests();
    _isTransmittingStep = false;
    _simulationStatus = EmulatorSimulationStatus.idle;
    _safeNotify();
  }

  /// Resets all state and cancels active timers deterministically (e.g. on logout).
  void clearState() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _cancelActiveRequests();
    _isTransmittingStep = false;
    _isMapPickMode = false;
    _activeCustomHost = null;
    _activeCustomPort = null;
    _simulationStatus = EmulatorSimulationStatus.idle;
    _portStatus = OsmandPortStatus.unknown;
    _lastTransportDiagnostics = null;
    _targetUniqueId = '';
    _targetDeviceName = null;
    _currentLat = -6.2088;
    _currentLon = 106.8456;
    _currentSpeed = 20.0;
    _currentBearing = 90.0;
    _currentAltitude = 25.0;
    _currentBattery = 85.0;
    _isIgnitionOn = true;
    _driverUniqueId = null;
    _simulationInterval = const Duration(seconds: 2);
    _transmissionSuccessCount = 0;
    _transmissionFailureCount = 0;
    _lastErrorMessage = null;
    _lastStatusCode = null;
    _lastTransmissionTime = null;
    _simulationWaypoints = [];
    _currentWaypointIndex = 0;
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    authProvider?.removeListener(_onAuthChanged);
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _cancelActiveRequests();
    super.dispose();
  }
}
