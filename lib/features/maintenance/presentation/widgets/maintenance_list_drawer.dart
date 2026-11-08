import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/maintenance_model.dart';
import '../providers/maintenance_provider.dart';
import 'maintenance_device_assignment_dialog.dart';
import 'maintenance_form_modal.dart';
import 'maintenance_list_item.dart';

/// Drawer and sliding panel displaying the complete maintenance catalog,
/// text search, alert severity filtering, creation, device permissions, and reset actions.
class MaintenanceListDrawer extends StatefulWidget {
  final void Function(MaintenanceModel maintenance)? onMaintenanceSelected;
  final VoidCallback? onClosePressed;

  const MaintenanceListDrawer({
    super.key,
    this.onMaintenanceSelected,
    this.onClosePressed,
  });

  /// Displays the maintenance drawer as a responsive bottom sheet.
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
            child: const MaintenanceListDrawer(),
          ),
        ),
      ),
    );
  }

  @override
  State<MaintenanceListDrawer> createState() => _MaintenanceListDrawerState();
}

class _MaintenanceListDrawerState extends State<MaintenanceListDrawer> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const List<({String key, String label, IconData icon})> _filters = [
    (key: 'all', label: 'Semua', icon: Icons.all_inclusive),
    (key: 'overdue', label: 'Jatuh Tempo', icon: Icons.warning_rounded),
    (key: 'warning', label: 'Mendekati', icon: Icons.schedule),
    (key: 'normal', label: 'Normal', icon: Icons.check_circle_outline),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaintenanceProvider>().fetchMaintenances();
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<MaintenanceProvider>().setSearchQuery(
          _searchController.text,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MaintenanceModel maintenance,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Jadwal Pemeliharaan'),
        content: Text(
          'Apakah Anda yakin ingin menghapus jadwal "${maintenance.name}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final provider = context.read<MaintenanceProvider>();
      final success = await provider.deleteMaintenance(maintenance.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Jadwal "${maintenance.name}" berhasil dihapus'
                  : provider.errorMessage ?? 'Gagal menghapus jadwal',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmReset(
    BuildContext context,
    MaintenanceModel maintenance,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reset Siklus Servis'),
        content: Text(
          'Perbarui nilai awal jadwal "${maintenance.name}" ke pembacaan telemetri saat ini? '
          'Siklus servis akan dimulai ulang dari 0%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Reset Servis'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final provider = context.read<MaintenanceProvider>();
      final success = await provider.resetMaintenance(maintenance);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Servis "${maintenance.name}" berhasil direset'
                  : provider.errorMessage ?? 'Gagal mereset servis',
            ),
          ),
        );
      }
    }
  }

  void _openCreateModal(BuildContext context) {
    MaintenanceFormModal.show(context);
  }

  void _openEditModal(BuildContext context, MaintenanceModel maintenance) {
    MaintenanceFormModal.show(context, initialMaintenance: maintenance);
  }

  void _openAssignmentDialog(
    BuildContext context,
    MaintenanceModel maintenance,
  ) {
    MaintenanceDeviceAssignmentDialog.show(context, maintenance: maintenance);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();

    final allMaintenances = provider.maintenances;
    final filtered = provider.filteredMaintenances;
    final selectedFilter = provider.selectedAlertFilter;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 1. Header Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.build_circle,
                    color: Color(0xFF1E88E5),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jadwal Pemeliharaan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filtered.length} dari ${allMaintenances.length} jadwal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add Maintenance Button
                  IconButton(
                    key: const Key('maintenance_drawer_add_button'),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF1E88E5),
                    ),
                    iconSize: 26,
                    tooltip: 'Tambah Jadwal',
                    onPressed: () => _openCreateModal(context),
                  ),

                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup',
                    onPressed:
                        widget.onClosePressed ??
                        () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                key: const Key('maintenance_drawer_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari jadwal servis...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = selectedFilter == filter.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      key: Key('maintenance_filter_${filter.key}'),
                      selected: isSelected,
                      avatar: Icon(
                        filter.icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      label: Text(filter.label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                      selectedColor: const Color(0xFF1E88E5),
                      checkmarkColor: Colors.white,
                      onSelected: (_) {
                        provider.setAlertFilter(filter.key);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // 4. Main List / Loading / Error
            Expanded(
              child: () {
                if (provider.isLoading && allMaintenances.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && allMaintenances.isEmpty) {
                  return Center(
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
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                provider.fetchMaintenances(force: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.build_circle_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            provider.searchQuery.isNotEmpty ||
                                    selectedFilter != 'all'
                                ? 'Tidak ada jadwal pemeliharaan yang cocok'
                                : 'Belum ada jadwal pemeliharaan',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final item = filtered[index];
                    final isSelected =
                        provider.selectedMaintenance?.id == item.id;
                    final progress = provider.getProgressForMaintenance(item);

                    return MaintenanceListItem(
                      key: Key('maintenance_item_${item.id}'),
                      maintenance: item,
                      progress: progress,
                      isSelected: isSelected,
                      onTap: () {
                        provider.selectMaintenance(item);
                        widget.onMaintenanceSelected?.call(item);
                      },
                      onEdit: () => _openEditModal(context, item),
                      onDelete: () => _confirmDelete(context, item),
                      onAssignDevices: () =>
                          _openAssignmentDialog(context, item),
                      onReset: () => _confirmReset(context, item),
                    );
                  },
                );
              }(),
            ),
          ],
        ),
      ),
    );
  }
}
