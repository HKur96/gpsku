import 'dart:async';
import '../../../../core/utils/app_logger.dart';
import '../../../fleet/data/datasources/traccar_websocket_service.dart';
import '../../data/models/event_model.dart';

/// Service responsible for real-time telematics event ingestion from Traccar WebSocket.
/// Buffers the latest [maxBufferSize] events (default 50) in memory (matching Traccar Web behavior)
/// and dispatches parsed [EventModel] entities to presentation subscribers.
class EventStreamService {
  final TraccarWebSocketService webSocketService;
  final int maxBufferSize;

  final List<EventModel> _bufferedEvents = [];
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  final _eventsBatchController = StreamController<List<EventModel>>.broadcast();
  final _singleEventController = StreamController<EventModel>.broadcast();

  EventStreamService({
    required this.webSocketService,
    this.maxBufferSize = 50,
  }) {
    _initWebSocketSubscription();
  }

  /// Read-only snapshot of buffered telematics events in chronological order (newest first).
  List<EventModel> get bufferedEvents => List.unmodifiable(_bufferedEvents);

  /// Broadcast stream emitting newly arrived batches of [EventModel].
  Stream<List<EventModel>> get eventsBatchStream =>
      _eventsBatchController.stream;

  /// Broadcast stream emitting each newly arrived [EventModel] individually.
  Stream<EventModel> get singleEventStream => _singleEventController.stream;

  void _initWebSocketSubscription() {
    _wsSub = webSocketService.messageStream.listen(
      _handleWebSocketMessage,
      onError: (dynamic error) {
        AppLogger.warn('EventStreamService WebSocket stream error: $error');
      },
    );
  }

  /// Parses incoming WebSocket payload for the `"events"` key.
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (!message.containsKey('events')) return;

    final rawEvents = message['events'];
    if (rawEvents is! List || rawEvents.isEmpty) return;

    final parsed = <EventModel>[];
    for (final item in rawEvents) {
      if (item is Map) {
        try {
          final event = EventModel.fromJson(Map<String, dynamic>.from(item));
          parsed.add(event);
        } catch (e) {
          AppLogger.warn('EventStreamService: Failed parsing event: $e');
        }
      }
    }

    if (parsed.isEmpty) return;

    // Filter out duplicates based on event.id to prevent double alerting on reconnect
    final existingIds = _bufferedEvents
        .map((e) => e.id)
        .where((id) => id > 0)
        .toSet();
    final uniqueNewEvents = <EventModel>[];
    for (final event in parsed) {
      if (event.id > 0 && existingIds.contains(event.id)) {
        AppLogger.info(
          'EventStreamService: Ignoring duplicate event #${event.id}',
        );
        continue;
      }
      uniqueNewEvents.add(event);
      if (event.id > 0) existingIds.add(event.id);
    }

    if (uniqueNewEvents.isEmpty) return;

    // Insert newest unique events at the beginning (index 0)
    _bufferedEvents.insertAll(0, uniqueNewEvents);

    // Limit buffer to maxBufferSize
    if (_bufferedEvents.length > maxBufferSize) {
      _bufferedEvents.removeRange(maxBufferSize, _bufferedEvents.length);
    }

    // Dispatch to stream subscribers
    if (!_eventsBatchController.isClosed) {
      _eventsBatchController.add(List.unmodifiable(uniqueNewEvents));
    }
    if (!_singleEventController.isClosed) {
      for (final event in uniqueNewEvents) {
        _singleEventController.add(event);
      }
    }
  }

  /// Manually ingest a list of events (useful for tests or replay).
  void ingestEvents(List<EventModel> events) {
    if (events.isEmpty) return;
    final existingIds = _bufferedEvents
        .map((e) => e.id)
        .where((id) => id > 0)
        .toSet();
    final uniqueNewEvents = <EventModel>[];
    for (final event in events) {
      if (event.id > 0 && existingIds.contains(event.id)) {
        continue;
      }
      uniqueNewEvents.add(event);
      if (event.id > 0) existingIds.add(event.id);
    }
    if (uniqueNewEvents.isEmpty) return;

    _bufferedEvents.insertAll(0, uniqueNewEvents);
    if (_bufferedEvents.length > maxBufferSize) {
      _bufferedEvents.removeRange(maxBufferSize, _bufferedEvents.length);
    }
    if (!_eventsBatchController.isClosed) {
      _eventsBatchController.add(List.unmodifiable(uniqueNewEvents));
    }
    if (!_singleEventController.isClosed) {
      for (final event in uniqueNewEvents) {
        _singleEventController.add(event);
      }
    }
  }

  /// Clears in-memory buffer (e.g. on logout / session termination).
  void clearBuffer() {
    _bufferedEvents.clear();
  }

  /// Disposes active subscriptions and controllers.
  void dispose() {
    _wsSub?.cancel();
    _wsSub = null;
    _eventsBatchController.close();
    _singleEventController.close();
  }
}
