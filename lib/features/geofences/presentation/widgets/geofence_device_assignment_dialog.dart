import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/geofence_model.dart';
import '../providers/geofences_provider.dart';

/// Modal dialog for assigning or unassigning vehicles to a [geofence]
/// via the Traccar `/api/permissions` endpoint.
class GeofenceDeviceAssignmentDialog extends StatefulWidget {
  final GeofenceModel geofence;

  const GeofenceDeviceAssignmentDialog({super.key, required this.geofence});

  /// Displays the assignment dialog. Returns `true` if changes were saved.
  static Future<bool?> show(
    BuildContext context, {
    required GeofenceModel geofence,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GeofenceDeviceAssignmentDialog(geofence: geofence),
    );
  }

  @override
  State<GeofenceDeviceAssignmentDialog> createState() =>
      _GeofenceDeviceAssignmentDialogState();
}

class _GeofenceDeviceAssignmentDialogState
    extends State<GeofenceDeviceAssignmentDialog> {
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
    final geofencesProvider = context.read<GeofencesProvider>();

    _allDevices = fleetProvider.devices.values.toList();
    final deviceIds = _allDevices.map((d) => d.id).toList();

    final linked = await geofencesProvider.getLinkedDeviceIdsForGeofence(
      widget.geofence.id,
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

  void _unselectAll() {
    setState(() {
      for (final d in _filteredDevices) {
        _selectedDeviceIds.remove(d.id);
      }
    });
  }

  Future<void> _saveAssignments() async {
    setState(() => _isSaving = true);

    final provider = context.read<GeofencesProvider>();
    final success = await provider.updateDeviceAssignments(
      geofenceId: widget.geofence.id,
      selectedDeviceIds: _selectedDeviceIds.toList(),
      initialDeviceIds: _initialLinkedDeviceIds.toList(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Penautan armada untuk geofence "${widget.geofence.name}" berhasil disimpan',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Gagal menyimpan penautan armada',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selectedDeviceIds.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Color(0xFF1E88E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tautkan Kendaraan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.geofence.name,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau plat kendaraan...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Quick Action Chips & Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ActionChip(
                        label: const Text(
                          'Pilih Semua',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: _selectAll,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text(
                          'Batal Semua',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: _unselectAll,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? Colors.blue.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count dipilih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: count > 0
                            ? theme.primaryColor
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),

              // 4. Device List
              Expanded(
                child: _isLoadingInitial
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Memuat status penautan armada...'),
                          ],
                        ),
                      )
                    : _filteredDevices.isEmpty
                    ? Center(
                        child: Text(
                          _allDevices.isEmpty
                              ? 'Belum ada kendaraan di armada'
                              : 'Tidak ada kendaraan sesuai pencarian',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredDevices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final dev = _filteredDevices[idx];
                          final isChecked = _selectedDeviceIds.contains(dev.id);

                          return CheckboxListTile(
                            value: isChecked,
                            dense: true,
                            title: Text(
                              dev.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${dev.uniqueId} • Status: ${dev.status}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            activeColor: theme.primaryColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDeviceIds.add(dev.id);
                                } else {
                                  _selectedDeviceIds.remove(dev.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              const Divider(),
              const SizedBox(height: 8),

              // 5. Action Buttons
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
                    onPressed: _isSaving || _isLoadingInitial
                        ? null
                        : _saveAssignments,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
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
