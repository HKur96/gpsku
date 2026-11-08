import 'package:flutter/material.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';

/// Single item tile representing a vehicle in the fleet list drawer/panel.
///
/// Displays device category avatar with semantic status tint, name, uniqueId,
/// last fix timestamp, real-time speed badge, and ACC ignition status.
class FleetListItem extends StatelessWidget {
  final DeviceModel device;
  final PositionModel? position;
  final bool isSelected;
  final VoidCallback? onTap;

  const FleetListItem({
    super.key,
    required this.device,
    this.position,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final status = device.status.toLowerCase();
    final isOnline = status == 'online';
    final isMoving = isOnline && (position != null && position!.speed > 0);
    final isOffline = status == 'offline';

    // Status color token
    final Color statusColor;
    if (isMoving) {
      statusColor = const Color(0xFF10B981); // Emerald (moving)
    } else if (isOnline) {
      statusColor = const Color(0xFFF59E0B); // Amber (idle)
    } else if (isOffline) {
      statusColor = const Color(0xFFEF4444); // Red (offline)
    } else {
      statusColor = const Color(0xFF6B7280); // Neutral (unknown)
    }

    final categoryIcon = _resolveCategoryIcon(device.category);

    // Selected state colors
    final tileColor = isSelected
        ? (isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
              : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isSelected
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    // Format fix time
    final fixTimeText = _formatFixTime(position?.fixTime ?? device.lastUpdate);

    // Speed in km/h
    final speedKmh = position?.speedKmh;

    // Ignition ACC status
    final dynamic ignitionAttr = position?.attributes['ignition'];
    final bool? isIgnitionOn = ignitionAttr is bool ? ignitionAttr : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Leading Avatar with Category Icon and Status Dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(categoryIcon, color: statusColor, size: 24),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Title & Subtitle Identity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vehicle Name / Plate Number
                      Text(
                        device.name.isNotEmpty
                            ? device.name
                            : 'Unit #${device.id}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Unique ID & Model
                      Text(
                        _buildUniqueIdAndModel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Last Fix Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              fixTimeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Trailing Badges: Speed & Ignition
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isMoving
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        speedKmh != null
                            ? '${speedKmh.toStringAsFixed(1)} km/h'
                            : '- km/h',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMoving
                              ? const Color(0xFF059669)
                              : (isDark
                                    ? Colors.grey[300]
                                    : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Ignition Badge
                    if (isIgnitionOn != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isIgnitionOn
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : (isDark
                                    ? const Color(
                                        0xFF334155,
                                      ).withValues(alpha: 0.5)
                                    : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isIgnitionOn ? 'ACC ON' : 'ACC OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isIgnitionOn
                                ? const Color(0xFF059669)
                                : (isDark
                                      ? Colors.grey[400]
                                      : const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildUniqueIdAndModel() {
    final buffer = StringBuffer(device.uniqueId);
    if (device.model != null && device.model!.trim().isNotEmpty) {
      buffer.write(' • ${device.model!.trim()}');
    }
    return buffer.toString();
  }

  static IconData _resolveCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'car':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      case 'ship':
      case 'boat':
        return Icons.directions_boat;
      case 'van':
        return Icons.airport_shuttle;
      case 'pickup':
        return Icons.agriculture;
      default:
        return Icons.navigation;
    }
  }

  static String _formatFixTime(DateTime? time) {
    if (time == null) return 'Belum ada data fix';
    final local = time.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }
}
