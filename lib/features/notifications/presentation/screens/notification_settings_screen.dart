import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_settings_provider.dart';
import '../widgets/notification_rule_form_modal.dart';

/// Screen for managing Traccar notification rules, multi-channel delivery matrix,
/// and live channel test dispatches.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSettingsProvider>().fetchSettings();
    });
  }

  void _openAddModal() {
    NotificationRuleFormModal.show(context);
  }

  void _openEditModal(NotificationModel notification) {
    NotificationRuleFormModal.show(context, notification: notification);
  }

  Future<void> _confirmDelete(NotificationModel notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Aturan Notifikasi'),
        content: Text(
          'Apakah Anda yakin ingin menghapus aturan notifikasi untuk kejadian "${NotificationSettingsProvider.formatEventType(notification.type)}"?',
        ),
        actions: [
          TextButton(
            key: const Key('notification_delete_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('notification_delete_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<NotificationSettingsProvider>();
      final success = await provider.deleteNotification(notification.id);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aturan notifikasi berhasil dihapus.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Gagal menghapus aturan notifikasi.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChannelTestSheet() {
    final provider = context.read<NotificationSettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ChangeNotifierProvider<NotificationSettingsProvider>.value(
            value: provider,
            child: const _ChannelTestSheet(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<NotificationSettingsProvider>();
    final notifications = settingsProvider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Notifikasi'),
        elevation: 0.5,
        actions: [
          IconButton(
            key: const Key('notification_settings_test_channels_action'),
            icon: const Icon(Icons.network_check),
            tooltip: 'Uji Coba Saluran',
            onPressed: _openChannelTestSheet,
          ),
          IconButton(
            key: const Key('notification_settings_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: () => settingsProvider.fetchSettings(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('notification_settings_add_fab'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Aturan'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        onPressed: _openAddModal,
      ),
      body: _buildBody(settingsProvider, notifications),
    );
  }

  Widget _buildBody(
    NotificationSettingsProvider provider,
    List<NotificationModel> notifications,
  ) {
    if (provider.isLoading && notifications.isEmpty) {
      return const Center(
        key: Key('notification_settings_loading_indicator'),
        child: CircularProgressIndicator(),
      );
    }

    if (provider.errorMessage != null && notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Pengaturan Notifikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('notification_settings_retry_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                onPressed: () => provider.fetchSettings(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        key: const Key('notification_settings_empty_state'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Aturan Notifikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Buat aturan untuk menerima alarm, status mesin, atau batas kecepatan pada kanal Web, Push, atau Email.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('notification_settings_create_first_button'),
                icon: const Icon(Icons.add),
                label: const Text('Buat Aturan Pertama'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _openAddModal,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchSettings(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return _NotificationRuleCard(
            key: Key('notification_rule_card_${item.id}'),
            notification: item,
            onEdit: () => _openEditModal(item),
            onDelete: () => _confirmDelete(item),
          );
        },
      ),
    );
  }
}

/// Visual card for a single notification rule.
class _NotificationRuleCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NotificationRuleCard({
    super.key,
    required this.notification,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final eventName = NotificationSettingsProvider.formatEventType(
      notification.type,
    );
    final eventColor = _getEventColor(notification.type);
    final eventIcon = _getEventIcon(notification.type);
    final channels = notification.notificatorList;
    final alarms = notification.attributes['alarms'] as String?;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Type Title + Popup Menu
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: eventColor.withValues(alpha: 0.15),
                  child: Icon(eventIcon, color: eventColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (notification.description != null &&
                          notification.description!.isNotEmpty)
                        Text(
                          notification.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('notification_rule_menu_${notification.id}'),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Ubah'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Badges row: "Semua Armada" + Specific Alarms
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (notification.always)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          size: 13,
                          color: Colors.indigo.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Semua Armada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (alarms != null && alarms.isNotEmpty)
                  ...alarms
                      .split(',')
                      .map(
                        (a) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            a.trim().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Channel Badges Row
            Row(
              children: [
                Text(
                  'Saluran:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: channels.map((channel) {
                      final label =
                          NotificationSettingsProvider.formatChannelName(
                            channel,
                          );
                      return Chip(
                        avatar: Icon(
                          _getChannelIcon(channel),
                          size: 14,
                          color: Colors.blue.shade900,
                        ),
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide(color: Colors.blue.shade100),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'alarm':
        return Colors.red.shade700;
      case 'overspeed':
        return Colors.orange.shade800;
      case 'deviceOnline':
        return Colors.green.shade700;
      case 'deviceOffline':
        return Colors.grey.shade700;
      case 'deviceMoving':
        return Colors.teal.shade700;
      case 'deviceStopped':
        return Colors.amber.shade900;
      case 'geofenceEnter':
      case 'geofenceExit':
      case 'geofenceCrossed':
        return Colors.blue.shade700;
      case 'ignitionOn':
      case 'ignitionOff':
        return Colors.deepPurple.shade700;
      case 'maintenance':
        return Colors.deepOrange.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'alarm':
        return Icons.warning_amber_rounded;
      case 'overspeed':
        return Icons.speed;
      case 'deviceOnline':
        return Icons.power;
      case 'deviceOffline':
        return Icons.power_off;
      case 'deviceMoving':
        return Icons.directions_car;
      case 'deviceStopped':
        return Icons.stop_circle_outlined;
      case 'geofenceEnter':
      case 'geofenceExit':
      case 'geofenceCrossed':
        return Icons.fence;
      case 'ignitionOn':
      case 'ignitionOff':
        return Icons.key;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.notifications;
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'web':
        return Icons.language;
      case 'firebase':
        return Icons.notifications_active;
      case 'mail':
        return Icons.email_outlined;
      case 'sms':
        return Icons.sms_outlined;
      case 'telegram':
        return Icons.send;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.podcasts;
    }
  }
}

/// Modal bottom sheet for testing channel connectivity individually.
class _ChannelTestSheet extends StatelessWidget {
  const _ChannelTestSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationSettingsProvider>();
    final notificators = provider.notificators.isNotEmpty
        ? provider.notificators
        : NotificationSettingsProvider.defaultNotificators;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uji Coba Kanal Notifikasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    key: const Key('channel_test_close_button'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Text(
                'Kirim pesan uji coba langsung ke server Traccar untuk memastikan saluran aktif sebelum digunakan.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notificators.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final notif = notificators[index];
                    final isTesting = provider.testingNotificator == notif.type;
                    final label =
                        notif.name ??
                        NotificationSettingsProvider.formatChannelName(
                          notif.type,
                        );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          _getChannelIcon(notif.type),
                          color: Colors.blue.shade800,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Tipe backend: ${notif.type}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: OutlinedButton(
                        key: Key('test_channel_button_${notif.type}'),
                        onPressed: isTesting
                            ? null
                            : () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                final success = await provider.testNotificator(
                                  notif.type,
                                );
                                if (!context.mounted) return;
                                scaffoldMessenger.clearSnackBars();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Pesan uji coba berhasil terkirim ke $label.'
                                          : 'Gagal mengirim pesan uji coba ke $label: ${provider.errorMessage}',
                                    ),
                                    backgroundColor: success
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                );
                              },
                        child: isTesting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Kirim Tes',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'web':
        return Icons.language;
      case 'firebase':
        return Icons.notifications_active;
      case 'mail':
        return Icons.email_outlined;
      case 'sms':
        return Icons.sms_outlined;
      case 'telegram':
        return Icons.send;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.podcasts;
    }
  }
}
