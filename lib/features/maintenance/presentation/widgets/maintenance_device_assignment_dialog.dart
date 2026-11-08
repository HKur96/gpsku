import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/maintenance_model.dart';
import '../providers/maintenance_provider.dart';

/// Modal dialog for assigning or unassigning vehicles to a [MaintenanceModel]
/// via the Traccar `/api/permissions` endpoint.
class MaintenanceDeviceAssignmentDialog extends StatefulWidget {
  final MaintenanceModel maintenance;

  const MaintenanceDeviceAssignmentDialog({
    super.key,
    required this.maintenance,
  });

  /// Displays the assignment dialog. Returns `true` if changes were saved.
  static Future<bool?> show(
    BuildContext context, {
    required MaintenanceModel maintenance,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          MaintenanceDeviceAssignmentDialog(maintenance: maintenance),
    );
  }

  @override
  State<MaintenanceDeviceAssignmentDialog> createState() =>
      _MaintenanceDeviceAssignmentDialogState();
}

class _MaintenanceDeviceAssignmentDialogState
    extends State<MaintenanceDeviceAssignmentDialog> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingInitial = true;
  bool _isSaving = false;

  List<DeviceModel> _allDevices = [];
  Set<int> _initialLinkedDeviceIds = {};
  Set<int> _selectedDeviceIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final fleetProvider = context.read<LiveFleetProvider>();
    final maintenanceProvider = context.read<MaintenanceProvider>();

    _allDevices = fleetProvider.devices.values.toList();
    final deviceIds = _allDevices.map((d) => d.id).toList();

    final linked = await maintenanceProvider.getLinkedDeviceIdsForMaintenance(
      widget.maintenance.id,
      deviceIds,
    );

    if (mounted) {
      setState(() {
        _initialLinkedDeviceIds = linked.toSet();
        _selectedDeviceIds = Set.from(_initialLinkedDeviceIds);
        _isLoadingInitial = false;
      });
    }
  }

  List<DeviceModel> get _filteredDevices {
    if (_searchQuery.isEmpty) return _allDevices;
    return _allDevices.where((d) {
      final name = d.name.toLowerCase();
      final uid = d.uniqueId.toLowerCase();
      final contact = d.contact?.toLowerCase() ?? '';
      return name.contains(_searchQuery) ||
          uid.contains(_searchQuery) ||
          contact.contains(_searchQuery);
    }).toList();
  }

  void _selectAll() {
    setState(() {
      for (final d in _filteredDevices) {
        _selectedDeviceIds.add(d.id);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (final d in _filteredDevices) {
        _selectedDeviceIds.remove(d.id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final maintenanceProvider = context.read<MaintenanceProvider>();

    final success = await maintenanceProvider.updateDeviceAssignments(
      maintenanceId: widget.maintenance.id,
      selectedDeviceIds: _selectedDeviceIds.toList(),
      initialDeviceIds: _initialLinkedDeviceIds.toList(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              maintenanceProvider.errorMessage ??
                  'Gagal memperbarui penautan armada',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDevices;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Title
              Row(
                children: [
                  const Icon(Icons.link, color: Color(0xFF1E88E5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tautkan Armada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.maintenance.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Search Bar
              TextField(
                key: const Key('maintenance_assignment_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor lambung...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Selection Summary & Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${_selectedDeviceIds.length} dari ${_allDevices.length} terpilih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _selectAll,
                        child: const Text(
                          'Pilih Semua',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _deselectAll,
                        child: const Text(
                          'Hapus Semua',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 1),

              // Device Checkbox List
              Expanded(
                child: _isLoadingInitial
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Tidak ada armada yang tersedia'
                              : 'Tidak ada armada yang cocok',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final device = filtered[index];
                          final isChecked = _selectedDeviceIds.contains(
                            device.id,
                          );

                          return CheckboxListTile(
                            key: Key('maintenance_device_tile_${device.id}'),
                            value: isChecked,
                            title: Text(
                              device.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${device.uniqueId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDeviceIds.add(device.id);
                                } else {
                                  _selectedDeviceIds.remove(device.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Actions: Cancel & Save
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('maintenance_save_assignments_button'),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
