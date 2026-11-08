import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/geofence_model.dart';
import '../providers/geofences_provider.dart';
import 'geofence_device_assignment_dialog.dart';
import 'geofence_form_modal.dart';
import 'geofence_list_item.dart';

/// Drawer and sliding panel displaying the complete geofence catalog,
/// text search, geometry filtering, creation, and device permission linking.
class GeofenceListDrawer extends StatefulWidget {
  final void Function(GeofenceModel geofence)? onGeofenceSelected;
  final VoidCallback? onClosePressed;

  const GeofenceListDrawer({
    super.key,
    this.onGeofenceSelected,
    this.onClosePressed,
  });

  @override
  State<GeofenceListDrawer> createState() => _GeofenceListDrawerState();
}

class _GeofenceListDrawerState extends State<GeofenceListDrawer> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const List<({String key, String label, IconData icon})> _filters = [
    (key: 'all', label: 'Semua', icon: Icons.all_inclusive),
    (key: 'POLYGON', label: 'Poligon', icon: Icons.crop_square),
    (key: 'CIRCLE', label: 'Lingkaran', icon: Icons.radio_button_checked),
    (key: 'LINESTRING', label: 'Rute', icon: Icons.timeline),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GeofencesProvider>().fetchGeofences();
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<GeofencesProvider>().setSearchQuery(
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
    GeofenceModel geofence,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Geofence'),
        content: Text(
          'Apakah Anda yakin ingin menghapus geofence "${geofence.name}"? '
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
      final provider = context.read<GeofencesProvider>();
      final success = await provider.deleteGeofence(geofence.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Geofence "${geofence.name}" berhasil dihapus'
                  : provider.errorMessage ?? 'Gagal menghapus geofence',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<GeofencesProvider>();
    final geofences = provider.filteredGeofences;
    final totalCount = provider.geofences.length;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 1. Header Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              color: theme.primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.fence, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Daftar Geofence',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${geofences.length} / $totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Tutup Drawer',
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

            // 2. Search & Add Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari geofence...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    tooltip: 'Tambah Geofence',
                    onPressed: () => GeofenceFormModal.show(context),
                  ),
                ],
              ),
            ),

            // 3. Geometry Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: _filters.map((f) {
                  final isSelected = provider.selectedGeometryFilter == f.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      avatar: Icon(
                        f.icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      label: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: theme.primaryColor,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => provider.setGeometryFilter(f.key),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 12),

            // 4. Geofence Items List
            Expanded(
              child: provider.isLoading && provider.geofences.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Memuat daftar geofence...'),
                        ],
                      ),
                    )
                  : geofences.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fence_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.geofences.isEmpty
                                  ? 'Belum ada geofence'
                                  : 'Tidak ada geofence sesuai pencarian',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (provider.geofences.isEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Buat Geofence Baru'),
                                onPressed: () =>
                                    GeofenceFormModal.show(context),
                              ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchGeofences(force: true),
                      child: ListView.builder(
                        itemCount: geofences.length,
                        itemBuilder: (context, idx) {
                          final g = geofences[idx];
                          final isSelected =
                              provider.selectedGeofence?.id == g.id;

                          return GeofenceListItem(
                            geofence: g,
                            isSelected: isSelected,
                            onTap: () {
                              provider.selectGeofence(g);
                              widget.onGeofenceSelected?.call(g);
                            },
                            onEdit: () =>
                                GeofenceFormModal.show(context, geofence: g),
                            onAssignDevices: () =>
                                GeofenceDeviceAssignmentDialog.show(
                                  context,
                                  geofence: g,
                                ),
                            onDelete: () => _confirmDelete(context, g),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
