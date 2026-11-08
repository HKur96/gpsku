import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';

void main() {
  group('DriverModel Unit Tests', () {
    const tDriver = DriverModel(
      id: 42,
      name: 'Budi Santoso',
      uniqueId: 'RFID-987654',
      attributes: {
        'phone': '081234567890',
        'contact': 'budi@logistik.id',
        'license': 'SIM-B2-UMUM',
      },
    );

    test('TC-DM-01: Serializes to JSON accurately with all fields', () {
      final json = tDriver.toJson();

      expect(json['id'], equals(42));
      expect(json['name'], equals('Budi Santoso'));
      expect(json['uniqueId'], equals('RFID-987654'));
      expect(
        json['attributes'],
        equals({
          'phone': '081234567890',
          'contact': 'budi@logistik.id',
          'license': 'SIM-B2-UMUM',
        }),
      );
    });

    test('TC-DM-02: Serializes to JSON omitting attributes when empty', () {
      const driverWithoutAttrs = DriverModel(
        id: 1,
        name: 'Agus Wijaya',
        uniqueId: 'IBUTTON-123',
      );

      final json = driverWithoutAttrs.toJson();

      expect(json['id'], equals(1));
      expect(json['name'], equals('Agus Wijaya'));
      expect(json['uniqueId'], equals('IBUTTON-123'));
      expect(json.containsKey('attributes'), isFalse);
    });

    test('TC-DM-03: Deserializes from JSON accurately with full payload', () {
      final json = {
        'id': 105,
        'name': 'Dedi Kusnandar',
        'uniqueId': 'RFID-456789',
        'attributes': {
          'phone': '08987654321',
          'contact': 'dedi@fleet.id',
          'license': 'SIM-A-POLOS',
        },
      };

      final driver = DriverModel.fromJson(json);

      expect(driver.id, equals(105));
      expect(driver.name, equals('Dedi Kusnandar'));
      expect(driver.uniqueId, equals('RFID-456789'));
      expect(driver.phone, equals('08987654321'));
      expect(driver.contact, equals('dedi@fleet.id'));
      expect(driver.license, equals('SIM-A-POLOS'));
    });

    test('TC-DM-04: Deserializes gracefully from incomplete or null JSON', () {
      final json = <String, dynamic>{
        'id': null,
        'name': null,
        'uniqueId': null,
        'attributes': null,
      };

      final driver = DriverModel.fromJson(json);

      expect(driver.id, equals(0));
      expect(driver.name, equals(''));
      expect(driver.uniqueId, equals(''));
      expect(driver.attributes, isEmpty);
      expect(driver.phone, isNull);
      expect(driver.license, isNull);
    });

    test(
      'TC-DM-05: Fallback license lookup checks driverLicense attribute',
      () {
        const driver = DriverModel(
          id: 7,
          name: 'Supardi',
          uniqueId: 'TAG-001',
          attributes: {'driverLicense': 'SIM-B1'},
        );

        expect(driver.license, equals('SIM-B1'));
      },
    );

    test('TC-DM-06: Attributes map is unmodifiable and throws on mutation', () {
      expect(
        () => tDriver.attributes['newKey'] = 'malicious',
        throwsA(isA<UnsupportedError>()),
      );

      final fromJsonDriver = DriverModel.fromJson({
        'id': 1,
        'name': 'Test',
        'uniqueId': 'U1',
        'attributes': {'key': 'val'},
      });
      expect(
        () => fromJsonDriver.attributes['newKey'] = 'malicious',
        throwsA(isA<UnsupportedError>()),
      );
    });

    test(
      'TC-DM-07: copyWith updates target fields while preserving others',
      () {
        final updated = tDriver.copyWith(
          name: 'Budi Santoso S.E.',
          uniqueId: 'RFID-NEW-001',
        );

        expect(updated.id, equals(42));
        expect(updated.name, equals('Budi Santoso S.E.'));
        expect(updated.uniqueId, equals('RFID-NEW-001'));
        expect(updated.phone, equals('081234567890'));
      },
    );

    test(
      'TC-DM-08: Value equality and hashCode with map entries comparison',
      () {
        final driverA = DriverModel(
          id: 10,
          name: 'Joko',
          uniqueId: 'TAG-10',
          attributes: Map.from({'role': 'senior', 'zone': 'JKT'}),
        );

        final driverB = DriverModel(
          id: 10,
          name: 'Joko',
          uniqueId: 'TAG-10',
          attributes: Map.from({'role': 'senior', 'zone': 'JKT'}),
        );

        final driverDifferent = DriverModel(
          id: 10,
          name: 'Joko',
          uniqueId: 'TAG-10',
          attributes: Map.from({'role': 'junior', 'zone': 'JKT'}),
        );

        expect(driverA, equals(driverB));
        expect(driverA.hashCode, equals(driverB.hashCode));
        expect(driverA, isNot(equals(driverDifferent)));
        expect(driverA.hashCode, isNot(equals(driverDifferent.hashCode)));
      },
    );

    test(
      'TC-DM-09: toString representation contains id, name, and uniqueId',
      () {
        final str = tDriver.toString();

        expect(str, contains('42'));
        expect(str, contains('Budi Santoso'));
        expect(str, contains('RFID-987654'));
      },
    );
  });
}
