// ignore_for_file: avoid_print
// Technical Spike Test: WebSocket Exponential Backoff & Lifecycle State Machine
// Validates backoff calculations, jitter boundaries, and reset-on-connected behavior.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ReconnectionPolicy {
  final int initialDelayMs;
  final double backoffMultiplier;
  final int maxDelayMs;
  final int maxRetries;

  int _currentAttempt = 0;
  final Random _random;

  ReconnectionPolicy({
    this.initialDelayMs = 1000,
    this.backoffMultiplier = 1.5,
    this.maxDelayMs = 30000,
    this.maxRetries = 10,
    Random? random,
  }) : _random = random ?? Random();

  int get currentAttempt => _currentAttempt;

  /// Calculates delay with randomized jitter (+/- 20%)
  int getNextDelayMs() {
    _currentAttempt++;
    // Exponential formula: delay = initialDelay * (multiplier ^ (attempt - 1))
    final calculatedDelay =
        initialDelayMs * pow(backoffMultiplier, _currentAttempt - 1);
    final clampedDelay = min(calculatedDelay.toDouble(), maxDelayMs.toDouble());

    // Jitter: +/- 20% to prevent thundering herd problem
    final jitterRange = clampedDelay * 0.2;
    final jitter = (_random.nextDouble() * 2 - 1) * jitterRange;
    final finalDelay = (clampedDelay + jitter).round();

    return max(initialDelayMs, min(finalDelay, maxDelayMs));
  }

  void reset() {
    _currentAttempt = 0;
  }

  bool canRetry() {
    return _currentAttempt < maxRetries;
  }
}

void main() {
  group('WebSocket Reconnection & Backoff Spike Tests', () {
    late ReconnectionPolicy policy;

    setUp(() {
      policy = ReconnectionPolicy(
        initialDelayMs: 1000,
        backoffMultiplier: 2.0,
        maxDelayMs: 16000,
        maxRetries: 5,
        random: Random(42), // Seeded for deterministic test
      );
    });

    test('SPIKE-WS-01: Initial reconnection policy state verified', () {
      expect(policy.currentAttempt, equals(0));
      expect(policy.canRetry(), isTrue);
    });

    test(
      'SPIKE-WS-02: Exponential backoff with jitter bounded within parameters',
      () {
        final delay1 = policy.getNextDelayMs();
        final delay2 = policy.getNextDelayMs();
        final delay3 = policy.getNextDelayMs();
        final delay4 = policy.getNextDelayMs();
        final delay5 = policy.getNextDelayMs();

        expect(delay1, inInclusiveRange(800, 1200));
        expect(delay2, inInclusiveRange(1600, 2400));
        expect(delay3, inInclusiveRange(3200, 4800));
        expect(delay4, inInclusiveRange(6400, 9600));
        expect(delay5, inInclusiveRange(12800, 16000));
      },
    );

    test('SPIKE-WS-03: Maximum retry threshold halts infinite looping', () {
      for (var i = 0; i < 5; i++) {
        policy.getNextDelayMs();
      }
      expect(policy.currentAttempt, equals(5));
      expect(policy.canRetry(), isFalse);
    });

    test(
      'SPIKE-WS-04: Successful connection resets backoff attempt counter',
      () {
        for (var i = 0; i < 3; i++) {
          policy.getNextDelayMs();
        }
        expect(policy.currentAttempt, equals(3));

        policy.reset();
        expect(policy.currentAttempt, equals(0));
        expect(policy.canRetry(), isTrue);
      },
    );
  });
}
