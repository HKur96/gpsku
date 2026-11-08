import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/notifications/data/models/event_model.dart';
import 'package:gpsku/features/notifications/presentation/services/alarm_audio_service.dart';

void main() {
  group('AlarmAudioService Unit Tests', () {
    late MockAudioPlayerAdapter mockAdapter;
    late AlarmAudioService service;

    setUp(() {
      mockAdapter = MockAudioPlayerAdapter();
      service = AlarmAudioService(
        adapter: mockAdapter,
        defaultAutoSilenceDuration: const Duration(milliseconds: 100),
      );
    });

    tearDown(() {
      if (!service.isDisposed) {
        service.dispose();
      }
    });

    test('TC-AAS-01: initial state is idle and unmuted', () {
      expect(service.isPlaying, isFalse);
      expect(service.isMuted, isFalse);
      expect(service.hasActiveTimer, isFalse);
    });

    test(
      'TC-AAS-02: playAlarm initiates playback and starts auto-silence timer',
      () async {
        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.playAlarm(assetPath: 'audio/siren.mp3');

        expect(service.isPlaying, isTrue);
        expect(mockAdapter.isPlaying, isTrue);
        expect(mockAdapter.lastPlayedAsset, 'audio/siren.mp3');
        expect(mockAdapter.lastLoop, isTrue);
        expect(service.hasActiveTimer, isTrue);
        expect(notifyCount, 1);
      },
    );

    test(
      'TC-AAS-03: shouldTriggerAlarm detects critical alarm types correctly',
      () {
        // SOS alert
        final sosEvent = const EventModel(
          id: 1,
          type: 'alarm',
          attributes: {'alarm': 'sos'},
        );
        expect(AlarmAudioService.shouldTriggerAlarm(sosEvent), isTrue);

        // Tamper alert
        final tamperEvent = const EventModel(
          id: 2,
          type: 'alarm',
          attributes: {'alarm': 'tamper'},
        );
        expect(AlarmAudioService.shouldTriggerAlarm(tamperEvent), isTrue);

        // Overspeed alarm
        final speedEvent = const EventModel(
          id: 3,
          type: 'alarm',
          attributes: {'alarm': 'overspeed'},
        );
        expect(AlarmAudioService.shouldTriggerAlarm(speedEvent), isTrue);

        // Regular device moving event
        final movingEvent = const EventModel(id: 4, type: 'deviceMoving');
        expect(AlarmAudioService.shouldTriggerAlarm(movingEvent), isFalse);
      },
    );

    test(
      'TC-AAS-04: muteAlarm halts audio and blocks subsequent triggers',
      () async {
        await service.playAlarm();
        expect(service.isPlaying, isTrue);

        await service.muteAlarm();

        expect(service.isPlaying, isFalse);
        expect(service.isMuted, isTrue);
        expect(mockAdapter.isPlaying, isFalse);
        expect(service.hasActiveTimer, isFalse);

        // Subsequent play attempt while muted
        await service.playAlarm();
        expect(service.isPlaying, isFalse);
        expect(mockAdapter.playCount, 1); // Not incremented!
      },
    );

    test('TC-AAS-05: resetMute allows subsequent audio triggers', () async {
      await service.muteAlarm();
      expect(service.isMuted, isTrue);

      service.resetMute();
      expect(service.isMuted, isFalse);

      await service.playAlarm();
      expect(service.isPlaying, isTrue);
      expect(mockAdapter.isPlaying, isTrue);
    });

    test(
      'TC-AAS-06: stopAlarm silences audio without setting mute flag',
      () async {
        await service.playAlarm();
        await service.stopAlarm();

        expect(service.isPlaying, isFalse);
        expect(service.isMuted, isFalse); // Still unmuted
        expect(mockAdapter.isPlaying, isFalse);
      },
    );

    test(
      'TC-AAS-07: auto-silence timer automatically silences playback',
      () async {
        await service.playAlarm(
          autoSilenceDuration: const Duration(milliseconds: 50),
        );
        expect(service.isPlaying, isTrue);

        // Wait for auto-silence duration to lapse
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(service.isPlaying, isFalse);
        expect(mockAdapter.isPlaying, isFalse);
      },
    );

    test('TC-AAS-08: dispose cleans up timer and audio adapter', () async {
      await service.playAlarm();
      service.dispose();

      expect(mockAdapter.isDisposed, isTrue);
      expect(service.hasActiveTimer, isFalse);
    });

    test(
      'TC-AAS-09: successive playAlarm calls cancel previous auto-silence timer preventing premature silencing',
      () async {
        // Trigger first alarm with 100ms auto-silence
        await service.playAlarm(
          autoSilenceDuration: const Duration(milliseconds: 100),
        );
        expect(service.isPlaying, isTrue);

        // Wait 60ms (first timer has 40ms remaining)
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(service.isPlaying, isTrue);

        // Trigger second alarm with another 100ms auto-silence (should cancel first timer)
        await service.playAlarm(
          autoSilenceDuration: const Duration(milliseconds: 100),
        );

        // Wait 60ms (total 120ms from start; first timer would have fired at 100ms if not cancelled)
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          service.isPlaying,
          isTrue,
          reason: 'First timer should have been cancelled by second call',
        );

        // Wait remaining 60ms for second timer (total 120ms since second call)
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          service.isPlaying,
          isFalse,
          reason: 'Second timer should have silenced playback',
        );
      },
    );
  });
}
