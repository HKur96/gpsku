import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/event_model.dart';
import '../../domain/services/event_stream_service.dart';
import '../services/alarm_audio_service.dart';

enum EventCategoryFilter { all, alarm, deviceStatus, geofence }

/// State management provider for real-time telematics notifications and emergency alerts.
class NotificationsProvider extends ChangeNotifier {
  final EventStreamService eventStreamService;
  final AlarmAudioService alarmAudioService;

  final Set<int> _readEventIds = {};
  EventCategoryFilter _selectedFilter = EventCategoryFilter.all;
  EventModel? _activeEmergencyEvent;
  StreamSubscription<List<EventModel>>? _eventsBatchSub;

  NotificationsProvider({
    required this.eventStreamService,
    required this.alarmAudioService,
  }) {
    _initSubscription();
  }

  void _initSubscription() {
    _eventsBatchSub = eventStreamService.eventsBatchStream.listen(
      _onNewEventsArrived,
    );
  }

  void _onNewEventsArrived(List<EventModel> newEvents) {
    if (newEvents.isEmpty) return;

    // Check for critical alarm/SOS events to trigger siren & banner
    for (final event in newEvents) {
      if (AlarmAudioService.shouldTriggerAlarm(event)) {
        _activeEmergencyEvent = event;
        // Unmute for new emergency incident and trigger siren
        alarmAudioService.resetMute();
        alarmAudioService.playAlarm();
        break;
      }
    }

    notifyListeners();
  }

  /// All buffered events (newest first).
  List<EventModel> get events => eventStreamService.bufferedEvents;

  /// Currently selected category filter.
  EventCategoryFilter get selectedFilter => _selectedFilter;

  /// Active critical emergency incident event to display on banner, if any.
  EventModel? get activeEmergencyEvent => _activeEmergencyEvent;

  /// Number of unread events in the buffer.
  int get unreadCount {
    return events.where((e) => !_readEventIds.contains(e.id)).length;
  }

  /// Returns filtered events based on active category.
  List<EventModel> get filteredEvents {
    switch (_selectedFilter) {
      case EventCategoryFilter.alarm:
        return events.where((e) => e.isAlarm).toList();
      case EventCategoryFilter.deviceStatus:
        return events.where((e) => e.isDeviceStatus).toList();
      case EventCategoryFilter.geofence:
        return events.where((e) => e.isGeofence).toList();
      case EventCategoryFilter.all:
        return events;
    }
  }

  /// Updates active filter category.
  void setFilter(EventCategoryFilter filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  /// Marks an individual event as read.
  void markAsRead(int eventId) {
    if (!_readEventIds.contains(eventId)) {
      _readEventIds.add(eventId);
      notifyListeners();
    }
  }

  /// Marks all current events in the buffer as read.
  void markAllAsRead() {
    for (final e in events) {
      _readEventIds.add(e.id);
    }
    notifyListeners();
  }

  /// Dismisses active emergency banner and silences siren.
  void dismissEmergencyBanner() {
    _activeEmergencyEvent = null;
    alarmAudioService.muteAlarm();
    notifyListeners();
  }

  /// Silences alarm siren without dismissing banner.
  void muteAlarm() {
    alarmAudioService.muteAlarm();
    notifyListeners();
  }

  /// Clears in-memory buffer, unread IDs, active banner, and stops audio siren.
  void clearAll() {
    eventStreamService.clearBuffer();
    _readEventIds.clear();
    _activeEmergencyEvent = null;
    alarmAudioService.stopAlarm();
    notifyListeners();
  }

  @override
  void dispose() {
    _eventsBatchSub?.cancel();
    _eventsBatchSub = null;
    super.dispose();
  }
}
