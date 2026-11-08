import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/event_model.dart';
import '../providers/notifications_provider.dart';

/// Single item representing a telematics event inside [NotificationsDrawer].
class NotificationListItem extends StatelessWidget {
  final EventModel event;
  final bool isRead;
  final void Function(int deviceId)? onSelectDevice;

  const NotificationListItem({
    super.key,
    required this.event,
    required this.isRead,
    this.onSelectDevice,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve vehicle label
    String deviceLabel = 'Unit #${event.deviceId}';
    try {
      final fleet = context.watch<LiveFleetProvider>();
      final device = fleet.devices[event.deviceId];
      if (device != null && device.name.isNotEmpty) {
        deviceLabel = device.name;
      }
    } catch (_) {}

    final visualConfig = _getEventVisualConfig(event);
    final timeStr = event.eventTime != null
        ? DateFormat('HH:mm:ss • dd/MM').format(event.eventTime!.toLocal())
        : '-';

    return InkWell(
      key: Key('notification_item_${event.id}'),
      onTap: () {
        context.read<NotificationsProvider>().markAsRead(event.id);
        if (onSelectDevice != null && event.deviceId > 0) {
          onSelectDevice!(event.deviceId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRead
              ? Colors.transparent
              : Colors.blue.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: visualConfig.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                visualConfig.icon,
                color: visualConfig.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          visualConfig.title,
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E88E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (event.message != null && event.message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.message!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _VisualConfig _getEventVisualConfig(EventModel event) {
    if (event.isSos) {
      return const _VisualConfig(
        title: 'Peringatan Darurat SOS',
        icon: Icons.emergency,
        color: Color(0xFFDC2626),
      );
    }
    if (event.isAlarm) {
      final alarm = event.alarmType?.toLowerCase();
      if (alarm == 'overspeed') {
        return const _VisualConfig(
          title: 'Alarm Batas Kecepatan',
          icon: Icons.speed,
          color: Colors.orange,
        );
      } else if (alarm == 'tamper') {
        return const _VisualConfig(
          title: 'Alarm Sabotase / Tamper',
          icon: Icons.security,
          color: Colors.red,
        );
      }
      return _VisualConfig(
        title: 'Alarm: ${event.alarmType ?? 'Telematika'}',
        icon: Icons.warning_amber_rounded,
        color: Colors.red.shade600,
      );
    }

    switch (event.type) {
      case EventModel.typeDeviceMoving:
        return const _VisualConfig(
          title: 'Kendaraan Bergerak',
          icon: Icons.navigation_outlined,
          color: Colors.green,
        );
      case EventModel.typeDeviceStopped:
        return const _VisualConfig(
          title: 'Kendaraan Berhenti',
          icon: Icons.pause_circle_outline,
          color: Colors.amber,
        );
      case EventModel.typeDeviceOnline:
        return const _VisualConfig(
          title: 'Perangkat Online',
          icon: Icons.wifi,
          color: Colors.teal,
        );
      case EventModel.typeDeviceOffline:
        return const _VisualConfig(
          title: 'Perangkat Offline',
          icon: Icons.wifi_off,
          color: Colors.grey,
        );
      case EventModel.typeGeofenceEnter:
        return const _VisualConfig(
          title: 'Masuk Geofence',
          icon: Icons.fence,
          color: Colors.blue,
        );
      case EventModel.typeGeofenceExit:
        return const _VisualConfig(
          title: 'Keluar Geofence',
          icon: Icons.fence_outlined,
          color: Colors.indigo,
        );
      case EventModel.typeMaintenance:
        return const _VisualConfig(
          title: 'Jadwal Servis Pemeliharaan',
          icon: Icons.build_circle_outlined,
          color: Colors.deepOrange,
        );
      case EventModel.typeCommandResult:
        return const _VisualConfig(
          title: 'Respon Perintah',
          icon: Icons.terminal,
          color: Colors.purple,
        );
      default:
        return _VisualConfig(
          title: event.type.isNotEmpty ? event.type : 'Event Telematika',
          icon: Icons.notifications_none,
          color: Colors.blueGrey,
        );
    }
  }
}

class _VisualConfig {
  final String title;
  final IconData icon;
  final Color color;

  const _VisualConfig({
    required this.title,
    required this.icon,
    required this.color,
  });
}
