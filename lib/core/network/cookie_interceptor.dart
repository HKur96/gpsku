import 'package:dio/dio.dart';
import 'session_cookie_jar.dart';

/// Interceptor that binds SessionCookieJar to Dio.
/// Injects RFC 6265 Cookie header on requests and captures Set-Cookie on responses.
class CookieInterceptor extends Interceptor {
  final SessionCookieJar cookieJar;

  CookieInterceptor({required this.cookieJar});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cookieHeader = cookieJar.outgoingCookieHeader;
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      options.headers['Cookie'] = cookieHeader;
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
      cookieJar.saveFromSetCookieHeaders(setCookieHeaders);
    }
    super.onResponse(response, handler);
  }
}
