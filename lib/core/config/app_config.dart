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

  /// Whether the configured API base URL uses encrypted HTTPS transport.
  bool get isHttps {
    final uri = Uri.tryParse(baseUrl);
    return uri?.scheme.toLowerCase() == 'https';
  }

  /// Derives Traccar WebServer's root proxy [Uri] (`POST /`) handled by
  /// `WebServer.initClientProxy()` to forward OsmAnd payloads internally to port 5055.
  Uri getOsmandProxyUri() {
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme.isNotEmpty ? uri.scheme : 'https',
      host: uri.host.isNotEmpty ? uri.host : '10.0.2.2',
      port: uri.hasPort ? uri.port : null,
      path: '/',
    );
  }

  /// Derives direct OsmAnd protocol ingestion URI from base URL host and port (default: 5055).
  /// Targets plain 'http' Netty TrackerServer for direct local development endpoints.
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
