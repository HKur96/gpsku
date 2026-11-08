import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../providers/notifications_provider.dart';

/// Prominent red emergency alert banner (#DC2626) displayed atop [FleetShellScreen]
/// when a critical telematics alarm or SOS alert is actively ringing.
class EmergencyAlertBanner extends StatelessWidget {
  final void Function(int deviceId)? onCenterDevice;

  const EmergencyAlertBanner({super.key, this.onCenterDevice});

  static const Color bannerColor = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationsProvider>();
    final activeEvent = notifProvider.activeEmergencyEvent;

    if (activeEvent == null) {
      return const SizedBox.shrink();
    }

    final isMuted = notifProvider.alarmAudioService.isMuted;
    final isPlaying = notifProvider.alarmAudioService.isPlaying;

    // Resolve vehicle name if LiveFleetProvider is available
    String deviceLabel = 'Unit #${activeEvent.deviceId}';
    try {
      final fleet = context.watch<LiveFleetProvider>();
      final device = fleet.devices[activeEvent.deviceId];
      if (device != null && device.name.isNotEmpty) {
        deviceLabel = device.name;
      }
    } catch (_) {
      // LiveFleetProvider may not be present in isolated test harness
    }

    final alarmType = activeEvent.isSos
        ? 'SOS DARURAT'
        : (activeEvent.alarmType?.toUpperCase() ?? 'ALARM TELEMATIKA');

    final timeString = activeEvent.eventTime != null
        ? DateFormat('HH:mm:ss').format(activeEvent.eventTime!.toLocal())
        : DateFormat('HH:mm:ss').format(DateTime.now());

    return Container(
      key: const Key('emergency_alert_banner'),
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarmType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$deviceLabel • $timeString',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('emergency_banner_dismiss_button'),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  tooltip: 'Tutup Peringatan',
                  onPressed: () => notifProvider.dismissEmergencyBanner(),
                ),
              ],
            ),
            if (activeEvent.message != null &&
                activeEvent.message!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                activeEvent.message!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('emergency_banner_mute_button'),
                    icon: Icon(
                      isMuted || !isPlaying
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      isMuted || !isPlaying ? 'Tersennyap' : 'Senyapkan',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => notifProvider.muteAlarm(),
                  ),
                  ElevatedButton.icon(
                    key: const Key('emergency_banner_center_button'),
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text(
                      'Pusatkan',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: bannerColor,
                      visualDensity: VisualDensity.compact,
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (onCenterDevice != null) {
                        onCenterDevice!(activeEvent.deviceId);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
