import 'package:flutter/foundation.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../data/models/maintenance_model.dart';

/// Alert severity level for vehicle maintenance scheduling.
enum MaintenanceAlertLevel {
  /// Well within safe threshold (< 90% of service interval).
  normal,

  /// Nearing service target (>= 90% and < 100% of service interval).
  warning,

  /// Service limit reached or exceeded (>= 100% of service interval).
  overdue,
}

/// Evaluated telemetry progress and countdown result for a specific [maintenance] item.
@immutable
class MaintenanceProgressResult {
  /// Associated maintenance definition.
  final MaintenanceModel maintenance;

  /// Current telemetry reading in raw backend units (meters, ms, or timestamp).
  final double currentValue;

  /// Target value when maintenance is due in raw backend units (`start + period`).
  final double targetValue;

  /// Remaining margin until due (`targetValue - currentValue`).
  /// Negative when [isOverdue] is true.
  final double remainingValue;

  /// Progress fraction completed within current interval (0.0 to 1.0, or > 1.0 if overdue).
  final double progressRatio;

  /// Current alert level.
  final MaintenanceAlertLevel alertLevel;

  const MaintenanceProgressResult({
    required this.maintenance,
    required this.currentValue,
    required this.targetValue,
    required this.remainingValue,
    required this.progressRatio,
    required this.alertLevel,
  });

  /// True when current telemetry has reached or exceeded due target.
  bool get isOverdue => alertLevel == MaintenanceAlertLevel.overdue;

  /// True when current telemetry is within warning window (>= 90% and < 100%).
  bool get isWarning => alertLevel == MaintenanceAlertLevel.warning;

  /// True when within safe normal operating limits.
  bool get isNormal => alertLevel == MaintenanceAlertLevel.normal;

  /// Remaining distance in meters.
  double get remainingDistanceMeters => remainingValue;

  /// Remaining distance in kilometers (km).
  double get remainingDistanceKm => remainingValue / 1000.0;

  /// Remaining engine operational duration in hours (h).
  double get remainingEngineHours => remainingValue / 3600000.0;

  /// Remaining duration in days.
  double get remainingDays => remainingValue / 86400000.0;

  /// Current value in kilometers (km).
  double get currentDistanceKm => currentValue / 1000.0;

  /// Current value in hours (h).
  double get currentEngineHours => currentValue / 3600000.0;

  /// Target value in kilometers (km).
  double get targetDistanceKm => targetValue / 1000.0;

  /// Target value in hours (h).
  double get targetEngineHours => targetValue / 3600000.0;

  /// Progress as a percentage (0.0% to 100.0%+).
  double get progressPercent => progressRatio * 100.0;

  /// Human-readable percentage label (e.g. "85.0%", "104.2%").
  String get percentageLabel =>
      '${progressPercent.clamp(0.0, 999.0).toStringAsFixed(1)}%';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceProgressResult &&
          runtimeType == other.runtimeType &&
          maintenance == other.maintenance &&
          currentValue == other.currentValue &&
          targetValue == other.targetValue &&
          remainingValue == other.remainingValue &&
          progressRatio == other.progressRatio &&
          alertLevel == other.alertLevel;

  @override
  int get hashCode =>
      maintenance.hashCode ^
      currentValue.hashCode ^
      targetValue.hashCode ^
      remainingValue.hashCode ^
      progressRatio.hashCode ^
      alertLevel.hashCode;

  @override
  String toString() =>
      'MaintenanceProgressResult(name: "${maintenance.name}", remaining: $remainingValue, alert: $alertLevel, ratio: $progressRatio)';
}

/// Pure Dart domain helper for computing remaining distance/hours,
/// progress ratio, and alert levels for Traccar maintenance schedules.
class MaintenanceProgressHelper {
  MaintenanceProgressHelper._();

  /// Default threshold (90%) where warning alert level is triggered.
  static const double defaultWarningThreshold = 0.9;

  /// Extracts the raw telemetry value from a [position] or [attributes] map
  /// corresponding to [maintenance.type].
  static double extractValue(
    MaintenanceModel maintenance, {
    PositionModel? position,
    Map<String, dynamic>? attributes,
  }) {
    final attrs = attributes ?? position?.attributes ?? const {};

    if (maintenance.isDistanceBased) {
      final totalDist = (attrs['totalDistance'] as num?)?.toDouble();
      if (totalDist != null) return totalDist;

      final odo = (attrs['odometer'] as num?)?.toDouble();
      if (odo != null) return odo;

      final svcOdo = (attrs['serviceOdometer'] as num?)?.toDouble();
      if (svcOdo != null) return svcOdo;

      return 0.0;
    }

    if (maintenance.isHoursBased) {
      final hours = (attrs['hours'] as num?)?.toDouble();
      return hours ?? 0.0;
    }

    if (maintenance.isTimeBased) {
      if (position != null) {
        return position.fixTime.millisecondsSinceEpoch.toDouble();
      }
      final rawTime = attrs[maintenance.type];
      if (rawTime is int) return rawTime.toDouble();
      if (rawTime is String) {
        final parsed = DateTime.tryParse(rawTime);
        if (parsed != null) return parsed.millisecondsSinceEpoch.toDouble();
      }
      return 0.0;
    }

    final rawVal = (attrs[maintenance.type] as num?)?.toDouble();
    return rawVal ?? 0.0;
  }

  /// Calculates maintenance status, target, and remaining metrics from [currentValue].
  ///
  /// * Distance formula: `remainingDistance = (start + period) - currentDeviceTotalDistance`.
  /// * Hours formula: `remainingHours = (start + period) - currentDeviceEngineHours`.
  static MaintenanceProgressResult calculate({
    required MaintenanceModel maintenance,
    required double currentValue,
    double warningThreshold = defaultWarningThreshold,
  }) {
    final targetValue = maintenance.start + maintenance.period;
    final remainingValue = targetValue - currentValue;

    double progressRatio;
    if (maintenance.period <= 0) {
      progressRatio = currentValue >= maintenance.start ? 1.0 : 0.0;
    } else {
      if (currentValue < maintenance.start) {
        progressRatio = 0.0;
      } else {
        progressRatio = (currentValue - maintenance.start) / maintenance.period;
      }
    }

    MaintenanceAlertLevel alertLevel;
    if (currentValue >= targetValue || remainingValue <= 0) {
      alertLevel = MaintenanceAlertLevel.overdue;
    } else if (progressRatio >= warningThreshold) {
      alertLevel = MaintenanceAlertLevel.warning;
    } else {
      alertLevel = MaintenanceAlertLevel.normal;
    }

    return MaintenanceProgressResult(
      maintenance: maintenance,
      currentValue: currentValue,
      targetValue: targetValue,
      remainingValue: remainingValue,
      progressRatio: progressRatio,
      alertLevel: alertLevel,
    );
  }

  /// Convenience calculation directly extracting telemetry from [position].
  static MaintenanceProgressResult calculateFromPosition({
    required MaintenanceModel maintenance,
    required PositionModel position,
    double warningThreshold = defaultWarningThreshold,
  }) {
    final currentValue = extractValue(maintenance, position: position);
    return calculate(
      maintenance: maintenance,
      currentValue: currentValue,
      warningThreshold: warningThreshold,
    );
  }
}

