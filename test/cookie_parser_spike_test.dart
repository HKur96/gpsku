// ignore_for_file: avoid_print, unintended_html_in_doc_comment
// Isolated Spike Test: RFC 6265 Cookie Parser & Lifecycle Management
// Validates:
// 1. Individual parsing of separate Set-Cookie header strings.
// 2. Cookie attribute stripping (Path, HttpOnly, SameSite, Expires excluded from outgoing Cookie).
// 3. Handling expired cookies (past Expires date).
// 4. Handling Max-Age=0 (immediate deletion of cookie).
// 5. In-place cookie replacement upon session renewal.
// 6. WebSocket reconnect using updated cookie after renewal.
// 7. Safety against malformed/null/empty headers.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

class SessionCookieJar {
  final Map<String, Cookie> _cookies = {};

  /// Parses raw 'set-cookie' headers from Dio response.
  /// Note: Cookie.fromSetCookieValue() parses EXACTLY ONE Set-Cookie header value.
  /// Multiple headers must be passed as List<String> and processed individually.
  void saveFromSetCookieHeaders(List<String>? setCookieHeaders) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return;

    final now = DateTime.now();

    for (final rawHeader in setCookieHeaders) {
      if (rawHeader.trim().isEmpty) continue;
      try {
        final cookie = Cookie.fromSetCookieValue(rawHeader);

        // Lifecycle Rule 1: Max-Age=0 or negative means immediate deletion
        if (cookie.maxAge != null && cookie.maxAge! <= 0) {
          _cookies.remove(cookie.name);
          continue;
        }

        // Lifecycle Rule 2: Past Expires date means cookie is already expired
        if (cookie.expires != null && cookie.expires!.isBefore(now)) {
          _cookies.remove(cookie.name);
          continue;
        }

        // Lifecycle Rule 3: Valid cookie saved or updated in-place (replacement)
        _cookies[cookie.name] = cookie;
      } catch (_) {
        // Ignore unparseable individual headers without crashing
      }
    }
  }

  /// Extracts session ID (JSESSIONID) value.
  String? get sessionCookieValue => _cookies['JSESSIONID']?.value;

  /// Generates the outgoing 'Cookie' header string.
  /// Strictly formats as: 'name1=value1; name2=value2'.
  /// NEVER includes Path, HttpOnly, Expires, or other metadata attributes.
  String? get outgoingCookieHeader {
    if (_cookies.isEmpty) return null;
    return _cookies.values.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Generates WebSocket specific Cookie header.
  /// Formats as 'JSESSIONID=value'.
  String? get webSocketCookieHeader {
    final jsessionid = _cookies['JSESSIONID'];
    if (jsessionid == null) return null;
    return '${jsessionid.name}=${jsessionid.value}';
  }

  /// Clears all stored cookies on logout or session expiration.
  void clear() {
    _cookies.clear();
  }

  bool get hasValidSession =>
      _cookies.containsKey('JSESSIONID') &&
      _cookies['JSESSIONID']!.value.isNotEmpty;

  int get cookieCount => _cookies.length;
}

void main() {
  group('Cookie Parser & Lifecycle Spike Tests', () {
    test(
      'SPIKE-CP-01: Single Set-Cookie parsed correctly. Outgoing header contains ONLY name=value',
      () {
        final jar = SessionCookieJar();
        final singleSetCookie = [
          'JSESSIONID=node01abcdef123456789.node0; Path=/; HttpOnly',
        ];
        jar.saveFromSetCookieHeaders(singleSetCookie);

        expect(jar.hasValidSession, isTrue);
        expect(jar.sessionCookieValue, equals('node01abcdef123456789.node0'));
        expect(
          jar.outgoingCookieHeader,
          equals('JSESSIONID=node01abcdef123456789.node0'),
        );
        expect(
          jar.webSocketCookieHeader,
          equals('JSESSIONID=node01abcdef123456789.node0'),
        );
        expect(jar.outgoingCookieHeader, isNot(contains('Path=/')));
        expect(jar.outgoingCookieHeader, isNot(contains('HttpOnly')));
      },
    );

    test(
      'SPIKE-CP-02: Multiple Set-Cookie headers parsed individually without attribute leakage',
      () {
        final jarMultiple = SessionCookieJar();
        final multipleSetCookies = [
          'JSESSIONID=node01xyz987654321.node0; Path=/api; HttpOnly; SameSite=Lax',
          'remember_me=user_hash_12345; Path=/; Expires=Wed, 21 Oct 2027 07:28:00 GMT; Secure',
        ];
        jarMultiple.saveFromSetCookieHeaders(multipleSetCookies);

        expect(
          jarMultiple.sessionCookieValue,
          equals('node01xyz987654321.node0'),
        );
        final outgoing = jarMultiple.outgoingCookieHeader!;
        expect(outgoing, contains('JSESSIONID=node01xyz987654321.node0'));
        expect(outgoing, contains('remember_me=user_hash_12345'));
        expect(outgoing, isNot(contains('Path=')));
        expect(outgoing, isNot(contains('Expires=')));
        expect(outgoing, isNot(contains('SameSite=')));
        expect(outgoing, isNot(contains('Secure')));
        expect(outgoing, isNot(contains('HttpOnly')));
      },
    );

    test('SPIKE-CP-03: Cookie with expired past date rejected upon receipt', () {
      final jarExpired = SessionCookieJar();
      final expiredCookie = [
        'JSESSIONID=stale_token_123; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT',
      ];
      jarExpired.saveFromSetCookieHeaders(expiredCookie);
      expect(jarExpired.hasValidSession, isFalse);
      expect(jarExpired.cookieCount, equals(0));
    });

    test(
      'SPIKE-CP-04: Max-Age=0 triggers immediate deletion of target cookie',
      () {
        final jarMaxAge = SessionCookieJar();
        jarMaxAge.saveFromSetCookieHeaders([
          'JSESSIONID=initial_session_456; Path=/',
        ]);
        expect(jarMaxAge.hasValidSession, isTrue);

        jarMaxAge.saveFromSetCookieHeaders([
          'JSESSIONID=deleted; Max-Age=0; Path=/',
        ]);
        expect(jarMaxAge.hasValidSession, isFalse);
        expect(jarMaxAge.outgoingCookieHeader, isNull);
      },
    );

    test(
      'SPIKE-CP-05: Cookie replacement succeeds; WebSocket header reflects renewed session',
      () {
        final jarRenewal = SessionCookieJar();
        jarRenewal.saveFromSetCookieHeaders([
          'JSESSIONID=session_v1; Path=/; HttpOnly',
        ]);
        expect(
          jarRenewal.webSocketCookieHeader,
          equals('JSESSIONID=session_v1'),
        );

        jarRenewal.saveFromSetCookieHeaders([
          'JSESSIONID=session_v2_renewed; Path=/; HttpOnly',
        ]);
        expect(
          jarRenewal.webSocketCookieHeader,
          equals('JSESSIONID=session_v2_renewed'),
        );
        expect(jarRenewal.outgoingCookieHeader, isNot(contains('session_v1')));
      },
    );

    test('SPIKE-CP-06: Null, empty, and malformed headers handled safely', () {
      final jarSafe = SessionCookieJar();
      jarSafe.saveFromSetCookieHeaders(null);
      jarSafe.saveFromSetCookieHeaders([]);
      jarSafe.saveFromSetCookieHeaders(['   ', 'malformed_without_equals']);
      expect(jarSafe.hasValidSession, isFalse);
    });
  });
}
