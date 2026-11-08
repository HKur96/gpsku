import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/utils/position_ordering_guard.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';

void main() {
  group('PositionOrderingGuard Deterministic Telematics Tests', () {
    final baseTime = DateTime.parse('2026-11-07T10:00:00.000Z');

    final current = PositionModel(
      id: 100,
      deviceId: 1,
      fixTime: baseTime,
      serverTime: baseTime.add(const Duration(seconds: 1)),
      latitude: -6.2000,
      longitude: 106.8166,
    );

    test('TC-POG-01: Accepts strictly newer fixTime', () {
      final newer = PositionModel(
        id: 101,
        deviceId: 1,
        fixTime: baseTime.add(const Duration(seconds: 5)),
        serverTime: baseTime.add(const Duration(seconds: 6)),
        latitude: -6.2001,
        longitude: 106.8167,
      );

      expect(PositionOrderingGuard.isPositionNewer(newer, current), isTrue);
      expect(PositionOrderingGuard.shouldUpdate(current, newer), isTrue);
    });

    test('TC-POG-02: Rejects stale/delayed out-of-order fixTime', () {
      final stale = PositionModel(
        id: 99,
        deviceId: 1,
        fixTime: baseTime.subtract(const Duration(seconds: 5)),
        serverTime: baseTime.add(const Duration(seconds: 10)),
        latitude: -6.1999,
        longitude: 106.8165,
      );

      expect(PositionOrderingGuard.isPositionNewer(stale, current), isFalse);
      expect(PositionOrderingGuard.shouldUpdate(current, stale), isFalse);
    });

    test(
      'TC-POG-03: Same fixTime resolves tie via higher auto-increment ID',
      () {
        final higherId = PositionModel(
          id: 105,
          deviceId: 1,
          fixTime: baseTime,
          serverTime: baseTime.add(const Duration(seconds: 2)),
          latitude: -6.2002,
          longitude: 106.8168,
        );

        expect(
          PositionOrderingGuard.isPositionNewer(higherId, current),
          isTrue,
        );
        expect(PositionOrderingGuard.shouldUpdate(current, higherId), isTrue);
      },
    );

    test('TC-POG-04: Same fixTime with lower ID is rejected as obsolete', () {
      final lowerId = PositionModel(
        id: 95,
        deviceId: 1,
        fixTime: baseTime,
        serverTime: baseTime.add(const Duration(seconds: 2)),
        latitude: -6.1998,
        longitude: 106.8164,
      );

      expect(PositionOrderingGuard.isPositionNewer(lowerId, current), isFalse);
      expect(PositionOrderingGuard.shouldUpdate(current, lowerId), isFalse);
    });

    test(
      'TC-POG-05: Missing database ID breaks tie using ingestion serverTime',
      () {
        final unpersistedCurrent = PositionModel(
          id: 0,
          deviceId: 1,
          fixTime: baseTime,
          serverTime: baseTime.add(const Duration(seconds: 1)),
          latitude: -6.2000,
          longitude: 106.8166,
        );

        final unpersistedNewerServer = PositionModel(
          id: 0,
          deviceId: 1,
          fixTime: baseTime,
          serverTime: baseTime.add(const Duration(seconds: 3)),
          latitude: -6.2003,
          longitude: 106.8169,
        );

        expect(
          PositionOrderingGuard.isPositionNewer(
            unpersistedNewerServer,
            unpersistedCurrent,
          ),
          isTrue,
        );
      },
    );

    test(
      'TC-POG-06: shouldUpdate returns true when existing position is null',
      () {
        expect(PositionOrderingGuard.shouldUpdate(null, current), isTrue);
      },
    );
  });
}
