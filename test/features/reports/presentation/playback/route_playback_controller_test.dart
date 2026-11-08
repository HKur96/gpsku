import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/domain/models/playback_state.dart';
import 'package:gpsku/features/reports/presentation/playback/route_playback_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('RoutePlaybackController State Machine & Animation Ticker Tests', () {
    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    final tPositions = [
      PositionModel(
        id: 1,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.2088,
        longitude: 106.8456,
        speed: 10.0, // knots
        course: 90.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 2,
        deviceId: 42,
        serverTime: tTime.add(const Duration(minutes: 5)),
        fixTime: tTime.add(const Duration(minutes: 5)),
        latitude: -6.2150,
        longitude: 106.8550,
        speed: 20.0,
        course: 120.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 3,
        deviceId: 42,
        serverTime: tTime.add(const Duration(minutes: 10)),
        fixTime: tTime.add(const Duration(minutes: 10)),
        latitude: -6.2200,
        longitude: 106.8650,
        speed: 0.0,
        course: 0.0,
        attributes: const {'ignition': false},
      ),
    ];

    test('TC-RPC-01: Initial state is idle when empty, paused when loaded', () {
      final controller = RoutePlaybackController();
      expect(controller.status, PlaybackStatus.idle);
      expect(controller.positions, isEmpty);

      controller.loadRoute(tPositions);
      expect(controller.status, PlaybackStatus.paused);
      expect(controller.positions.length, 3);
      expect(controller.currentIndex, 0.0);
      expect(controller.currentProgress, 0.0);
    });

    test(
      'TC-RPC-02: Play starts ticker and transitions to playing; pause stops ticker',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        controller.play();
        expect(controller.status, PlaybackStatus.playing);
        expect(controller.isPlaying, isTrue);

        controller.pause();
        expect(controller.status, PlaybackStatus.paused);
        expect(controller.isPaused, isTrue);
      },
    );

    test(
      'TC-RPC-03: togglePlayPause switches between play and pause cleanly',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        controller.togglePlayPause();
        expect(controller.isPlaying, isTrue);

        controller.togglePlayPause();
        expect(controller.isPaused, isTrue);
      },
    );

    test(
      'TC-RPC-04: tick(delta) advances currentIndex scaled by speed multiplier',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );
        controller.play();

        // At 1x speed: 1.0 delta advances by 1.0 index
        controller.tick(1.0);
        expect(controller.currentIndex, closeTo(1.0, 0.001));
        expect(controller.currentFloorIndex, 1);

        // Change speed to 2x: 0.5 delta advances by 0.5 * 2.0 = 1.0 index
        controller.setSpeed(PlaybackSpeed.speed2x);
        controller.tick(0.5);
        expect(controller.currentIndex, closeTo(2.0, 0.001));
        expect(controller.isCompleted, isTrue);
      },
    );

    test(
      'TC-RPC-05: Reaching the terminus transitions state to completed and stops ticker',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );
        controller.play();

        // Advance past total segments (N - 1 = 2)
        controller.tick(5.0);

        expect(controller.currentIndex, 2.0);
        expect(controller.status, PlaybackStatus.completed);
        expect(controller.isCompleted, isTrue);
        expect(controller.currentProgress, 1.0);
      },
    );

    test(
      'TC-RPC-06: seekToProgress updates index and telemetry immediately',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        // Halfway (50% progress)
        controller.seekToProgress(0.5);

        expect(controller.currentProgress, 0.5);
        expect(controller.currentIndex, 1.0);
        expect(controller.currentPositionModel?.id, 2);
        expect(controller.isIgnitionOn, isTrue);
      },
    );

    test(
      'TC-RPC-07: Scrubbing lifecycle pauses during drag and resumes on release',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );
        controller.play();

        // User touches and starts dragging slider
        controller.onScrubStart();
        expect(controller.isPaused, isTrue);

        // User drags slider to 25%
        controller.onScrubUpdate(0.25);
        expect(controller.currentProgress, 0.25);

        // User releases slider
        controller.onScrubEnd();
        expect(controller.isPlaying, isTrue);
        controller.dispose();
      },
    );

    test(
      'TC-RPC-08: stepForward and stepBackward move discretely by 1 fix',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        controller.stepForward();
        expect(controller.currentFloorIndex, 1);

        controller.stepForward();
        expect(controller.currentFloorIndex, 2);

        controller.stepBackward();
        expect(controller.currentFloorIndex, 1);
      },
    );

    test('TC-RPC-09: Speed multiplier selection updates multiplier value', () {
      final controller = RoutePlaybackController(initialPositions: tPositions);

      controller.setSpeed(PlaybackSpeed.speed4x);
      expect(controller.speed, PlaybackSpeed.speed4x);
      expect(controller.speed.multiplier, 4.0);

      controller.setSpeed(PlaybackSpeed.speed8x);
      expect(controller.speed, PlaybackSpeed.speed8x);
      expect(controller.speed.multiplier, 8.0);
    });

    test('TC-RPC-10: Camera follow mode toggling updates flag', () {
      final controller = RoutePlaybackController(initialPositions: tPositions);
      expect(controller.isCameraFollowEnabled, isFalse);

      controller.toggleCameraFollow();
      expect(controller.isCameraFollowEnabled, isTrue);

      controller.toggleCameraFollow();
      expect(controller.isCameraFollowEnabled, isFalse);
    });

    test(
      'TC-RPC-11: Edge-case: single point route does not crash or divide by zero',
      () {
        final single = [tPositions.first];
        final controller = RoutePlaybackController(initialPositions: single);

        expect(controller.currentProgress, 0.0);
        expect(controller.totalDistance, 0.0);
        expect(controller.currentDistanceTraveled, 0.0);
        expect(controller.currentInterpolatedCoordinate, isNotNull);

        controller.play();
        controller.tick(1.0);
        expect(controller.currentIndex, 0.0);
        controller.dispose();
      },
    );

    test(
      'TC-RPC-12: Dispatches onPositionUpdated callback during tick and seek',
      () {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );
        LatLng? lastCoord;
        double? lastBearing;

        controller.onPositionUpdated = (coord, bearing) {
          lastCoord = coord;
          lastBearing = bearing;
        };

        controller.seekToProgress(0.5);

        expect(lastCoord, isNotNull);
        expect(lastCoord!.latitude, closeTo(-6.2150, 0.001));
        expect(lastBearing, isNotNull);
      },
    );

    test('TC-RPC-13: Computes cumulative distance accurately', () {
      final controller = RoutePlaybackController(initialPositions: tPositions);

      expect(controller.totalDistance, greaterThan(0.0));
      expect(controller.totalDistanceKm, greaterThan(0.0));

      controller.seekToProgress(1.0);
      expect(
        controller.currentDistanceTraveled,
        equals(controller.totalDistance),
      );
    });

    test('TC-RPC-14: Restart resets progress to 0 and starts playing', () {
      final controller = RoutePlaybackController(initialPositions: tPositions);
      controller.seekToProgress(1.0);
      expect(controller.isCompleted, isTrue);

      controller.restart();
      expect(controller.currentProgress, 0.0);
      expect(controller.isPlaying, isTrue);
      controller.dispose();
    });
  });
}
