import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/domain/helpers/active_driver_resolver.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/maintenance/domain/helpers/maintenance_progress_helper.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:gpsku/features/share/presentation/widgets/share_link_bottom_sheet.dart';
import 'package:gpsku/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';

/// Interactive telemetry bottom sheet displaying essential device and position metrics.
///
/// Follows GPSku design system specifications (SCR-MAP-02 StatusCard) and updates
/// reactively when WebSocket telemetry arrives.
class VehicleDetailSheet extends StatelessWidget {
  /// Standard estimated height in pixels used for camera southward offset calculation.
  static const double estimatedSheetHeight = 250.0;

  final DeviceModel device;
  final PositionModel? position;
  final VoidCallback? onDismiss;
  final VoidCallback? onCenterToVehicle;
  final VoidCallback? onCommandsPressed;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onEmulatorPressed;

  const VehicleDetailSheet({
    super.key,
    required this.device,
    this.position,
    this.onDismiss,
    this.onCenterToVehicle,
    this.onCommandsPressed,
    this.onHistoryPressed,
    this.onSharePressed,
    this.onEmulatorPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Icon, Identity, Status Badge, Close Button
              _buildHeader(context),

              const SizedBox(height: 12),

              // Quick Action Bar: Center, Commands, History
              _buildActionRow(context),

              const SizedBox(height: 12),

              // Driver Information Section
              _buildDriverSection(context),

              const SizedBox(height: 12),

              // Telemetry Section: Metrics Grid or No-Fix Banner
              () {
                final pos = position;
                if (pos != null && _hasValidCoordinates(pos)) {
                  return _buildMetricsGrid(context, pos);
                }
                return _buildNoFixBanner(context);
              }(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final status = device.status.toLowerCase();
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'online':
        statusColor = const Color(0xFF2E7D32); // Green
        statusLabel = 'Online';
        break;
      case 'offline':
        statusColor = const Color(0xFFC62828); // Red
        statusLabel = 'Offline';
        break;
      default:
        statusColor = const Color(0xFF757575); // Grey
        statusLabel = 'Unknown';
        break;
    }

    final categoryIcon = _resolveCategoryIcon(device.category);

    MaintenanceProvider? maintenanceProvider;
    try {
      maintenanceProvider = Provider.of<MaintenanceProvider>(context);
    } catch (_) {
      maintenanceProvider = null;
    }

    final maintenanceAlert = maintenanceProvider?.evaluateDeviceAlertLevel(
      device.id,
      position,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Category Icon Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(categoryIcon, color: statusColor, size: 24),
        ),

        const SizedBox(width: 12),

        // Title and Unique ID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      device.name.isNotEmpty
                          ? device.name
                          : 'Device #${device.id}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (maintenanceAlert != null &&
                  maintenanceAlert != MaintenanceAlertLevel.normal) ...[
                const SizedBox(height: 4),
                _buildMaintenanceDueBadge(maintenanceAlert),
              ],
              const SizedBox(height: 2),
              Text(
                device.uniqueId +
                    (device.model != null ? ' • ${device.model}' : ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Telemetry Emulator Launch Button (Feature F-39)
        IconButton(
          key: const Key('vehicle_sheet_emulator_button'),
          icon: const Icon(Icons.sensors_outlined),
          iconSize: 20,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          tooltip: 'Simulasi Telemetri',
          onPressed:
              onEmulatorPressed ??
              () => TelemetryEmulatorSheet.show(context, initialDevice: device),
        ),

        // Dismiss / Close Button
        IconButton(
          key: const Key('vehicle_sheet_dismiss_button'),
          icon: const Icon(Icons.close),
          iconSize: 20,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          tooltip: 'Tutup',
          onPressed: onDismiss,
        ),
      ],
    );
  }

  Widget _buildMaintenanceDueBadge(MaintenanceAlertLevel level) {
    final isOverdue = level == MaintenanceAlertLevel.overdue;
    final color = isOverdue
        ? const Color(0xFFC62828) // Red
        : const Color(0xFFE65100); // Amber
    final label = isOverdue ? 'Servis Jatuh Tempo' : 'Jadwal Servis Mendekati';

    return Container(
      key: const Key('vehicle_sheet_maintenance_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        // Center to Vehicle Button
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('vehicle_sheet_center_button'),
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('Pusatkan', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onCenterToVehicle,
          ),
        ),
        const SizedBox(width: 8),

        // Commands Button (Placeholder / Disabled per P7.3.4 scope)
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('vehicle_sheet_commands_button'),
            icon: const Icon(Icons.send_outlined, size: 16),
            label: const Text('Perintah', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onCommandsPressed,
          ),
        ),
        const SizedBox(width: 8),

        // History Button (Placeholder / Disabled per P7.3.4 scope)
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('vehicle_sheet_history_button'),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Riwayat', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onHistoryPressed,
          ),
        ),
        const SizedBox(width: 8),

        // Share Button (Public Share Link via F-37)
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('vehicle_sheet_share_button'),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Bagikan', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed:
                onSharePressed ??
                () => ShareLinkBottomSheet.show(context, device: device),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    DriversProvider? driversProvider;
    try {
      driversProvider = Provider.of<DriversProvider>(context);
    } catch (_) {
      driversProvider = null;
    }

    final rawRfid = ActiveDriverResolver.extractDriverUniqueId(position);

    DriverModel? activeDriver;
    if (driversProvider != null) {
      activeDriver = driversProvider.resolveActiveDriver(position);
      if (activeDriver == null && rawRfid == null) {
        final deviceDrivers = driversProvider.getDriversForDevice(device.id);
        if (deviceDrivers.isNotEmpty) {
          activeDriver = deviceDrivers.first;
        }
      }
    }

    return Container(
      key: const Key('vehicle_sheet_driver_card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: activeDriver != null
                ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
                : (isDark ? Colors.grey[800] : Colors.grey[200]),
            child: Icon(
              Icons.badge_outlined,
              size: 18,
              color: activeDriver != null
                  ? const Color(0xFF1E88E5)
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'PENGEMUDI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (activeDriver != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: const Key('vehicle_sheet_driver_rfid'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E88E5,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activeDriver.uniqueId,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ] else if (rawRfid != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: const Key('vehicle_sheet_driver_rfid'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rawRfid,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  activeDriver != null
                      ? activeDriver.name
                      : (rawRfid != null
                            ? 'Kartu: $rawRfid'
                            : 'Tanpa Pengemudi'),
                  key: const Key('vehicle_sheet_driver_name'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: activeDriver != null || rawRfid != null
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activeDriver?.phone != null &&
                    activeDriver!.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 11,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activeDriver.phone!,
                        key: const Key('vehicle_sheet_driver_phone'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, PositionModel pos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Speed (km/h)
    final speedText = '${pos.speedKmh.toStringAsFixed(1)} km/h';

    // 2. Ignition
    final dynamic ignitionVal = pos.attributes['ignition'];
    final bool? isIgnitionOn = ignitionVal is bool ? ignitionVal : null;
    final String ignitionText = isIgnitionOn == true
        ? 'ON'
        : (isIgnitionOn == false ? 'OFF' : '-');
    final Color ignitionColor = isIgnitionOn == true
        ? const Color(0xFF2E7D32)
        : (isIgnitionOn == false ? Colors.grey : Colors.grey);

    // 3. Heading / Course
    final courseText =
        '${pos.course.toStringAsFixed(0)}° (${compassDirection(pos.course)})';

    // 4. Battery / Power
    final dynamic batteryVal =
        pos.attributes['batteryLevel'] ??
        pos.attributes['battery'] ??
        device.attributes['batteryLevel'];
    final String batteryText = batteryVal != null ? '$batteryVal%' : '-';

    // 5. Address / Coordinates
    final locationText = pos.address != null && pos.address!.isNotEmpty
        ? pos.address!
        : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

    // 6. Fix Time
    final timeText = formatFixTime(pos.fixTime);

    return Column(
      children: [
        // 4-Card Grid
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.speed,
                iconColor: const Color(0xFF1976D2),
                label: 'Kecepatan',
                value: speedText,
                key: const Key('metric_speed'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Icons.vpn_key_outlined,
                iconColor: ignitionColor,
                label: 'Kontak (ACC)',
                value: ignitionText,
                key: const Key('metric_ignition'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.explore_outlined,
                iconColor: const Color(0xFF00897B),
                label: 'Arah Kompas',
                value: courseText,
                key: const Key('metric_heading'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: Icons.battery_charging_full,
                iconColor: const Color(0xFFF57C00),
                label: 'Baterai',
                value: batteryText,
                key: const Key('metric_battery'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Location & Timestamp footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      key: const Key('metric_location'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Sinyal terakhir: $timeText',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    key: const Key('metric_fix_time'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoFixBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.gps_off, color: Color(0xFFD97706), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menunggu Sinyal GPS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kendaraan belum mengirimkan koordinat posisi yang valid.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasValidCoordinates(PositionModel pos) {
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return false;
    if (pos.latitude.isNaN || pos.latitude.isInfinite) return false;
    if (pos.longitude.isNaN || pos.longitude.isInfinite) return false;
    if (pos.latitude < -90.0 || pos.latitude > 90.0) return false;
    if (pos.longitude < -180.0 || pos.longitude > 180.0) return false;
    return true;
  }

  static IconData _resolveCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      default:
        return Icons.navigation;
    }
  }

  /// Calculates Indonesian 8-point compass cardinal direction.
  static String compassDirection(double course) {
    final normalized = (course % 360.0 + 360.0) % 360.0;
    if (normalized >= 337.5 || normalized < 22.5) return 'U'; // Utara
    if (normalized >= 22.5 && normalized < 67.5) return 'TL'; // Timur Laut
    if (normalized >= 67.5 && normalized < 112.5) return 'T'; // Timur
    if (normalized >= 112.5 && normalized < 157.5) return 'TG'; // Tenggara
    if (normalized >= 157.5 && normalized < 202.5) return 'S'; // Selatan
    if (normalized >= 202.5 && normalized < 247.5) return 'BD'; // Barat Daya
    if (normalized >= 247.5 && normalized < 292.5) return 'B'; // Barat
    return 'BL'; // Barat Laut
  }

  /// Formats UTC [DateTime] to localized readable string: `DD/MM/YYYY HH:MM:SS`.
  static String formatFixTime(DateTime time) {
    final local = time.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min:$sec';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
