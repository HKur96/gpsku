// Application Configuration Management

class AppConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  const AppConfig({
    this.baseUrl =
        'http://10.0.2.2:8082', // Standard Android emulator loopback to host Traccar
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 15),
  });

  /// Derives WebSocket URI from HTTP/HTTPS base URL.
  Uri get webSocketUri {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(
      scheme: wsScheme,
      path: '/api/socket',
      queryParameters: null,
    );
  }

  /// Derives OsmAnd protocol ingestion URI from base URL host and port (default: 5055).
  /// Defaults to plain 'http' scheme to avoid SSL handshake failures against Netty TrackerServer.
  Uri getOsmandUri({int port = 5055, String scheme = 'http'}) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      scheme: scheme,
      port: port,
      path: '/',
      queryParameters: null,
    );
  }

  AppConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    return AppConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
    );
  }
}
