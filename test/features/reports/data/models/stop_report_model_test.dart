import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';

void main() {
  group('StopReportModel Unit Tests', () {
    final tStartTime = DateTime.parse('2026-11-08T10:00:00.000Z');
    final tEndTime = DateTime.parse('2026-11-08T10:45:00.000Z');

    final tFullJson = <String, dynamic>{
      'deviceId': 15,
      'deviceName': 'Van Delivery 01',
      'distance': 0.0,
      'averageSpeed': 0.0,
      'maxSpeed': 0.0,
      'spentFuel': 0.5,
      'startOdometer': 85400.0,
      'endOdometer': 85400.0,
      'startTime': '2026-11-08T10:00:00.000Z',
      'endTime': '2026-11-08T10:45:00.000Z',
      'positionId': 2005,
      'latitude': -6.1751,
      'longitude': 106.8650,
      'address': 'Gudang Cempaka Putih, Jakarta',
      'duration': 2700000, // 45 minutes in ms
      'engineHours': 900000, // 15 minutes idle idling
    };

    test('TC-STOP-01: Deserializes complete JSON correctly', () {
      final model = StopReportModel.fromJson(tFullJson);

      expect(model.deviceId, 15);
      expect(model.deviceName, 'Van Delivery 01');
      expect(model.distance, 0.0);
      expect(model.averageSpeed, 0.0);
      expect(model.maxSpeed, 0.0);
      expect(model.spentFuel, 0.5);
      expect(model.startOdometer, 85400.0);
      expect(model.endOdometer, 85400.0);
      expect(model.startTime, tStartTime);
      expect(model.endTime, tEndTime);
      expect(model.positionId, 2005);
      expect(model.latitude, -6.1751);
      expect(model.longitude, 106.8650);
      expect(model.address, 'Gudang Cempaka Putih, Jakarta');
      expect(model.duration, 2700000);
      expect(model.engineHours, 900000);
    });

    test('TC-STOP-02: Handles minimal JSON with null attributes safely', () {
      final minimalJson = <String, dynamic>{
        'deviceId': 3,
        'distance': 0.0,
        'averageSpeed': 0.0,
        'maxSpeed': 0.0,
        'startTime': '2026-11-08T00:00:00.000Z',
        'endTime': '2026-11-08T00:10:00.000Z',
        'latitude': -6.12,
        'longitude': 106.78,
        'duration': 600000,
        'engineHours': 0,
      };

      final model = StopReportModel.fromJson(minimalJson);

      expect(model.deviceId, 3);
      expect(model.deviceName, isNull);
      expect(model.positionId, isNull);
      expect(model.address, isNull);
      expect(model.spentFuel, isNull);
      expect(model.duration, 600000);
      expect(model.engineHours, 0);
    });

    test(
      'TC-STOP-03: Clamps negative distance, speeds, duration, engineHours to 0',
      () {
        final negativeJson = <String, dynamic>{
          'deviceId': 3,
          'distance': -100.0,
          'averageSpeed': -5.0,
          'maxSpeed': -1.0,
          'startTime': '2026-11-08T00:00:00.000Z',
          'endTime': '2026-11-08T00:10:00.000Z',
          'latitude': -6.12,
          'longitude': 106.78,
          'duration': -5000,
          'engineHours': -1000,
        };

        final model = StopReportModel.fromJson(negativeJson);

        expect(model.distance, 0.0);
        expect(model.averageSpeed, 0.0);
        expect(model.maxSpeed, 0.0);
        expect(model.duration, 0);
        expect(model.engineHours, 0);
      },
    );

    test(
      'TC-STOP-04: Converts duration and engineHours to Duration objects',
      () {
        final model = StopReportModel.fromJson(tFullJson);

        expect(model.durationTime, const Duration(minutes: 45));
        expect(model.engineHoursTime, const Duration(minutes: 15));
      },
    );

    test('TC-STOP-05: Computes distance in kilometers correctly', () {
      final model = StopReportModel.fromJson({
        ...tFullJson,
        'distance': 1200.0,
      });

      expect(model.distanceKm, 1.2);
    });

    test('TC-STOP-06: Serializes to JSON preserving expected structure', () {
      final model = StopReportModel.fromJson(tFullJson);
      final json = model.toJson();

      expect(json['deviceId'], 15);
      expect(json['deviceName'], 'Van Delivery 01');
      expect(json['positionId'], 2005);
      expect(json['address'], 'Gudang Cempaka Putih, Jakarta');
      expect(json['duration'], 2700000);
      expect(json['engineHours'], 900000);
    });

    test('TC-STOP-07: Value equality and hashCode work correctly', () {
      final model1 = StopReportModel.fromJson(tFullJson);
      final model2 = StopReportModel.fromJson(tFullJson);
      final model3 = StopReportModel.fromJson({
        ...tFullJson,
        'positionId': 9999,
      });

      expect(model1, equals(model2));
      expect(model1.hashCode, equals(model2.hashCode));
      expect(model1, isNot(equals(model3)));
    });

    test('TC-STOP-08: Safely parses string numbers and dates', () {
      final stringJson = <String, dynamic>{
        'deviceId': '15',
        'distance': '0.0',
        'averageSpeed': '0.0',
        'maxSpeed': '0.0',
        'spentFuel': '0.5',
        'startOdometer': '85400.0',
        'endOdometer': '85400.0',
        'startTime': '2026-11-08T10:00:00.000Z',
        'endTime': '2026-11-08T10:45:00.000Z',
        'positionId': '2005',
        'latitude': '-6.1751',
        'longitude': '106.8650',
        'duration': '2700000',
        'engineHours': '900000',
      };

      final model = StopReportModel.fromJson(stringJson);

      expect(model.deviceId, 15);
      expect(model.positionId, 2005);
      expect(model.latitude, -6.1751);
      expect(model.longitude, 106.8650);
      expect(model.duration, 2700000);
      expect(model.engineHours, 900000);
    });
  });
}
