import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/domain/models/playback_state.dart';
import 'package:gpsku/features/reports/presentation/playback/route_playback_controller.dart';

/// Interactive mobile control sheet for historical route telemetry playback.
///
/// Features:
/// 1. Timeline scrub bar slider with start/current/end timestamps.
/// 2. Active telemetry metric card (speed, ignition ACC, distance traveled, local timestamp).
/// 3. Media control actions (Play, Pause, Replay, Step Forward, Step Backward).
/// 4. Speed multiplier toggle pill (1x, 2x, 4x, 8x).
/// 5. Camera follow mode toggle.
class RoutePlaybackSheet extends StatelessWidget {
  final RoutePlaybackController controller;
  final VoidCallback? onClose;

  const RoutePlaybackSheet({super.key, required this.controller, this.onClose});

  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final positions = controller.positions;
        final currentPos = controller.currentPositionModel;

        if (positions.isEmpty) {
          return const SizedBox.shrink();
        }

        final startTimeStr = _timeFormat.format(
          positions.first.fixTime.toLocal(),
        );
        final endTimeStr = _timeFormat.format(positions.last.fixTime.toLocal());
        final currentTimeStr = currentPos != null
            ? _dateTimeFormat.format(currentPos.fixTime.toLocal())
            : '--';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16.0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Drag handle & Header
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),

                  // 2. Active Telemetry Metric Card
                  _buildTelemetryCard(context, currentPos, currentTimeStr),
                  const SizedBox(height: 10.0),

                  // 3. Scrub Bar Slider & Timestamps
                  _buildScrubBar(context, startTimeStr, endTimeStr),

                  // 4. Playback Controls Bar
                  _buildControlsRow(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryCard(
    BuildContext context,
    PositionModel? currentPos,
    String currentTimeStr,
  ) {
    final speedKmh = controller.currentSpeedKmh.toStringAsFixed(1);
    final distanceKm = controller.currentDistanceTraveledKm.toStringAsFixed(1);
    final totalKm = controller.totalDistanceKm.toStringAsFixed(1);
    final isIgnitionOn = controller.isIgnitionOn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Row 1: Timestamp & Ignition badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 15.0,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5.0),
                  Text(
                    currentTimeStr,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: isIgnitionOn
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isIgnitionOn
                        ? const Color(0xFF81C784)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  isIgnitionOn ? 'ACC ON' : 'ACC OFF',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: isIgnitionOn
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),

          // Row 2: Speed & Distance Traveled
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, size: 16.0, color: Color(0xFF1E88E5)),
                  const SizedBox(width: 5.0),
                  Text(
                    '$speedKmh km/h',
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.route, size: 16.0, color: Color(0xFF00ACC1)),
                  const SizedBox(width: 5.0),
                  Text(
                    '$distanceKm / $totalKm km',
                    style: const TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrubBar(
    BuildContext context,
    String startTimeStr,
    String endTimeStr,
  ) {
    final positions = controller.positions;
    final currentIndexStr =
        '${controller.currentFloorIndex + 1}/${positions.length}';

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: const Color(0xFF1E88E5),
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: const Color(0xFF1E88E5),
          ),
          child: Slider(
            value: controller.currentProgress,
            min: 0.0,
            max: 1.0,
            onChangeStart: (_) => controller.onScrubStart(),
            onChanged: (val) => controller.onScrubUpdate(val),
            onChangeEnd: (_) => controller.onScrubEnd(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                startTimeStr,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              Text(
                currentIndexStr,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                endTimeStr,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context) {
    final status = controller.status;
    final isPlaying = status == PlaybackStatus.playing;
    final isCompleted = status == PlaybackStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Camera Follow Mode Toggle
          IconButton(
            tooltip: 'Ikuti Kamera',
            icon: Icon(
              controller.isCameraFollowEnabled
                  ? Icons.near_me
                  : Icons.near_me_outlined,
              color: controller.isCameraFollowEnabled
                  ? const Color(0xFF1E88E5)
                  : Colors.grey.shade500,
            ),
            onPressed: () => controller.toggleCameraFollow(),
          ),

          // 2. Step Backward
          IconButton(
            tooltip: 'Langkah Mundur',
            icon: const Icon(Icons.skip_previous),
            color: const Color(0xFF1E293B),
            onPressed: controller.currentFloorIndex > 0
                ? () => controller.stepBackward()
                : null,
          ),

          // 3. Central Play / Pause / Replay FAB
          Material(
            color: const Color(0xFF1E88E5),
            shape: const CircleBorder(),
            elevation: 3.0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (isCompleted) {
                  controller.restart();
                } else {
                  controller.togglePlayPause();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  isCompleted
                      ? Icons.replay
                      : isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 28.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 4. Step Forward
          IconButton(
            tooltip: 'Langkah Maju',
            icon: const Icon(Icons.skip_next),
            color: const Color(0xFF1E293B),
            onPressed:
                controller.currentFloorIndex < controller.positions.length - 1
                ? () => controller.stepForward()
                : null,
          ),

          // 5. Speed Multiplier Pill (Cycles 1x -> 2x -> 4x -> 8x -> 1x)
          InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () {
              final nextSpeed = switch (controller.speed) {
                PlaybackSpeed.speed1x => PlaybackSpeed.speed2x,
                PlaybackSpeed.speed2x => PlaybackSpeed.speed4x,
                PlaybackSpeed.speed4x => PlaybackSpeed.speed8x,
                PlaybackSpeed.speed8x => PlaybackSpeed.speed1x,
              };
              controller.setSpeed(nextSpeed);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                controller.speed.label,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
