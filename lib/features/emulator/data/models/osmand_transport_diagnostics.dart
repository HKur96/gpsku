import 'package:flutter/foundation.dart';

/// Distinguishes the physical transport path used to reach Traccar's OsmAnd decoder.
enum OsmandTransportMode {
  /// Direct TCP/HTTP connection to Netty OsmAnd TrackerServer (e.g. port 5055).
  directHttpPort,

  /// Encrypted HTTPS reverse-proxy (`POST https://<domain>/`) routed via Traccar WebServer.initClientProxy().
  httpsWebProxy,

  /// Local HTTP proxy fallback (`POST http://<host>:<webPort>/`) used after direct port 5055 failed.
  httpWebProxyFallback,
}

/// Immutable diagnostic record describing the exact OsmAnd transport path used.
@immutable
class OsmandTransportDiagnostics {
  final OsmandTransportMode mode;
  final Uri endpointUri;
  final String httpMethod;
  final int? statusCode;
  final String? initialDirectFailureReason;
  final DateTime timestamp;

  const OsmandTransportDiagnostics({
    required this.mode,
    required this.endpointUri,
    required this.httpMethod,
    this.statusCode,
    this.initialDirectFailureReason,
    required this.timestamp,
  });

  bool get isDirectMode => mode == OsmandTransportMode.directHttpPort;
  bool get isHttpsProxy => mode == OsmandTransportMode.httpsWebProxy;
  bool get isFallbackProxy => mode == OsmandTransportMode.httpWebProxyFallback;
  bool get isProxyMode => mode != OsmandTransportMode.directHttpPort;

  String get modeLabel {
    switch (mode) {
      case OsmandTransportMode.directHttpPort:
        return 'Direct HTTP Port ${endpointUri.hasPort ? endpointUri.port : 5055}';
      case OsmandTransportMode.httpsWebProxy:
        return 'HTTPS Web Proxy (POST / → OsmAnd)';
      case OsmandTransportMode.httpWebProxyFallback:
        return 'Fallback HTTP Proxy (:${endpointUri.hasPort ? endpointUri.port : 8082} → OsmAnd)';
    }
  }
}

/// Companion contract for datasources/repositories exposing transport diagnostics
/// without breaking simpler mocks.
abstract interface class OsmandTransportDiagnosticsProvider {
  OsmandTransportDiagnostics? get lastTransportDiagnostics;
}
