// ignore_for_file: avoid_print
// Test spike for Traccar position ordering deterministic guard
// Covers all multi-criteria edge cases: fixTime, id, and serverTime.

import 'package:flutter_test/flutter_test.dart';

class Position {
  final int id;
  final int deviceId;
  final DateTime fixTime;
  final DateTime serverTime;
  final double latitude;
  final double longitude;

  Position({
    required this.id,
    required this.deviceId,
    required this.fixTime,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() =>
      'Position(id: $id, fixTime: $fixTime, serverTime: $serverTime)';
}

/// Deterministic guard to determine if incoming position is strictly newer than current position.
/// Protects against out-of-order delivery between fast WebSocket and delayed REST responses.
bool isPositionNewer(Position incoming, Position current) {
  // Criterion 1: Satellite fixTime is strictly newer
  if (incoming.fixTime.isAfter(current.fixTime)) {
    return true;
  }

  // Criterion 2: Same fixTime (split-second batch fix), evaluate auto-increment database PK
  if (incoming.fixTime.isAtSameMomentAs(current.fixTime)) {
    if (incoming.id > 0 && current.id > 0) {
      return incoming.id > current.id;
    }
    // Criterion 3: One or both lack persistent ID, compare ingestion serverTime
    return incoming.serverTime.isAfter(current.serverTime);
  }

  // Incoming fixTime is in the past -> stale / obsolete
  return false;
}

void main() {
  group('Position Ordering Spike Tests', () {
    final baseTime = DateTime.parse('2026-11-07T10:00:00.000Z');
    final current = Position(
      id: 100,
      deviceId: 1,
      fixTime: baseTime,
      serverTime: baseTime.add(const Duration(seconds: 1)),
      latitude: -6.2000,
      longitude: 106.8166,
    );

    test('SPIKE-PO-01: Newer fixTime correctly accepted', () {
      final newerFix = Position(
        id: 101,
        deviceId: 1,
        fixTime: baseTime.add(const Duration(seconds: 5)),
        serverTime: baseTime.add(const Duration(seconds: 6)),
        latitude: -6.2001,
        longitude: 106.8167,
      );
      expect(isPositionNewer(newerFix, current), isTrue);
    });

    test('SPIKE-PO-02: Stale fixTime correctly rejected', () {
      final staleFix = Position(
        id: 99,
        deviceId: 1,
        fixTime: baseTime.subtract(const Duration(seconds: 5)),
        serverTime: baseTime.add(const Duration(seconds: 10)),
        latitude: -6.1999,
        longitude: 106.8165,
      );
      expect(isPositionNewer(staleFix, current), isFalse);
    });

    test('SPIKE-PO-03: Same fixTime with higher ID correctly accepted', () {
      final sameFixHigherId = Position(
        id: 105,
        deviceId: 1,
        fixTime: baseTime,
        serverTime: baseTime.add(const Duration(seconds: 2)),
        latitude: -6.2002,
        longitude: 106.8168,
      );
      expect(isPositionNewer(sameFixHigherId, current), isTrue);
    });

    test('SPIKE-PO-04: Same fixTime with lower ID correctly rejected', () {
      final sameFixLowerId = Position(
        id: 95,
        deviceId: 1,
        fixTime: baseTime,
        serverTime: baseTime.add(const Duration(seconds: 2)),
        latitude: -6.1998,
        longitude: 106.8164,
      );
      expect(isPositionNewer(sameFixLowerId, current), isFalse);
    });

    test('SPIKE-PO-05: Duplicate packet correctly rejected (idempotent)', () {
      final duplicatePacket = Position(
        id: 100,
        deviceId: 1,
        fixTime: baseTime,
        serverTime: baseTime.add(const Duration(seconds: 1)),
        latitude: -6.2000,
        longitude: 106.8166,
      );
      expect(isPositionNewer(duplicatePacket, current), isFalse);
    });

    test(
      'SPIKE-PO-06: Same fixTime with unpersisted ID and higher serverTime correctly accepted',
      () {
        final unpersistedNewerServerTime = Position(
          id: 0,
          deviceId: 1,
          fixTime: baseTime,
          serverTime: baseTime.add(const Duration(seconds: 5)),
          latitude: -6.2003,
          longitude: 106.8169,
        );
        final unpersistedCurrent = Position(
          id: 0,
          deviceId: 1,
          fixTime: baseTime,
          serverTime: baseTime.add(const Duration(seconds: 1)),
          latitude: -6.2000,
          longitude: 106.8166,
        );
        expect(
          isPositionNewer(unpersistedNewerServerTime, unpersistedCurrent),
          isTrue,
        );
      },
    );
  });
}
