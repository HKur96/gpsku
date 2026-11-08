import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';

class FakeTraccarWebSocketService extends TraccarWebSocketService {
  final _mockStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _mockMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  FakeTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  Stream<WebSocketConnectionState> get stateStream =>
      _mockStateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream =>
      _mockMessageController.stream;

  void emitMessage(Map<String, dynamic> msg) {
    _mockMessageController.add(msg);
  }

  void emitState(WebSocketConnectionState state) {
    _mockStateController.add(state);
  }

  @override
  void dispose() {
    _mockStateController.close();
    _mockMessageController.close();
    super.dispose();
  }
}

void main() {
  group('LiveFleetProvider Coalescing Buffer & Telematics Tests', () {
    late FakeTraccarWebSocketService fakeWs;
    late LiveFleetProvider provider;

    setUp(() {
      fakeWs = FakeTraccarWebSocketService();
      provider = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 60),
      );
    });

    tearDown(() {
      provider.dispose();
      fakeWs.dispose();
    });

    test(
      'TC-LFP-01: Rapid WebSocket burst is coalesced within window before notifying listeners',
      () async {
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        final t0 = DateTime.parse('2026-11-07T10:00:00.000Z');

        // Burst of 5 packets sent in rapid succession for device 1
        for (int i = 1; i <= 5; i++) {
          fakeWs.emitMessage({
            'positions': [
              {
                'id': 100 + i,
                'deviceId': 1,
                'fixTime': t0.add(Duration(seconds: i)).toIso8601String(),
                'latitude': -6.2000 + (i * 0.001),
                'longitude': 106.8166 + (i * 0.001),
                'speed': 20.0 + i,
              },
            ],
          });
        }

        // Allow microtask to process stream reception into pending buffer
        await Future.delayed(const Duration(milliseconds: 10));

        // Immediately after burst, coalescing buffer is holding pending updates (0 UI notifications so far)
        expect(notifyCount, equals(0));
        expect(provider.hasActiveBuffer, isTrue);

        // Wait for the coalescing timer (60ms) to flush
        await Future.delayed(const Duration(milliseconds: 90));

        // Exactly ONE aggregated UI notification fired instead of 5 individual rebuilds
        expect(notifyCount, equals(1));
        expect(provider.positions.containsKey(1), isTrue);

        // The position has the latest state from the burst
        final finalPos = provider.positions[1]!;
        expect(finalPos.id, equals(105));
        expect(finalPos.speed, equals(25.0));
      },
    );

    test(
      'TC-LFP-02: Stale out-of-order packets inside burst are filtered out by PositionOrderingGuard',
      () async {
        final t0 = DateTime.parse('2026-11-07T10:00:00.000Z');

        // Packet 1: Normal update
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 200,
              'deviceId': 2,
              'fixTime': t0.add(const Duration(seconds: 10)).toIso8601String(),
              'latitude': -6.2100,
              'longitude': 106.8200,
              'speed': 40.0,
            },
          ],
        });

        // Packet 2: Delayed out-of-order packet with older fixTime (5s ago)
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 195,
              'deviceId': 2,
              'fixTime': t0.add(const Duration(seconds: 5)).toIso8601String(),
              'latitude': -6.2050,
              'longitude': 106.8150,
              'speed': 30.0,
            },
          ],
        });

        // Allow microtasks to receive both stream messages
        await Future.delayed(const Duration(milliseconds: 10));

        // Flush immediately
        provider.flushImmediately();

        final pos = provider.positions[2]!;
        expect(pos.id, equals(200));
        expect(
          pos.speed,
          equals(40.0),
          reason: 'Stale packet 195 must be rejected',
        );
      },
    );

    test(
      'TC-LFP-03: Devices and positions in multi-payload packet are both aggregated',
      () async {
        fakeWs.emitMessage({
          'devices': [
            {
              'id': 10,
              'name': 'Truck Express 01',
              'uniqueId': 'TRK-001',
              'status': 'online',
            },
          ],
          'positions': [
            {
              'id': 501,
              'deviceId': 10,
              'fixTime': '2026-11-07T10:05:00.000Z',
              'latitude': -6.3000,
              'longitude': 106.8500,
              'speed': 55.0,
            },
          ],
        });

        // Allow microtask to process stream reception
        await Future.delayed(const Duration(milliseconds: 10));

        provider.flushImmediately();

        expect(provider.devices.containsKey(10), isTrue);
        expect(provider.devices[10]!.name, equals('Truck Express 01'));
        expect(provider.positions.containsKey(10), isTrue);
        expect(provider.positions[10]!.id, equals(501));
      },
    );
  });
}
