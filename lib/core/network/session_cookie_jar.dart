// RFC 6265 Compliant Session Cookie Jar for Traccar API & WebSocket Handshake
// Ensures no attribute leakage (Path, HttpOnly, SameSite, Expires) into outgoing headers.

import 'dart:io';

class SessionCookieJar {
  final Map<String, Cookie> _cookies = {};

  /// Parses raw 'set-cookie' headers from Dio response.
  /// Note: Cookie.fromSetCookieValue() parses EXACTLY ONE Set-Cookie header value.
  /// Multiple headers must be passed as `List<String>` and processed individually.
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

  /// Generates the outgoing 'Cookie' header string for REST requests.
  /// Strictly formats as: 'name1=value1; name2=value2'.
  /// NEVER includes Path, HttpOnly, Expires, or other metadata attributes.
  String? get outgoingCookieHeader {
    if (_cookies.isEmpty) return null;
    return _cookies.values.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Generates WebSocket specific Cookie header.
  /// Formats strictly as 'JSESSIONID=value'.
  String? get webSocketCookieHeader {
    final jsessionid = _cookies['JSESSIONID'];
    if (jsessionid == null) return null;
    return '${jsessionid.name}=${jsessionid.value}';
  }

  /// Clears all stored cookies on logout or session expiration.
  void clear() {
    _cookies.clear();
  }

  /// Returns true if an active non-empty JSESSIONID cookie exists.
  bool get hasValidSession =>
      _cookies.containsKey('JSESSIONID') &&
      _cookies['JSESSIONID']!.value.isNotEmpty;

  int get cookieCount => _cookies.length;
}
