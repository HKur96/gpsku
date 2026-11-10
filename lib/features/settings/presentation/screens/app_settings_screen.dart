import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../emulator/presentation/providers/telemetry_emulator_provider.dart';
import '../../../emulator/presentation/widgets/telemetry_emulator_sheet.dart';
import '../../../notifications/presentation/screens/notification_settings_screen.dart';

/// Action requested from [AppSettingsScreen] when returning to the live fleet map shell.
enum SettingsLaunchAction { openEmulatorSheet, activateMapPick }

/// Canonical Application Settings Hub (`/settings`) reusing existing notification
/// settings and enforcing strict authorization for Developer Options (`F-39`).
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  String _describeTransportSummary(AppConfig? config) {
    if (config == null) {
      return 'Endpoint dinamis berdasarkan konfigurasi koneksi aktif';
    }
    if (config.isHttps) {
      return 'HTTPS Proxy: POST ${config.getOsmandProxyUri()} → OsmAnd';
    }
    return 'HTTP Lokal: ${config.getOsmandUri()} (fallback :${config.getOsmandProxyUri().port})';
  }

  void _openNotificationSettings(BuildContext context) {
    try {
      context.push('/notification-settings');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationSettingsScreen(),
        ),
      );
    }
  }

  Future<void> _handleOpenEmulator(BuildContext context) async {
    AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }

    TelemetryEmulatorProvider? emulator;
    try {
      emulator = context.read<TelemetryEmulatorProvider>();
    } on ProviderNotFoundException {
      emulator = null;
    }

    final isAllowed =
        (auth?.canAccessDeveloperTools ?? false) &&
        (emulator?.isDeveloperAuthorized ?? false);
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses ditolak: Mode Pengembang hanya untuk Administrator non-readonly.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(SettingsLaunchAction.openEmulatorSheet);
      return;
    }

    await TelemetryEmulatorSheet.show(context);
  }

  void _handleActivateMapPick(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }

    TelemetryEmulatorProvider? emulator;
    try {
      emulator = context.read<TelemetryEmulatorProvider>();
    } on ProviderNotFoundException {
      emulator = null;
    }

    final isAllowed =
        (auth?.canAccessDeveloperTools ?? false) &&
        (emulator?.isDeveloperAuthorized ?? false);
    if (!isAllowed || emulator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses ditolak: Mode Pengembang hanya untuk Administrator non-readonly.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final activated = emulator.setMapPickMode(true);
    if (!activated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emulator.lastErrorMessage ?? 'Gagal mengaktifkan Mode Pilih Peta.',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(SettingsLaunchAction.activateMapPick);
      return;
    }

    try {
      context.go('/');
    } catch (_) {
      // Isolated test harness without GoRouter
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }

    AppConfig? appConfig;
    try {
      appConfig = context.watch<AppConfig>();
    } on ProviderNotFoundException {
      appConfig = null;
    }

    TelemetryEmulatorProvider? emulator;
    try {
      emulator = context.watch<TelemetryEmulatorProvider>();
    } on ProviderNotFoundException {
      emulator = null;
    }

    final user = auth?.currentUser;
    final isDeveloperAllowed = auth?.canAccessDeveloperTools ?? false;

    String roleLabel = 'Pengguna';
    Color roleColor = const Color(0xFF475569);
    if (user != null) {
      if (user.readonly) {
        roleLabel = 'Read-Only';
        roleColor = const Color(0xFFD97706);
      } else if (user.administrator) {
        roleLabel = 'Administrator';
        roleColor = const Color(0xFF1E88E5);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan'), elevation: 0.5),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (user != null) ...[
            Card(
              elevation: 1,
              child: ListTile(
                key: const Key('settings_account_summary_tile'),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1E88E5),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  user.name.isNotEmpty ? user.name : 'User #${user.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(user.email),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Umum',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: ListTile(
              key: const Key('settings_notifications_tile'),
              leading: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1E88E5),
              ),
              title: const Text('Pengaturan Notifikasi'),
              subtitle: const Text(
                'Aturan alert, saluran pengiriman, dan uji notifikasi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNotificationSettings(context),
            ),
          ),

          if (isDeveloperAllowed) ...[
            const SizedBox(height: 24),
            Text(
              'Mode Pengembang',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFD97706),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              key: const Key('settings_developer_section'),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                ),
              ),
              child: ExpansionTile(
                key: const Key('settings_developer_expansion_tile'),
                initiallyExpanded: true,
                leading: const Icon(
                  Icons.developer_mode_outlined,
                  color: Color(0xFFD97706),
                ),
                title: const Text(
                  'Mode Pengembang (Developer Options)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  _describeTransportSummary(appConfig),
                  style: const TextStyle(fontSize: 11),
                ),
                children: [
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings_open_emulator_button'),
                    enabled: emulator != null,
                    leading: const Icon(
                      Icons.sensors_outlined,
                      color: Color(0xFF1E88E5),
                    ),
                    title: const Text('Simulator Telemetri GPS (OsmAnd)'),
                    subtitle: const Text(
                      'Buka panel injeksi telemetri & simulasi rute',
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: emulator != null
                        ? () => _handleOpenEmulator(context)
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings_activate_map_pick_button'),
                    enabled: emulator != null,
                    leading: const Icon(
                      Icons.add_location_alt_outlined,
                      color: Color(0xFF16A34A),
                    ),
                    title: const Text('Mode Pilih Koordinat di Peta'),
                    subtitle: const Text(
                      'Ketuk titik di peta utama untuk menyuntikkan koordinat',
                    ),
                    trailing: const Icon(Icons.map_outlined, size: 18),
                    onTap: emulator != null
                        ? () => _handleActivateMapPick(context)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
