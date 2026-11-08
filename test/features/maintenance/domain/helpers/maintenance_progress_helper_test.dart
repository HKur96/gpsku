import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/domain/helpers/maintenance_progress_helper.dart';

void main() {
  group('MaintenanceProgressHelper Domain Tests', () {
    const tDistanceMaintenance = MaintenanceModel(
      id: 1,
      name: 'Ganti Oli 5000 km',
      type: 'totalDistance',
      start: 10000000.0, // Baseline: 10,000 km
      period: 5000000.0, // Interval: 5,000 km
    );

    const tHoursMaintenance = MaintenanceModel(
      id: 2,
      name: 'Servis Mesin 100 Jam',
      type: 'hours',
      start: 0.0,
      period: 360000000.0, // 100 hours in ms
    );

    test('TC-MPH-01: Distance-based calculation: Normal alert (< 90%)', () {
      // Vehicle is at 13,000 km (3,000 km completed out of 5,000 km = 60%)
      final result = MaintenanceProgressHelper.calculate(
        maintenance: tDistanceMaintenance,
        currentValue: 13000000.0,
      );

      expect(result.currentValue, equals(13000000.0));
      expect(result.targetValue, equals(15000000.0));
      expect(result.remainingValue, equals(2000000.0)); // 2,000 km remaining
      expect(result.remainingDistanceKm, equals(2000.0));
      expect(result.currentDistanceKm, equals(13000.0));
      expect(result.targetDistanceKm, equals(15000.0));
      expect(result.progressRatio, closeTo(0.6, 0.001));
      expect(result.alertLevel, equals(MaintenanceAlertLevel.normal));
      expect(result.isNormal, isTrue);
      expect(result.isWarning, isFalse);
      expect(result.isOverdue, isFalse);
      expect(result.percentageLabel, equals('60.0%'));
    });

    test(
      'TC-MPH-02: Distance-based calculation: Warning alert (>= 90% and < 100%)',
      () {
        // Vehicle is at 14,600 km (4,600 km completed out of 5,000 km = 92%)
        final result = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue: 14600000.0,
        );

        expect(result.remainingValue, equals(400000.0)); // 400 km remaining
        expect(result.remainingDistanceKm, equals(400.0));
        expect(result.progressRatio, closeTo(0.92, 0.001));
        expect(result.alertLevel, equals(MaintenanceAlertLevel.warning));
        expect(result.isWarning, isTrue);
        expect(result.isNormal, isFalse);
        expect(result.isOverdue, isFalse);
      },
    );

    test('TC-MPH-03: Distance-based calculation: Overdue alert (>= 100%)', () {
      // Vehicle is at 15,200 km (200 km past due target)
      final result = MaintenanceProgressHelper.calculate(
        maintenance: tDistanceMaintenance,
        currentValue: 15200000.0,
      );

      expect(result.remainingValue, equals(-200000.0)); // -200 km
      expect(result.remainingDistanceKm, equals(-200.0));
      expect(result.progressRatio, closeTo(1.04, 0.001));
      expect(result.alertLevel, equals(MaintenanceAlertLevel.overdue));
      expect(result.isOverdue, isTrue);
      expect(result.isWarning, isFalse);
      expect(result.isNormal, isFalse);
    });

    test('TC-MPH-04: Hours-based calculation: ms to hours evaluation', () {
      // 95 hours operational (95% -> warning)
      final currentMs = 95 * 3600000.0;
      final result = MaintenanceProgressHelper.calculate(
        maintenance: tHoursMaintenance,
        currentValue: currentMs,
      );

      expect(result.currentEngineHours, closeTo(95.0, 0.001));
      expect(result.targetEngineHours, closeTo(100.0, 0.001));
      expect(result.remainingEngineHours, closeTo(5.0, 0.001));
      expect(result.progressRatio, closeTo(0.95, 0.001));
      expect(result.alertLevel, equals(MaintenanceAlertLevel.warning));
      expect(result.isWarning, isTrue);
    });

    test(
      'TC-MPH-05: Time-based calculation: epoch timestamps and remaining days',
      () {
        final now = DateTime(2026, 11, 8, 12, 0);
        final startTime = now.subtract(const Duration(days: 25)); // 25 days ago
        const periodDays = 30; // 30-day inspection cycle

        final timeMaintenance = MaintenanceModel(
          id: 3,
          name: 'Inspeksi Bulanan',
          type: 'fixTime',
          start: startTime.millisecondsSinceEpoch.toDouble(),
          period: periodDays * 86400000.0,
        );

        final result = MaintenanceProgressHelper.calculate(
          maintenance: timeMaintenance,
          currentValue: now.millisecondsSinceEpoch.toDouble(),
        );

        expect(result.remainingDays, closeTo(5.0, 0.01)); // 5 days remaining
        expect(result.progressRatio, closeTo(25 / 30, 0.01));
        expect(result.alertLevel, equals(MaintenanceAlertLevel.normal));
      },
    );

    test(
      'TC-MPH-06: Custom warning threshold (80%) triggers warning earlier',
      () {
        // 85% progress: normal with default 90% threshold, but warning with 80% threshold
        final resultDefault = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue: 14250000.0, // 85%
        );
        expect(resultDefault.alertLevel, equals(MaintenanceAlertLevel.normal));

        final resultCustom = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue: 14250000.0,
          warningThreshold: 0.8,
        );
        expect(resultCustom.alertLevel, equals(MaintenanceAlertLevel.warning));
      },
    );

    test(
      'TC-MPH-07: extractValue extracts from position attributes fallback hierarchy',
      () {
        final posTotalDist = PositionModel(
          id: 1,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime(2026, 11, 8, 10, 0),
          latitude: -6.2,
          longitude: 106.8,
          attributes: {'totalDistance': 5500000.0, 'odometer': 5000000.0},
        );

        final posOdoOnly = PositionModel(
          id: 2,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime(2026, 11, 8, 10, 0),
          latitude: -6.2,
          longitude: 106.8,
          attributes: {'odometer': 4200000.0},
        );

        final posHours = PositionModel(
          id: 3,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime(2026, 11, 8, 10, 0),
          latitude: -6.2,
          longitude: 106.8,
          attributes: {'hours': 18000000.0}, // 5 hours in ms
        );

        expect(
          MaintenanceProgressHelper.extractValue(
            tDistanceMaintenance,
            position: posTotalDist,
          ),
          equals(5500000.0),
        );

        expect(
          MaintenanceProgressHelper.extractValue(
            tDistanceMaintenance,
            position: posOdoOnly,
          ),
          equals(4200000.0),
        );

        expect(
          MaintenanceProgressHelper.extractValue(
            tHoursMaintenance,
            position: posHours,
          ),
          equals(18000000.0),
        );
      },
    );

    test(
      'TC-MPH-08: calculateFromPosition calculates progress directly from PositionModel',
      () {
        final pos = PositionModel(
          id: 99,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime(2026, 11, 8, 10, 0),
          latitude: -6.2,
          longitude: 106.8,
          attributes: {'totalDistance': 14800000.0}, // 4,800 km = 96%
        );

        final result = MaintenanceProgressHelper.calculateFromPosition(
          maintenance: tDistanceMaintenance,
          position: pos,
        );

        expect(result.remainingDistanceKm, equals(200.0));
        expect(result.alertLevel, equals(MaintenanceAlertLevel.warning));
      },
    );

    test(
      'TC-MPH-09: Handles currentValue < start gracefully without negative progress ratio',
      () {
        final result = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue:
              8000000.0, // 8,000 km while baseline start was 10,000 km
        );

        expect(result.progressRatio, equals(0.0));
        expect(
          result.remainingDistanceKm,
          equals(7000.0),
        ); // 15,000 - 8,000 = 7,000
        expect(result.alertLevel, equals(MaintenanceAlertLevel.normal));
      },
    );

    test(
      'TC-MPH-10: Handles zero period gracefully without division by zero',
      () {
        const zeroPeriod = MaintenanceModel(
          id: 5,
          name: 'One-time Check',
          type: 'totalDistance',
          start: 1000.0,
          period: 0.0,
        );

        final resultBefore = MaintenanceProgressHelper.calculate(
          maintenance: zeroPeriod,
          currentValue: 500.0,
        );
        expect(resultBefore.progressRatio, equals(0.0));
        expect(resultBefore.alertLevel, equals(MaintenanceAlertLevel.normal));

        final resultAfter = MaintenanceProgressHelper.calculate(
          maintenance: zeroPeriod,
          currentValue: 1200.0,
        );
        expect(resultAfter.progressRatio, equals(1.0));
        expect(resultAfter.alertLevel, equals(MaintenanceAlertLevel.overdue));
      },
    );

    test(
      'TC-MPH-11: Value equality and hashCode on MaintenanceProgressResult',
      () {
        final res1 = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue: 12000000.0,
        );
        final res2 = MaintenanceProgressHelper.calculate(
          maintenance: tDistanceMaintenance,
          currentValue: 12000000.0,
        );

        expect(res1, equals(res2));
        expect(res1.hashCode, equals(res2.hashCode));
        expect(res1.toString(), contains('Ganti Oli 5000 km'));
      },
    );
  });
}
