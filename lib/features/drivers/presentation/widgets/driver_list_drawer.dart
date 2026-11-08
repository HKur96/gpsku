import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/driver_model.dart';
import '../providers/drivers_provider.dart';
import 'driver_device_assignment_dialog.dart';
import 'driver_form_modal.dart';
import 'driver_list_item.dart';

/// Drawer and sliding panel displaying the complete driver catalog,
/// debounced text search, creation, device permissions, and delete actions.
class DriverListDrawer extends StatefulWidget {
  final void Function(DriverModel driver)? onDriverSelected;
  final VoidCallback? onClosePressed;

  const DriverListDrawer({
    super.key,
    this.onDriverSelected,
    this.onClosePressed,
  });

  /// Displays the driver drawer as a responsive bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            child: const DriverListDrawer(),
          ),
        ),
      ),
    );
  }

  @override
  State<DriverListDrawer> createState() => _DriverListDrawerState();
}

class _DriverListDrawerState extends State<DriverListDrawer> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriversProvider>().fetchDrivers();
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<DriversProvider>().setSearchQuery(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, DriverModel driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Pengemudi'),
        content: Text(
          'Apakah Anda yakin ingin menghapus supir "${driver.name}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            key: const Key('driver_delete_cancel_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('driver_delete_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await context.read<DriversProvider>().deleteDriver(
        driver.id,
      );
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengemudi "${driver.name}" berhasil dihapus'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<DriversProvider>();

    final drivers = provider.filteredDrivers;
    final totalCount = provider.drivers.length;

    return SafeArea(
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Title, Count Badge, Add Button, Close Button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF1E88E5),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daftar Pengemudi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: const Key('driver_drawer_count_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount Supir',
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),

                // Add button (+)
                IconButton(
                  key: const Key('driver_drawer_add_button'),
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF1E88E5),
                  tooltip: 'Tambah Pengemudi',
                  onPressed: () {
                    DriverFormModal.show(context);
                  },
                ),

                // Close Button
                IconButton(
                  key: const Key('driver_drawer_close_button'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () {
                    if (widget.onClosePressed != null) {
                      widget.onClosePressed!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: TextField(
              key: const Key('driver_drawer_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari supir, RFID, telepon, SIM...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('driver_drawer_search_clear_button'),
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<DriversProvider>().setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Content: Loading, Error, Empty, or List
          Expanded(
            child: Builder(
              builder: (ctx) {
                if (provider.isLoading && provider.drivers.isEmpty) {
                  return const Center(
                    key: Key('driver_drawer_loading'),
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.errorMessage != null && provider.drivers.isEmpty) {
                  return Center(
                    key: const Key('driver_drawer_error'),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('driver_drawer_retry_button'),
                            onPressed: () => provider.fetchDrivers(force: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (drivers.isEmpty) {
                  return Center(
                    key: const Key('driver_drawer_empty'),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Tidak ada supir yang cocok dengan pencarian'
                                : 'Belum ada supir terdaftar',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_searchController.text.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => DriverFormModal.show(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah Supir Pertama'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: drivers.length,
                  padding: const EdgeInsets.only(bottom: 24.0),
                  itemBuilder: (ctx, index) {
                    final driver = drivers[index];
                    final isSelected = provider.selectedDriver?.id == driver.id;

                    return DriverListItem(
                      driver: driver,
                      isSelected: isSelected,
                      onTap: () {
                        provider.selectDriver(driver);
                        widget.onDriverSelected?.call(driver);
                      },
                      onEdit: () {
                        DriverFormModal.show(context, initialDriver: driver);
                      },
                      onAssignDevices: () {
                        DriverDeviceAssignmentDialog.show(
                          context,
                          driver: driver,
                        );
                      },
                      onDelete: () {
                        _confirmDelete(context, driver);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
