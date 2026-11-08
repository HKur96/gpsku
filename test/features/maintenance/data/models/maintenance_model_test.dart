import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';

void main() {
  group('MaintenanceModel Unit Tests', () {
    const tAttributes = {'cost': 150000, 'vendor': 'Bengkel Resmi'};

    const tMaintenance = MaintenanceModel(
      id: 101,
      name: 'Ganti Oli Mesin',
      type: 'totalDistance',
      start: 10000000.0, // 10,000 km in meters
      period: 5000000.0, // 5,000 km in meters
      attributes: tAttributes,
    );

    test('TC-MM-01: Deserializes full MaintenanceModel from Traccar JSON map', () {
      final json = {
        'id': 101,
        'name': 'Ganti Oli Mesin',
        'type': 'totalDistance',
        'start': 10000000,
        'period': 5000000,
        'attributes': {'cost': 150000, 'vendor': 'Bengkel Resmi'},
      };

      final model = MaintenanceModel.fromJson(json);

      expect(model.id, equals(101));
      expect(model.name, equals('Ganti Oli Mesin'));
      expect(model.type, equals('totalDistance'));
      expect(model.start, equals(10000000.0));
      expect(model.period, equals(5000000.0));
      expect(model.attributes['vendor'], equals('Bengkel Resmi'));
    });

    test('TC-MM-02: Handles missing/null values with safe defaults', () {
      final json = <String, dynamic>{'name': 'Jadwal Tanpa ID'};

      final model = MaintenanceModel.fromJson(json);

      expect(model.id, equals(0));
      expect(model.name, equals('Jadwal Tanpa ID'));
      expect(model.type, equals('totalDistance'));
      expect(model.start, equals(0.0));
      expect(model.period, equals(0.0));
      expect(model.attributes, isEmpty);
    });

    test('TC-MM-03: Serializes MaintenanceModel to valid Traccar REST JSON map', () {
      final json = tMaintenance.toJson();

      expect(json['id'], equals(101));
      expect(json['name'], equals('Ganti Oli Mesin'));
      expect(json['type'], equals('totalDistance'));
      expect(json['start'], equals(10000000.0));
      expect(json['period'], equals(5000000.0));
      expect(json['attributes'], equals(tAttributes));
    });

    test('TC-MM-04: copyWith returns new instance with updated properties', () {
      final updated = tMaintenance.copyWith(
        name: 'Ganti Oli Sintetis',
        period: 7500000.0,
      );

      expect(updated.id, equals(101));
      expect(updated.name, equals('Ganti Oli Sintetis'));
      expect(updated.period, equals(7500000.0));
      expect(updated.start, equals(10000000.0));
    });

    test('TC-MM-05: Value equality and hashCode', () {
      const clone = MaintenanceModel(
        id: 101,
        name: 'Ganti Oli Mesin',
        type: 'totalDistance',
        start: 10000000.0,
        period: 5000000.0,
        attributes: {'cost': 150000, 'vendor': 'Bengkel Resmi'},
      );

      expect(tMaintenance, equals(clone));
      expect(tMaintenance.hashCode, equals(clone.hashCode));

      final different = tMaintenance.copyWith(id: 102);
      expect(tMaintenance, isNot(equals(different)));
    });

    test('TC-MM-06: Type classification getters identify distance, hours, and time', () {
      const dist1 = MaintenanceModel(
        id: 1,
        name: 'Odo',
        type: 'odometer',
        start: 0,
        period: 1000,
      );
      const dist2 = MaintenanceModel(
        id: 2,
        name: 'Total',
        type: 'totalDistance',
        start: 0,
        period: 1000,
      );
      const hours = MaintenanceModel(
        id: 3,
        name: 'Hours',
        type: 'hours',
        start: 0,
        period: 3600000,
      );
      const time = MaintenanceModel(
        id: 4,
        name: 'Date',
        type: 'serverTime',
        start: 0,
        period: 86400000,
      );

      expect(dist1.isDistanceBased, isTrue);
      expect(dist1.isHoursBased, isFalse);
      expect(dist1.isTimeBased, isFalse);

      expect(dist2.isDistanceBased, isTrue);
      expect(hours.isHoursBased, isTrue);
      expect(hours.isDistanceBased, isFalse);
      expect(time.isTimeBased, isTrue);
      expect(time.isHoursBased, isFalse);
    });

    test('TC-MM-07: Converted unit getters (km, hours, days)', () {
      const dist = MaintenanceModel(
        id: 1,
        name: 'Dist',
        type: 'totalDistance',
        start: 50000.0, // 50 km
        period: 10000.0, // 10 km
      );
      expect(dist.startKm, equals(50.0));
      expect(dist.periodKm, equals(10.0));

      const hours = MaintenanceModel(
        id: 2,
        name: 'Engine',
        type: 'hours',
        start: 7200000.0, // 2 hours
        period: 3600000.0, // 1 hour
      );
      expect(hours.startHours, equals(2.0));
      expect(hours.periodHours, equals(1.0));

      const time = MaintenanceModel(
        id: 3,
        name: 'Calendar',
        type: 'serverTime',
        start: 172800000.0, // 2 days
        period: 86400000.0, // 1 day
      );
      expect(time.startDays, equals(2.0));
      expect(time.periodDays, equals(1.0));
    });
  });
}

