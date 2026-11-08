import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/domain/models/playback_state.dart';
import 'package:gpsku/features/reports/presentation/playback/route_playback_controller.dart';
import 'package:gpsku/features/reports/presentation/widgets/playback/route_playback_sheet.dart';

void main() {
  group('RoutePlaybackSheet Widget Tests', () {
    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    final tPositions = [
      PositionModel(
        id: 1,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.2088,
        longitude: 106.8456,
        speed: 25.0, // knots -> 46.3 km/h
        course: 90.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 2,
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

    Widget buildTestWidget(RoutePlaybackController controller) {
      return MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RoutePlaybackSheet(controller: controller),
          ),
        ),
      );
    }

    testWidgets(
      'TC-RPS-01: Renders active telemetry metrics: speed, ACC ON, distance',
      (tester) async {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        await tester.pumpWidget(buildTestWidget(controller));
        await tester.pump();

        // Verify speed rendered
        expect(find.textContaining('46.3 km/h'), findsOneWidget);

        // Verify ACC ON badge rendered
        expect(find.text('ACC ON'), findsOneWidget);

        // Verify Distance Traveled rendered
        expect(find.textContaining('km'), findsWidgets);

        // Verify Slider exists
        expect(find.byType(Slider), findsOneWidget);
      },
    );

    testWidgets('TC-RPS-02: Tapping Play/Pause button toggles playback state', (
      tester,
    ) async {
      final controller = RoutePlaybackController(initialPositions: tPositions);

      await tester.pumpWidget(buildTestWidget(controller));
      await tester.pump();

      expect(controller.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Tap Play
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(controller.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(controller.isPaused, isTrue);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      controller.dispose();
    });

    testWidgets(
      'TC-RPS-03: Tapping Speed pill cycles 1x -> 2x -> 4x -> 8x -> 1x',
      (tester) async {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        await tester.pumpWidget(buildTestWidget(controller));
        await tester.pump();

        expect(find.text('1x'), findsOneWidget);

        await tester.tap(find.text('1x'));
        await tester.pump();
        expect(controller.speed, PlaybackSpeed.speed2x);
        expect(find.text('2x'), findsOneWidget);

        await tester.tap(find.text('2x'));
        await tester.pump();
        expect(controller.speed, PlaybackSpeed.speed4x);
        expect(find.text('4x'), findsOneWidget);

        await tester.tap(find.text('4x'));
        await tester.pump();
        expect(controller.speed, PlaybackSpeed.speed8x);
        expect(find.text('8x'), findsOneWidget);

        await tester.tap(find.text('8x'));
        await tester.pump();
        expect(controller.speed, PlaybackSpeed.speed1x);
        expect(find.text('1x'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-RPS-04: Tapping Step Forward and Step Backward buttons updates index',
      (tester) async {
        final controller = RoutePlaybackController(
          initialPositions: tPositions,
        );

        await tester.pumpWidget(buildTestWidget(controller));
        await tester.pump();

        expect(controller.currentFloorIndex, 0);

        // Tap Forward
        await tester.tap(find.byIcon(Icons.skip_next));
        await tester.pump();
        expect(controller.currentFloorIndex, 1);

        // Tap Backward
        await tester.tap(find.byIcon(Icons.skip_previous));
        await tester.pump();
        expect(controller.currentFloorIndex, 0);
      },
    );

    testWidgets('TC-RPS-05: Tapping Camera Follow button toggles follow mode', (
      tester,
    ) async {
      final controller = RoutePlaybackController(initialPositions: tPositions);

      await tester.pumpWidget(buildTestWidget(controller));
      await tester.pump();

      expect(controller.isCameraFollowEnabled, isFalse);

      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pump();

      expect(controller.isCameraFollowEnabled, isTrue);
      expect(find.byIcon(Icons.near_me), findsOneWidget);
    });

    testWidgets('TC-RPS-06: Renders Replay icon when status is completed', (
      tester,
    ) async {
      final controller = RoutePlaybackController(initialPositions: tPositions);
      controller.seekToProgress(1.0);

      await tester.pumpWidget(buildTestWidget(controller));
      await tester.pump();

      expect(controller.isCompleted, isTrue);
      expect(find.byIcon(Icons.replay), findsOneWidget);

      // Tapping Replay restarts playback
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pump();

      expect(controller.currentProgress, 0.0);
      expect(controller.isPlaying, isTrue);

      controller.pause();
      await tester.pump();
      controller.dispose();
    });

    testWidgets('TC-RPS-07: Empty route positions renders empty widget', (
      tester,
    ) async {
      final controller = RoutePlaybackController();

      await tester.pumpWidget(buildTestWidget(controller));
      await tester.pump();

      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Container), findsNothing);
    });
  });
}
