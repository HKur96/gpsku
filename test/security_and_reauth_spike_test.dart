// ignore_for_file: avoid_print, use_super_parameters
// Isolated Spike Test: Security Sanitization, ReAuth Concurrency, and Failure Abstraction
// Validates:
// 1. Sanitization of sensitive headers (Authorization, Cookie) and payload fields (password, token).
// 2. Concurrency guard preventing multiple parallel re-authentication requests.
// 3. Separation of clean user messages from diagnostic debug details.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// === 1. SANITIZATION LOGIC SPIKE ===
class InspectorSanitizer {
  static const Set<String> sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-session-token',
  };

  static const Set<String> sensitiveFields = {
    'password',
    'code',
    'totp',
    'token',
    'secret',
    'hashedpassword',
    'salt',
  };

  /// Sanitizes HTTP headers by redacting sensitive authentication keys.
  static Map<String, dynamic> sanitizeHeaders(Map<String, dynamic> rawHeaders) {
    final sanitized = <String, dynamic>{};
    for (final entry in rawHeaders.entries) {
      if (sensitiveHeaders.contains(entry.key.toLowerCase())) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Recursively sanitizes request/response body maps.
  static dynamic sanitizeBody(dynamic body) {
    if (body is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in body.entries) {
        final keyStr = entry.key.toString().toLowerCase();
        if (sensitiveFields.contains(keyStr)) {
          sanitized[entry.key.toString()] = '[REDACTED]';
        } else if (entry.value is Map || entry.value is List) {
          sanitized[entry.key.toString()] = sanitizeBody(entry.value);
        } else {
          sanitized[entry.key.toString()] = entry.value;
        }
      }
      return sanitized;
    } else if (body is List) {
      return body.map((item) => sanitizeBody(item)).toList();
    }
    return body;
  }
}

// === 2. CONCURRENCY RE-AUTH GUARD SPIKE ===
class ReAuthMutex {
  Completer<bool>? _currentReAuthCompleter;
  int reAuthExecutionCount = 0;

  bool get isReAuthenticating => _currentReAuthCompleter != null;

  /// Simulates parallel requests encountering 401.
  /// Only the first request executes re-auth; all subsequent requests wait on the same Completer.
  Future<bool> executeOrWait(Future<bool> Function() reAuthAction) async {
    if (_currentReAuthCompleter != null) {
      // Another request is already re-authenticating; wait for its outcome
      return _currentReAuthCompleter!.future;
    }

    _currentReAuthCompleter = Completer<bool>();
    reAuthExecutionCount++;

    try {
      final success = await reAuthAction();
      _currentReAuthCompleter!.complete(success);
      return success;
    } catch (e) {
      _currentReAuthCompleter!.complete(false);
      return false;
    } finally {
      _currentReAuthCompleter = null;
    }
  }
}

// === 3. FAILURE ABSTRACTION SPIKE ===
abstract class Failure {
  final String message;
  final int? statusCode;
  final String? debugDetails;

  const Failure(this.message, {this.statusCode, this.debugDetails});

  @override
  String toString() => 'Failure(message: "$message", statusCode: $statusCode)';
}

class NetworkFailure extends Failure {
  const NetworkFailure({String? debugDetails})
    : super(
        'Koneksi internet bermasalah. Periksa jaringan Anda.',
        debugDetails: debugDetails,
      );
}

class ServerFailure extends Failure {
  const ServerFailure({int? statusCode, String? debugDetails})
    : super(
        'Terjadi kendala pada server. Silakan coba kembali nanti.',
        statusCode: statusCode,
        debugDetails: debugDetails,
      );
}

void main() {
  group('Security, ReAuth & Failure Spike Tests', () {
    test(
      'SPIKE-SR-01: Sensitive headers (Authorization, Cookie) properly redacted',
      () {
        final rawHeaders = {
          'Accept': 'application/json',
          'Authorization': 'Bearer node01abcdef123456789',
          'Cookie': 'JSESSIONID=node01xyz987654321; Path=/',
          'User-Agent': 'GPSku-Mobile/1.0.0',
        };
        final sanitizedHeaders = InspectorSanitizer.sanitizeHeaders(rawHeaders);
        expect(sanitizedHeaders['Accept'], equals('application/json'));
        expect(sanitizedHeaders['Authorization'], equals('[REDACTED]'));
        expect(sanitizedHeaders['Cookie'], equals('[REDACTED]'));
        expect(sanitizedHeaders['User-Agent'], equals('GPSku-Mobile/1.0.0'));
      },
    );

    test(
      'SPIKE-SR-02: Sensitive payload fields (password, token) recursively redacted',
      () {
        final rawBody = {
          'email': 'operator@fleet.com',
          'password': 'SuperSecretPassword123!',
          'nested': {
            'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
            'status': 'active',
          },
        };
        final sanitizedBody = InspectorSanitizer.sanitizeBody(rawBody);
        expect(sanitizedBody['email'], equals('operator@fleet.com'));
        expect(sanitizedBody['password'], equals('[REDACTED]'));
        expect(sanitizedBody['nested']['token'], equals('[REDACTED]'));
        expect(sanitizedBody['nested']['status'], equals('active'));
      },
    );

    test(
      'SPIKE-SR-03: 5 parallel 401 requests executed re-auth exactly ONCE via Mutex',
      () async {
        final mutex = ReAuthMutex();
        var actualReAuthCalls = 0;

        Future<bool> simulateReAuth() async {
          actualReAuthCalls++;
          await Future.delayed(const Duration(milliseconds: 50));
          return true; // Re-auth successful
        }

        // Launch 5 parallel requests encountering 401
        final results = await Future.wait([
          mutex.executeOrWait(simulateReAuth),
          mutex.executeOrWait(simulateReAuth),
          mutex.executeOrWait(simulateReAuth),
          mutex.executeOrWait(simulateReAuth),
          mutex.executeOrWait(simulateReAuth),
        ]);

        expect(results.every((r) => r == true), isTrue);
        expect(actualReAuthCalls, equals(1));
        expect(mutex.reAuthExecutionCount, equals(1));
      },
    );

    test(
      'SPIKE-SR-04: Failure separates clean user-facing message from internal diagnostics',
      () {
        final failure = ServerFailure(
          statusCode: 500,
          debugDetails:
              'org.postgresql.util.PSQLException: ERROR: relation "tc_devices" does not exist at line 42',
        );
        expect(failure.message, isNot(contains('PSQLException')));
        expect(failure.message, isNot(contains('tc_devices')));
        expect(
          failure.message,
          equals('Terjadi kendala pada server. Silakan coba kembali nanti.'),
        );
        expect(failure.debugDetails, contains('PSQLException'));
      },
    );
  });
}
