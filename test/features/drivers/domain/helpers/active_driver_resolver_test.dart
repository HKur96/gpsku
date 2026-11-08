import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/domain/helpers/active_driver_resolver.dart';

void main() {
  group('ActiveDriverResolver Unit Tests', () {
    const tDriver1 = DriverModel(
      id: 1,
      name: 'Budi Santoso',
      uniqueId: 'RFID-1001',
    );
    const tDriver2 = DriverModel(
      id: 2,
      name: 'Agus Wijaya',
      uniqueId: 'IBUTTON-2002',
    );
    const tDriver3 = DriverModel(
      id: 3,
      name: 'Dedi Kusnandar',
      uniqueId: 'TAG-3003',
    );

    final driversCatalog = [tDriver1, tDriver2, tDriver3];

    PositionModel createPosition({Map<String, dynamic>? attributes}) {
      return PositionModel(
        id: 999,
        deviceId: 10,
        protocol: 'osmand',
        serverTime: DateTime.now(),
        deviceTime: DateTime.now(),
        fixTime: DateTime.now(),
        valid: true,
        latitude: -6.2000,
        longitude: 106.8166,
        altitude: 10.0,
        speed: 40.0,
        course: 180.0,
        attributes: attributes ?? const {},
      );
    }

    test(
      'TC-ADR-01: Resolves active driver from matching position attributes',
      () {
        final pos = createPosition(attributes: {'driverUniqueId': 'RFID-1001'});

        final resolved = ActiveDriverResolver.resolveFromPosition(
          position: pos,
          drivers: driversCatalog,
        );

        expect(resolved, isNotNull);
        expect(resolved?.id, equals(1));
        expect(resolved?.name, equals('Budi Santoso'));
      },
    );

    test('TC-ADR-02: Matches case-insensitively and trims whitespace', () {
      final pos = createPosition(
        attributes: {'driverUniqueId': '  ibutton-2002  '},
      );

      final resolved = ActiveDriverResolver.resolveFromPosition(
        position: pos,
        drivers: driversCatalog,
      );

      expect(resolved, isNotNull);
      expect(resolved?.id, equals(2));
      expect(resolved?.name, equals('Agus Wijaya'));
    });

    test('TC-ADR-03: Returns null when position is null', () {
      final resolved = ActiveDriverResolver.resolveFromPosition(
        position: null,
        drivers: driversCatalog,
      );

      expect(resolved, isNull);
    });

    test(
      'TC-ADR-04: Returns null when position has no driverUniqueId attribute',
      () {
        final pos = createPosition(attributes: {'totalDistance': 50000.0});

        final resolved = ActiveDriverResolver.resolveFromPosition(
          position: pos,
          drivers: driversCatalog,
        );

        expect(resolved, isNull);
      },
    );

    test('TC-ADR-05: Returns null when driverUniqueId is blank or empty', () {
      final pos = createPosition(attributes: {'driverUniqueId': '   '});

      final resolved = ActiveDriverResolver.resolveFromPosition(
        position: pos,
        drivers: driversCatalog,
      );

      expect(resolved, isNull);
    });

    test(
      'TC-ADR-06: Returns null when driverUniqueId is not in the catalog',
      () {
        final pos = createPosition(
          attributes: {'driverUniqueId': 'UNKNOWN-TAG-999'},
        );

        final resolved = ActiveDriverResolver.resolveFromPosition(
          position: pos,
          drivers: driversCatalog,
        );

        expect(resolved, isNull);
      },
    );

    test('TC-ADR-07: extractDriverUniqueId returns clean trimmed string', () {
      final posWithId = createPosition(
        attributes: {'driverUniqueId': '  TAG-3003 '},
      );
      final posWithoutId = createPosition(attributes: {});

      expect(
        ActiveDriverResolver.extractDriverUniqueId(posWithId),
        equals('TAG-3003'),
      );
      expect(ActiveDriverResolver.extractDriverUniqueId(posWithoutId), isNull);
      expect(ActiveDriverResolver.extractDriverUniqueId(null), isNull);
    });

    test(
      'TC-ADR-08: resolveByUniqueId resolves driver directly by string key',
      () {
        final match = ActiveDriverResolver.resolveByUniqueId(
          driverUniqueId: 'tag-3003',
          drivers: driversCatalog,
        );

        expect(match, isNotNull);
        expect(match?.name, equals('Dedi Kusnandar'));

        expect(
          ActiveDriverResolver.resolveByUniqueId(
            driverUniqueId: null,
            drivers: driversCatalog,
          ),
          isNull,
        );
      },
    );

    test(
      'TC-ADR-09: formatDriverDisplay returns driver name when driver entity is present',
      () {
        final display = ActiveDriverResolver.formatDriverDisplay(
          driver: tDriver1,
          fallbackUniqueId: 'RFID-1001',
        );

        expect(display, equals('Budi Santoso'));
      },
    );

    test(
      'TC-ADR-10: formatDriverDisplay falls back to RFID uniqueId when entity is null',
      () {
        final display = ActiveDriverResolver.formatDriverDisplay(
          driver: null,
          fallbackUniqueId: 'RFID-UNKNOWN-999',
        );

        expect(display, equals('RFID-UNKNOWN-999'));
      },
    );

    test(
      'TC-ADR-11: formatDriverDisplay returns defaultFallback when all are absent',
      () {
        final displayDefault = ActiveDriverResolver.formatDriverDisplay(
          driver: null,
          fallbackUniqueId: null,
        );

        final displayCustom = ActiveDriverResolver.formatDriverDisplay(
          driver: null,
          fallbackUniqueId: '   ',
          defaultFallback: 'Supir Tidak Terdaftar',
        );

        expect(displayDefault, equals('Tanpa Pengemudi'));
        expect(displayCustom, equals('Supir Tidak Terdaftar'));
      },
    );
  });
}
