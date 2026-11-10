import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../../reports/presentation/playback/route_geodesic_helper.dart';
import '../../data/models/telemetry_packet_model.dart';
import '../../domain/repositories/telemetry_emulator_repository.dart';

/// Status of the active telemetry simulation session.
enum EmulatorSimulationStatus { idle, sendingSingleFix, simulating, paused }

/// Status of the Traccar OsmAnd port (port 5055) reachability probe.
enum OsmandPortStatus { unknown, probing, reachable, unreachable }

/// State management for the GPS Telemetry Emulator and Route Simulator Engine.
class TelemetryEmulatorProvider extends ChangeNotifier {
  final TelemetryEmulatorRepository repository;

  TelemetryEmulatorProvider({required this.repository});

  EmulatorSimulationStatus _simulationStatus = EmulatorSimulationStatus.idle;
  EmulatorSimulationStatus get simulationStatus => _simulationStatus;

  OsmandPortStatus _portStatus = OsmandPortStatus.unknown;
  OsmandPortStatus get portStatus => _portStatus;

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

  /// Prefills active target parameters from selected [device] and optional [lastPosition].
  /// Enforces mapping [device.uniqueId] (IMEI/Serial), NOT integer [device.id].
  void setTargetDevice(DeviceModel device, [PositionModel? lastPosition]) {
    _targetUniqueId = device.uniqueId;
    _targetDeviceName = device.name;
    if (lastPosition != null) {
      _currentLat = lastPosition.latitude;
      _currentLon = lastPosition.longitude;
      _currentSpeed = lastPosition.speed * 1.852; // knots to km/h
      _currentBearing = lastPosition.course;
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
    notifyListeners();
  }

  /// Sets manual target unique ID.
  void setTargetUniqueId(String uniqueId, [String? deviceName]) {
    _targetUniqueId = uniqueId.trim();
    if (deviceName != null) _targetDeviceName = deviceName;
    notifyListeners();
  }

  /// Updates current simulation coordinate.
  void updateCoordinates({required double lat, required double lon}) {
    _currentLat = lat;
    _currentLon = lon;
    notifyListeners();
  }

  /// Updates current vehicle speed in km/h.
  void updateSpeed(double speedKmh) {
    _currentSpeed = speedKmh.clamp(0.0, 200.0);
    notifyListeners();
  }

  /// Updates vehicle heading / bearing in degrees [0, 360).
  void updateBearing(double bearing) {
    _currentBearing = (bearing % 360.0 + 360.0) % 360.0;
    notifyListeners();
  }

  /// Updates vehicle altitude in meters.
  void updateAltitude(double altitude) {
    _currentAltitude = altitude;
    notifyListeners();
  }

  /// Updates vehicle battery percentage [0, 100].
  void updateBattery(double battery) {
    _currentBattery = battery.clamp(0.0, 100.0);
    notifyListeners();
  }

  /// Sets vehicle engine ignition contact switch state.
  void setIgnition(bool ignition) {
    _isIgnitionOn = ignition;
    notifyListeners();
  }

  /// Sets active simulation timer step interval (e.g. 1s, 2s, 5s).
  void setSimulationInterval(Duration interval) {
    _simulationInterval = interval;
    if (isSimulating) {
      _startTimer();
    }
    notifyListeners();
  }

  /// Sets custom waypoint route path for simulation.
  void setWaypoints(List<LatLng> waypoints) {
    _simulationWaypoints = List.of(waypoints);
    _currentWaypointIndex = 0;
    if (waypoints.isNotEmpty) {
      _currentLat = waypoints.first.latitude;
      _currentLon = waypoints.first.longitude;
      if (waypoints.length > 1) {
        _currentBearing = RouteGeodesicHelper.calculateBearing(
          waypoints[0],
          waypoints[1],
        );
      }
    }
    notifyListeners();
  }

  /// Clears waypoints path, falling back to constant-bearing vector simulation.
  void clearWaypoints() {
    _simulationWaypoints = [];
    _currentWaypointIndex = 0;
    notifyListeners();
  }

  /// Probes reachability of the OsmAnd protocol listener on port 5055.
  Future<bool> probePort({String? customHost, int? customPort}) async {
    _portStatus = OsmandPortStatus.probing;
    notifyListeners();

    final result = await repository.probePort(
      customHost: customHost,
      customPort: customPort,
    );

    return result.fold(
      (failure) {
        _portStatus = OsmandPortStatus.unreachable;
        _lastErrorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (reachable) {
        _portStatus = reachable
            ? OsmandPortStatus.reachable
            : OsmandPortStatus.unreachable;
        notifyListeners();
        return reachable;
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

  /// Transmits a single telemetry fix coordinate to Traccar OsmAnd port 5055.
  Future<bool> sendSingleFix({String? customHost, int? customPort}) async {
    if (_targetUniqueId.isEmpty) {
      _lastErrorMessage = 'Unique ID perangkat target belum dipilih';
      notifyListeners();
      return false;
    }

    _simulationStatus = EmulatorSimulationStatus.sendingSingleFix;
    _lastErrorMessage = null;
    notifyListeners();

    final packet = buildCurrentPacket();
    final result = await repository.sendTelemetry(
      packet: packet,
      customHost: customHost,
      customPort: customPort,
    );

    _simulationStatus = EmulatorSimulationStatus.idle;
    _lastTransmissionTime = DateTime.now();

    return result.fold(
      (failure) {
        _transmissionFailureCount++;
        _lastErrorMessage = failure.message;
        _lastStatusCode = failure.statusCode ?? 500;
        notifyListeners();
        return false;
      },
      (success) {
        _transmissionSuccessCount++;
        _lastStatusCode = 200;
        _portStatus = OsmandPortStatus.reachable;
        notifyListeners();
        return true;
      },
    );
  }

  /// Starts the automated periodic path simulation engine.
  void startSimulation({String? customHost, int? customPort}) {
    if (_targetUniqueId.isEmpty) {
      _lastErrorMessage =
          'Pilih perangkat target sebelum memulai simulasi rute';
      notifyListeners();
      return;
    }

    _simulationStatus = EmulatorSimulationStatus.simulating;
    _lastErrorMessage = null;
    _startTimer(customHost: customHost, customPort: customPort);
    notifyListeners();
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
    if (_simulationStatus != EmulatorSimulationStatus.simulating) return;

    _advancePosition();
    final packet = buildCurrentPacket();
    final result = await repository.sendTelemetry(
      packet: packet,
      customHost: customHost,
      customPort: customPort,
    );

    _lastTransmissionTime = DateTime.now();
    result.fold(
      (failure) {
        _transmissionFailureCount++;
        _lastErrorMessage = failure.message;
        _lastStatusCode = failure.statusCode ?? 500;
      },
      (success) {
        _transmissionSuccessCount++;
        _lastStatusCode = 200;
        _portStatus = OsmandPortStatus.reachable;
      },
    );
    notifyListeners();
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

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  /// Pauses automated path simulation without clearing coordinates.
  void pauseSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationStatus = EmulatorSimulationStatus.paused;
    notifyListeners();
  }

  /// Stops automated path simulation and resets status to idle.
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationStatus = EmulatorSimulationStatus.idle;
    notifyListeners();
  }

  /// Resets all state and cancels active timers deterministically (e.g. on logout).
  void clearState() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationStatus = EmulatorSimulationStatus.idle;
    _portStatus = OsmandPortStatus.unknown;
    _targetUniqueId = '';
    _targetDeviceName = null;
    _transmissionSuccessCount = 0;
    _transmissionFailureCount = 0;
    _lastErrorMessage = null;
    _lastStatusCode = null;
    _lastTransmissionTime = null;
    _simulationWaypoints = [];
    _currentWaypointIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    super.dispose();
  }
}
