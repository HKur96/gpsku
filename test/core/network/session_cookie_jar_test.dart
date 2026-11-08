import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';

void main() {
  group('SessionCookieJar RFC 6265 & Lifecycle Tests', () {
    late SessionCookieJar cookieJar;

    setUp(() {
      cookieJar = SessionCookieJar();
    });

    test('TC-CJ-01: Correctly parses single Set-Cookie header', () {
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=node01abcdef123456; Path=/; HttpOnly; SameSite=Lax',
      ]);

      expect(cookieJar.sessionCookieValue, equals('node01abcdef123456'));
      expect(cookieJar.hasValidSession, isTrue);
    });

    test('TC-CJ-02: Processes multiple Set-Cookie headers individually', () {
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=node01sessionid; Path=/; HttpOnly',
        'rememberMe=true; Path=/; Expires=Wed, 21 Oct 2027 07:28:00 GMT',
        'tracking=active; Path=/api',
      ]);

      expect(cookieJar.cookieCount, equals(3));
      expect(cookieJar.sessionCookieValue, equals('node01sessionid'));
    });

    test(
      'TC-CJ-03: Outgoing cookie header strictly strips attributes (RFC 6265)',
      () {
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=node01xyz; Path=/; HttpOnly; Secure; SameSite=Strict',
          'userPref=dark; Path=/settings; HttpOnly',
        ]);

        final outgoing = cookieJar.outgoingCookieHeader;
        expect(outgoing, isNotNull);
        // Must NOT contain attributes
        expect(outgoing, isNot(contains('Path=')));
        expect(outgoing, isNot(contains('HttpOnly')));
        expect(outgoing, isNot(contains('Secure')));
        expect(outgoing, isNot(contains('SameSite')));

        // Must contain raw key=value pairs
        expect(outgoing, contains('JSESSIONID=node01xyz'));
        expect(outgoing, contains('userPref=dark'));
      },
    );

    test(
      'TC-CJ-04: webSocketCookieHeader returns strictly JSESSIONID=value',
      () {
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=node0999socket; Path=/; HttpOnly',
          'extra=ignore; Path=/',
        ]);

        expect(
          cookieJar.webSocketCookieHeader,
          equals('JSESSIONID=node0999socket'),
        );
      },
    );

    test('TC-CJ-05: Max-Age=0 or negative triggers immediate deletion', () {
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=initial_session; Path=/',
      ]);
      expect(cookieJar.hasValidSession, isTrue);

      // Deletion packet from backend
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=; Path=/; Max-Age=0; HttpOnly',
      ]);
      expect(cookieJar.hasValidSession, isFalse);
      expect(cookieJar.sessionCookieValue, isNull);
    });

    test('TC-CJ-06: Past Expires date is dropped immediately', () {
      cookieJar.saveFromSetCookieHeaders([
        'expiredCookie=old; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT',
      ]);
      expect(cookieJar.cookieCount, equals(0));
    });

    test('TC-CJ-07: In-place cookie replacement upon session renewal', () {
      cookieJar.saveFromSetCookieHeaders(['JSESSIONID=first_session; Path=/']);
      expect(cookieJar.sessionCookieValue, equals('first_session'));

      // Backend issues session rotation
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=renewed_session_token; Path=/; HttpOnly',
      ]);
      expect(cookieJar.sessionCookieValue, equals('renewed_session_token'));
      expect(cookieJar.cookieCount, equals(1));
    });

    test('TC-CJ-08: clear() purges all stored session data', () {
      cookieJar.saveFromSetCookieHeaders([
        'JSESSIONID=session_to_clear; Path=/',
        'theme=light; Path=/',
      ]);
      expect(cookieJar.cookieCount, equals(2));

      cookieJar.clear();
      expect(cookieJar.cookieCount, equals(0));
      expect(cookieJar.hasValidSession, isFalse);
      expect(cookieJar.outgoingCookieHeader, isNull);
      expect(cookieJar.webSocketCookieHeader, isNull);
    });

    test(
      'TC-CJ-09: Cookie rotation updates both REST and WebSocket headers to latest session without leakage',
      () {
        // Initial Session
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=initial_session_aaa; Path=/; HttpOnly',
        ]);
        expect(
          cookieJar.outgoingCookieHeader,
          equals('JSESSIONID=initial_session_aaa'),
        );
        expect(
          cookieJar.webSocketCookieHeader,
          equals('JSESSIONID=initial_session_aaa'),
        );

        // Server Rotates Session
        cookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=rotated_session_bbb; Path=/; HttpOnly',
        ]);

        // REST header must only contain rotated session
        final restHeader = cookieJar.outgoingCookieHeader;
        expect(restHeader, equals('JSESSIONID=rotated_session_bbb'));
        expect(restHeader, isNot(contains('initial_session_aaa')));
        expect(restHeader, isNot(contains('Path=')));
        expect(restHeader, isNot(contains('HttpOnly')));

        // WebSocket header must strictly equal rotated session
        final wsHeader = cookieJar.webSocketCookieHeader;
        expect(wsHeader, equals('JSESSIONID=rotated_session_bbb'));
        expect(wsHeader, isNot(contains('initial_session_aaa')));
        expect(wsHeader, isNot(contains('Path=')));
      },
    );
  });
}
