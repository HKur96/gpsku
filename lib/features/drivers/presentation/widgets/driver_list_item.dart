import 'package:flutter/material.dart';
import '../../data/models/driver_model.dart';

/// Single visual item card in [DriverListDrawer] displaying driver profile,
/// RFID/iButton identifier badge, contact details, and context actions.
class DriverListItem extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssignDevices;
  final bool isSelected;

  const DriverListItem({
    super.key,
    required this.driver,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAssignDevices,
    this.isSelected = false,
  });

  String _getInitialLetter() {
    final trimmed = driver.name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initial = _getInitialLetter();
    final phone = driver.phone;
    final license = driver.license;

    return Container(
      key: Key('driver_list_item_${driver.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1E88E5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Driver initial letter
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(
                    0xFF1E88E5,
                  ).withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Driver details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Driver Name & Actions
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driver.name.isNotEmpty
                                  ? driver.name
                                  : 'Driver #${driver.id}',
                              key: Key('driver_item_name_${driver.id}'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Popup menu actions
                          PopupMenuButton<String>(
                            key: Key('driver_item_menu_button_${driver.id}'),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit?.call();
                                  break;
                                case 'assign':
                                  onAssignDevices?.call();
                                  break;
                                case 'delete':
                                  onDelete?.call();
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF1E88E5),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Ubah'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'assign',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      size: 18,
                                      color: Color(0xFF00897B),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Tautkan Armada'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Color(0xFFE53935),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Hapus',
                                      style: TextStyle(
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // RFID / iButton badge
                      Container(
                        key: Key('driver_item_rfid_${driver.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: Color(0xFF1E88E5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              driver.uniqueId.isNotEmpty
                                  ? driver.uniqueId
                                  : 'Tanpa ID Kartu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Optional Phone and License tags
                      if ((phone != null && phone.trim().isNotEmpty) ||
                          (license != null && license.trim().isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (phone != null && phone.trim().isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    key: Key('driver_item_phone_${driver.id}'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            if (license != null && license.trim().isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.credit_card_outlined,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    license,
                                    key: Key(
                                      'driver_item_license_${driver.id}',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
