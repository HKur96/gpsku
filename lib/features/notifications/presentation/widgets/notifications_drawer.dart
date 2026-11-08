import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/notifications_provider.dart';
import '../screens/notification_settings_screen.dart';
import 'notification_list_item.dart';

/// Slide-over drawer presenting telematics event history, category filter chips,
/// unread count badge, and bulk actions ("Tandai Semua Dibaca", "Hapus Riwayat").
class NotificationsDrawer extends StatelessWidget {
  final void Function(int deviceId)? onSelectDevice;

  const NotificationsDrawer({super.key, this.onSelectDevice});

  static void show(
    BuildContext context, {
    void Function(int deviceId)? onSelectDevice,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: NotificationsDrawer(onSelectDevice: onSelectDevice),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationsProvider>();
    final unread = notifProvider.unreadCount;
    final filtered = notifProvider.filteredEvents;

    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF1E88E5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${notifProvider.events.length} Event • $unread Belum Dibaca',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('notifications_drawer_settings_button'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Pengaturan Notifikasi',
                onPressed: () {
                  Navigator.of(context).pop();
                  try {
                    context.push('/notification-settings');
                  } catch (_) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                key: const Key('notifications_drawer_close_button'),
                icon: const Icon(Icons.close),
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Action Buttons Row (Tandai Semua Dibaca & Bersihkan)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TextButton.icon(
                key: const Key('notifications_mark_all_read_button'),
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text(
                  'Tandai Sudah Dibaca',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: unread > 0
                    ? () => notifProvider.markAllAsRead()
                    : null,
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('notifications_clear_all_button'),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.red,
                ),
                label: const Text(
                  'Hapus Riwayat',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: notifProvider.events.isNotEmpty
                    ? () => notifProvider.clearAll()
                    : null,
              ),
            ],
          ),
        ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: 'Semua',
                filter: EventCategoryFilter.all,
                isSelected:
                    notifProvider.selectedFilter == EventCategoryFilter.all,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Alarm / Darurat',
                filter: EventCategoryFilter.alarm,
                isSelected:
                    notifProvider.selectedFilter == EventCategoryFilter.alarm,
                accentColor: Colors.red,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Status Unit',
                filter: EventCategoryFilter.deviceStatus,
                isSelected:
                    notifProvider.selectedFilter ==
                    EventCategoryFilter.deviceStatus,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Geofence',
                filter: EventCategoryFilter.geofence,
                isSelected:
                    notifProvider.selectedFilter ==
                    EventCategoryFilter.geofence,
              ),
            ],
          ),
        ),

        const Divider(height: 12),

        // Event List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada notifikasi saat ini',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('notifications_list_view'),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final event = filtered[index];
                    final isRead = !notifProvider.events.any(
                      (e) => e.id == event.id && notifProvider.unreadCount > 0,
                    );
                    return NotificationListItem(
                      event: event,
                      isRead: isRead,
                      onSelectDevice: (deviceId) {
                        Navigator.of(context).pop();
                        if (onSelectDevice != null) {
                          onSelectDevice!(deviceId);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required EventCategoryFilter filter,
    required bool isSelected,
    Color? accentColor,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? (accentColor != null ? Colors.white : Colors.white)
              : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: accentColor ?? const Color(0xFF1E88E5),
      onSelected: (_) {
        context.read<NotificationsProvider>().setFilter(filter);
      },
      visualDensity: VisualDensity.compact,
    );
  }
}
