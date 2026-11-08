import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/event_model.dart';

/// Decoupled interface for audio playback to allow 100% headless unit testing.
abstract class AudioPlayerAdapter {
  Future<void> playAsset(String assetPath, {bool loop = true});
  Future<void> stop();
  Future<void> dispose();
}

/// Production implementation of [AudioPlayerAdapter] using [audioplayers].
class AudioplayersAdapter implements AudioPlayerAdapter {
  final AudioPlayer _player;

  AudioplayersAdapter({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  @override
  Future<void> playAsset(String assetPath, {bool loop = true}) async {
    try {
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      AppLogger.warn('AudioplayersAdapter: playAsset error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.warn('AudioplayersAdapter: stop error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

/// In-memory mock implementation of [AudioPlayerAdapter] for headless tests.
class MockAudioPlayerAdapter implements AudioPlayerAdapter {
  bool isPlaying = false;
  bool isDisposed = false;
  String? lastPlayedAsset;
  bool? lastLoop;
  int playCount = 0;
  int stopCount = 0;

  @override
  Future<void> playAsset(String assetPath, {bool loop = true}) async {
    isPlaying = true;
    lastPlayedAsset = assetPath;
    lastLoop = loop;
    playCount++;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    isPlaying = false;
    isDisposed = true;
  }
}

/// Service managing alarm siren playback, auto-silence timer, and mute controls.
class AlarmAudioService extends ChangeNotifier {
  final AudioPlayerAdapter adapter;
  final Duration defaultAutoSilenceDuration;

  bool _isPlaying = false;
  bool _isMuted = false;
  Timer? _autoSilenceTimer;

  static const String defaultAlarmAsset = 'audio/alarm.mp3';

  AlarmAudioService({
    AudioPlayerAdapter? adapter,
    this.defaultAutoSilenceDuration = const Duration(seconds: 30),
  }) : adapter = adapter ?? AudioplayersAdapter();

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get hasActiveTimer =>
      _autoSilenceTimer != null && _autoSilenceTimer!.isActive;

  /// Helper to decide if an incoming telematics event should trigger the siren.
  /// Standard triggers: SOS alert, tamper, high overspeed, vibration, accident.
  static bool shouldTriggerAlarm(EventModel event) {
    if (event.isSos) return true;
    if (event.isAlarm) {
      final alarm = event.alarmType?.toLowerCase();
      return alarm == EventModel.alarmSos ||
          alarm == EventModel.alarmTamper ||
          alarm == EventModel.alarmOverspeed ||
          alarm == EventModel.alarmAccident ||
          alarm == EventModel.alarmPowerCut ||
          alarm == EventModel.alarmVibration;
    }
    return false;
  }

  /// Triggers the alarm siren unless muted.
  Future<void> playAlarm({
    String? assetPath,
    Duration? autoSilenceDuration,
    bool loop = true,
  }) async {
    if (_isMuted) {
      AppLogger.info('AlarmAudioService: Alarm trigger suppressed (muted).');
      return;
    }

    _isPlaying = true;
    notifyListeners();

    await adapter.playAsset(assetPath ?? defaultAlarmAsset, loop: loop);

    // Reset and start auto-silence countdown
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = Timer(
      autoSilenceDuration ?? defaultAutoSilenceDuration,
      () async {
        AppLogger.info('AlarmAudioService: Auto-silence timeout reached.');
        await stopAlarm();
      },
    );
  }

  /// Immediately silences the alarm and sets mute state to prevent immediate re-trigger.
  Future<void> muteAlarm() async {
    _isMuted = true;
    await stopAlarm();
  }

  /// Unmutes the alarm for subsequent incidents.
  void resetMute() {
    _isMuted = false;
    notifyListeners();
  }

  /// Silences the audio and cancels the auto-silence timer without setting mute flag.
  Future<void> stopAlarm() async {
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = null;

    if (_isPlaying) {
      _isPlaying = false;
      await adapter.stop();
      notifyListeners();
    }
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = null;
    adapter.dispose();
    super.dispose();
  }
}
