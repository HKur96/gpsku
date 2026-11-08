import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/notifications/data/models/event_model.dart';
import 'package:gpsku/features/notifications/domain/services/event_stream_service.dart';

class MockTraccarWebSocketService extends TraccarWebSocketService {
  final _mockMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  MockTraccarWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  Stream<Map<String, dynamic>> get messageStream =>
      _mockMessageController.stream;

  void emitMessage(Map<String, dynamic> message) {
    _mockMessageController.add(message);
  }

  @override
  void dispose() {
    _mockMessageController.close();
    super.dispose();
  }
}

void main() {
  late MockTraccarWebSocketService mockWs;
  late EventStreamService service;

  setUp(() {
    mockWs = MockTraccarWebSocketService();
    service = EventStreamService(webSocketService: mockWs, maxBufferSize: 5);
  });

  tearDown(() {
    service.dispose();
    mockWs.dispose();
  });

  group('EventStreamService Unit Tests', () {
    test(
      'TC-ESS-01: ingests WebSocket {"events": [...]} and updates buffer',
      () async {
        expect(service.bufferedEvents, isEmpty);

        mockWs.emitMessage({
          'events': [
            {
              'id': 101,
              'type': 'deviceOnline',
              'deviceId': 5,
              'eventTime': '2026-11-08T15:00:00.000Z',
            },
            {
              'id': 102,
              'type': 'alarm',
              'deviceId': 5,
              'eventTime': '2026-11-08T15:01:00.000Z',
              'attributes': {'alarm': 'sos'},
            },
          ],
        });

        // Pump microtasks to allow stream delivery
        await Future<void>.delayed(Duration.zero);

        expect(service.bufferedEvents.length, 2);
        expect(service.bufferedEvents[0].id, 101);
        expect(service.bufferedEvents[1].id, 102);
        expect(service.bufferedEvents[1].isSos, isTrue);
      },
    );

    test(
      'TC-ESS-02: dispatches events to eventsBatchStream and singleEventStream',
      () async {
        final batchCompleter = Completer<List<EventModel>>();
        final singleEvents = <EventModel>[];

        final batchSub = service.eventsBatchStream.listen(
          batchCompleter.complete,
        );
        final singleSub = service.singleEventStream.listen(singleEvents.add);

        mockWs.emitMessage({
          'events': [
            {'id': 201, 'type': 'deviceMoving', 'deviceId': 10},
            {'id': 202, 'type': 'deviceStopped', 'deviceId': 10},
          ],
        });

        final batch = await batchCompleter.future;
        expect(batch.length, 2);
        expect(batch.first.id, 201);
        expect(batch.last.id, 202);

        await Future<void>.delayed(Duration.zero);
        expect(singleEvents.length, 2);
        expect(singleEvents.map((e) => e.id), [201, 202]);

        await batchSub.cancel();
        await singleSub.cancel();
      },
    );

    test(
      'TC-ESS-03: enforces maxBufferSize window discarding older events',
      () async {
        // Buffer size configured as 5 in setUp
        for (int i = 1; i <= 7; i++) {
          mockWs.emitMessage({
            'events': [
              {'id': i, 'type': 'deviceOnline', 'deviceId': i},
            ],
          });
          await Future<void>.delayed(Duration.zero);
        }

        expect(service.bufferedEvents.length, 5);
        // Newest events (7, 6, 5, 4, 3) must be retained
        expect(service.bufferedEvents.map((e) => e.id), [7, 6, 5, 4, 3]);
      },
    );

    test('TC-ESS-04: ignores unrelated WebSocket payloads', () async {
      mockWs.emitMessage({
        'positions': [
          {'id': 1, 'deviceId': 2},
        ],
      });
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedEvents, isEmpty);
    });

    test('TC-ESS-05: clearBuffer empties the buffered events', () async {
      service.ingestEvents([
        const EventModel(id: 1, type: 'alarm'),
        const EventModel(id: 2, type: 'deviceMoving'),
      ]);

      expect(service.bufferedEvents.length, 2);

      service.clearBuffer();

      expect(service.bufferedEvents, isEmpty);
    });

    test('TC-ESS-06: returns unmodifiable collection for bufferedEvents', () {
      service.ingestEvents([const EventModel(id: 1, type: 'alarm')]);

      expect(
        () =>
            service.bufferedEvents.add(const EventModel(id: 2, type: 'alarm')),
        throwsUnsupportedError,
      );
    });

    test(
      'TC-ESS-07: deduplicates events based on id avoiding double alerts',
      () async {
        int batchCount = 0;
        service.eventsBatchStream.listen((_) => batchCount++);

        // Emit initial event #50
        mockWs.emitMessage({
          'events': [
            {'id': 50, 'type': 'alarm', 'deviceId': 1},
          ],
        });
        await Future<void>.delayed(Duration.zero);
        expect(service.bufferedEvents.length, 1);
        expect(batchCount, 1);

        // Reconnect sends duplicate event #50 and new event #51
        mockWs.emitMessage({
          'events': [
            {'id': 50, 'type': 'alarm', 'deviceId': 1}, // Duplicate
            {'id': 51, 'type': 'deviceMoving', 'deviceId': 1}, // New
          ],
        });
        await Future<void>.delayed(Duration.zero);

        expect(service.bufferedEvents.length, 2);
        expect(service.bufferedEvents.map((e) => e.id), [51, 50]);
        expect(batchCount, 2); // Dispatched only the new event!
      },
    );
  });
}
