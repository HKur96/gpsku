import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/io.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/session_cookie_jar.dart';
import '../../../../core/utils/app_logger.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Real-time WebSocket connection service managing session-cookie handshake,
/// reconnection state machine, exponential backoff with jitter, and stream dispatch.
class TraccarWebSocketService {
  final AppConfig appConfig;
  final SessionCookieJar cookieJar;

  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  bool _manuallyDisconnected = false;
  int _reconnectAttempts = 0;
  static const int _maxBackoffSeconds = 30;

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  TraccarWebSocketService({required this.appConfig, required this.cookieJar});

  WebSocketConnectionState get state => _state;
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Connects to Traccar WebSocket endpoint (/api/socket) using active session cookie.
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_state == WebSocketConnectionState.connected ||
        _state == WebSocketConnectionState.connecting) {
      return;
    }

    final cookieHeader = cookieJar.webSocketCookieHeader;
    if (cookieHeader == null || cookieHeader.isEmpty) {
      AppLogger.warn(
        'Cannot connect WebSocket: No valid JSESSIONID cookie available.',
      );
      _updateState(WebSocketConnectionState.disconnected);
      return;
    }

    _manuallyDisconnected = false;
    _updateState(
      _reconnectAttempts > 0
          ? WebSocketConnectionState.reconnecting
          : WebSocketConnectionState.connecting,
    );

    try {
      final wsUri = appConfig.webSocketUri;
      AppLogger.info('Connecting to Traccar WebSocket: $wsUri');

      _channel = IOWebSocketChannel.connect(
        wsUri,
        headers: {'Cookie': cookieHeader},
        pingInterval: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 15),
      );

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      await _channel!.ready;

      _reconnectAttempts = 0;
      _updateState(WebSocketConnectionState.connected);
      AppLogger.info('Traccar WebSocket successfully connected.');
    } catch (e, stack) {
      AppLogger.error('Traccar WebSocket connection error', e, stack);
      _handleDisconnectAndReconnect();
    }
  }

  void _onMessageReceived(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          _messageController.add(decoded);
        } else if (decoded is Map) {
          _messageController.add(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      AppLogger.warn('Failed to parse incoming WebSocket message: $e');
    }
  }

  void _onError(dynamic error) {
    AppLogger.error('Traccar WebSocket stream error', error);
    _handleDisconnectAndReconnect();
  }

  void _onDone() {
    AppLogger.info('Traccar WebSocket connection closed by peer.');
    _handleDisconnectAndReconnect();
  }

  void _handleDisconnectAndReconnect() {
    _cleanupSocket();

    if (_manuallyDisconnected || _isDisposed) {
      _updateState(WebSocketConnectionState.disconnected);
      return;
    }

    _updateState(WebSocketConnectionState.reconnecting);

    // Calculate exponential backoff with random jitter
    _reconnectAttempts++;
    final baseBackoff = min(
      pow(2, _reconnectAttempts - 1).toInt(),
      _maxBackoffSeconds,
    );
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: baseBackoff, milliseconds: jitterMs);

    AppLogger.info(
      'Scheduling WebSocket reconnect in ${delay.inMilliseconds}ms (attempt #$_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected && !_isDisposed) {
        connect();
      }
    });
  }

  /// Manually disconnects the WebSocket without scheduling automatic reconnect.
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _cleanupSocket();
    _reconnectAttempts = 0;
    _updateState(WebSocketConnectionState.disconnected);
    AppLogger.info('Traccar WebSocket manually disconnected.');
  }

  void _cleanupSocket() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _updateState(WebSocketConnectionState newState) {
    if (_state != newState && !_stateController.isClosed) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}
