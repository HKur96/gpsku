import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';

void main() {
  group('TripReportModel Unit Tests', () {
    final tStartTime = DateTime.parse('2026-11-08T08:00:00.000Z');
    final tEndTime = DateTime.parse('2026-11-08T09:30:00.000Z');

    final tFullJson = <String, dynamic>{
      'deviceId': 42,
      'deviceName': 'Truck Volvo FM',
      'distance': 45500.0, // meters
      'averageSpeed': 25.5, // knots
      'maxSpeed': 45.0, // knots
      'spentFuel': 12.4,
      'startOdometer': 105000.0,
      'endOdometer': 150500.0,
      'startTime': '2026-11-08T08:00:00.000Z',
      'endTime': '2026-11-08T09:30:00.000Z',
      'business': true,
      'startPositionId': 1001,
      'endPositionId': 1099,
      'startLat': -6.2088,
      'startLon': 106.8456,
      'endLat': -6.3000,
      'endLon': 106.9000,
      'startAddress': 'Jl. Sudirman, Jakarta',
      'endAddress': 'Jl. TB Simatupang, Jakarta',
      'duration': 5400000, // 90 minutes in ms
      'driverUniqueId': 'DRV-007',
      'driverName': 'Budi Santoso',
    };

    test('TC-TRIP-01: Deserializes complete JSON correctly', () {
      final model = TripReportModel.fromJson(tFullJson);

      expect(model.deviceId, 42);
      expect(model.deviceName, 'Truck Volvo FM');
      expect(model.distance, 45500.0);
      expect(model.averageSpeed, 25.5);
      expect(model.maxSpeed, 45.0);
      expect(model.spentFuel, 12.4);
      expect(model.startOdometer, 105000.0);
      expect(model.endOdometer, 150500.0);
      expect(model.startTime, tStartTime);
      expect(model.endTime, tEndTime);
      expect(model.business, isTrue);
      expect(model.startPositionId, 1001);
      expect(model.endPositionId, 1099);
      expect(model.startLat, -6.2088);
      expect(model.startLon, 106.8456);
      expect(model.endLat, -6.3000);
      expect(model.endLon, 106.9000);
      expect(model.startAddress, 'Jl. Sudirman, Jakarta');
      expect(model.endAddress, 'Jl. TB Simatupang, Jakarta');
      expect(model.duration, 5400000);
      expect(model.driverUniqueId, 'DRV-007');
      expect(model.driverName, 'Budi Santoso');
    });

    test('TC-TRIP-02: Handles minimal JSON with null attributes safely', () {
      final minimalJson = <String, dynamic>{
        'deviceId': 1,
        'distance': 0.0,
        'averageSpeed': 0.0,
        'maxSpeed': 0.0,
        'startTime': '2026-11-08T00:00:00.000Z',
        'endTime': '2026-11-08T01:00:00.000Z',
        'duration': 3600000,
      };

      final model = TripReportModel.fromJson(minimalJson);

      expect(model.deviceId, 1);
      expect(model.deviceName, isNull);
      expect(model.distance, 0.0);
      expect(model.spentFuel, isNull);
      expect(model.startAddress, isNull);
      expect(model.endAddress, isNull);
      expect(model.driverName, isNull);
      expect(model.business, isFalse);
      expect(model.duration, 3600000);
    });

    test(
      'TC-TRIP-03: Clamps negative averageSpeed, maxSpeed, and distance to 0.0',
      () {
        final negativeJson = <String, dynamic>{
          'deviceId': 1,
          'distance': -500.0,
          'averageSpeed': -10.5,
          'maxSpeed': -2.0,
          'startTime': '2026-11-08T00:00:00.000Z',
          'endTime': '2026-11-08T01:00:00.000Z',
          'duration': -1000,
        };

        final model = TripReportModel.fromJson(negativeJson);

        expect(model.distance, 0.0);
        expect(model.averageSpeed, 0.0);
        expect(model.maxSpeed, 0.0);
        expect(model.duration, 0);
      },
    );

    test(
      'TC-TRIP-04: Computes speed in km/h correctly (1 knot = 1.852 km/h)',
      () {
        final model = TripReportModel.fromJson(tFullJson);

        expect(model.speedKmh, closeTo(25.5 * 1.852, 0.001));
        expect(model.maxSpeedKmh, closeTo(45.0 * 1.852, 0.001));
      },
    );

    test('TC-TRIP-05: Computes distance in kilometers correctly', () {
      final model = TripReportModel.fromJson(tFullJson);

      expect(model.distanceKm, 45.5);
    });

    test(
      'TC-TRIP-06: Converts duration in milliseconds to Duration object',
      () {
        final model = TripReportModel.fromJson(tFullJson);

        expect(model.durationTime, const Duration(minutes: 90));
      },
    );

    test('TC-TRIP-07: Serializes to JSON preserving expected structure', () {
      final model = TripReportModel.fromJson(tFullJson);
      final json = model.toJson();

      expect(json['deviceId'], 42);
      expect(json['deviceName'], 'Truck Volvo FM');
      expect(json['distance'], 45500.0);
      expect(json['business'], isTrue);
      expect(json['startAddress'], 'Jl. Sudirman, Jakarta');
      expect(json['driverName'], 'Budi Santoso');
      expect(json['duration'], 5400000);
    });

    test('TC-TRIP-08: Value equality and hashCode work correctly', () {
      final model1 = TripReportModel.fromJson(tFullJson);
      final model2 = TripReportModel.fromJson(tFullJson);
      final model3 = TripReportModel.fromJson({...tFullJson, 'deviceId': 99});

      expect(model1, equals(model2));
      expect(model1.hashCode, equals(model2.hashCode));
      expect(model1, isNot(equals(model3)));
    });

    test('TC-TRIP-09: Safely parses string numbers and dates', () {
      final stringJson = <String, dynamic>{
        'deviceId': '42',
        'distance': '12500.5',
        'averageSpeed': '20.2',
        'maxSpeed': '35.8',
        'spentFuel': '5.2',
        'startOdometer': '50000.0',
        'endOdometer': '62500.5',
        'startTime': '2026-11-08T08:00:00.000Z',
        'endTime': '2026-11-08T09:00:00.000Z',
        'startPositionId': '501',
        'endPositionId': '550',
        'startLat': '-6.2',
        'startLon': '106.8',
        'endLat': '-6.3',
        'endLon': '106.9',
        'duration': '3600000',
      };

      final model = TripReportModel.fromJson(stringJson);

      expect(model.deviceId, 42);
      expect(model.distance, 12500.5);
      expect(model.averageSpeed, 20.2);
      expect(model.maxSpeed, 35.8);
      expect(model.spentFuel, 5.2);
      expect(model.startPositionId, 501);
      expect(model.startLat, -6.2);
      expect(model.duration, 3600000);
    });
  });
}
