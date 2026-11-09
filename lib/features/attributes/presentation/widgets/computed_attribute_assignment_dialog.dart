import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/computed_attribute_model.dart';
import '../providers/computed_attributes_provider.dart';

/// Modal dialog for assigning or unassigning vehicles to a [ComputedAttributeModel]
/// via the Traccar `/api/permissions` endpoint.
class ComputedAttributeAssignmentDialog extends StatefulWidget {
  final ComputedAttributeModel attribute;

  const ComputedAttributeAssignmentDialog({super.key, required this.attribute});

  /// Displays the assignment dialog. Returns `true` if changes were saved.
  static Future<bool?> show(
    BuildContext context, {
    required ComputedAttributeModel attribute,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ComputedAttributeAssignmentDialog(attribute: attribute),
    );
  }

  @override
  State<ComputedAttributeAssignmentDialog> createState() =>
      _ComputedAttributeAssignmentDialogState();
}

class _ComputedAttributeAssignmentDialogState
    extends State<ComputedAttributeAssignmentDialog> {
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
    LiveFleetProvider? fleetProvider;
    try {
      fleetProvider = context.read<LiveFleetProvider>();
    } on ProviderNotFoundException {
      fleetProvider = null;
    }

    final attrProvider = context.read<ComputedAttributesProvider>();

    _allDevices = fleetProvider?.devices.values.toList() ?? [];
    final deviceIds = _allDevices.map((d) => d.id).toList();

    final linked = await attrProvider.getLinkedDeviceIdsForAttribute(
      widget.attribute.id,
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
    return _allDevices.where((device) {
      final nameMatch = device.name.toLowerCase().contains(_searchQuery);
      final idMatch = device.uniqueId.toLowerCase().contains(_searchQuery);
      return nameMatch || idMatch;
    }).toList();
  }

  void _selectAll() {
    setState(() {
      _selectedDeviceIds.addAll(_filteredDevices.map((d) => d.id));
    });
  }

  void _deselectAll() {
    setState(() {
      for (final device in _filteredDevices) {
        _selectedDeviceIds.remove(device.id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final provider = context.read<ComputedAttributesProvider>();
    final success = await provider.updateDeviceAssignments(
      attributeId: widget.attribute.id,
      selectedDeviceIds: _selectedDeviceIds.toList(),
      initialDeviceIds: _initialLinkedDeviceIds.toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final err = provider.errorMessage ?? 'Gagal memperbarui relasi kendaraan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredDevices;

    return AlertDialog(
      key: Key('attribute_assignment_dialog_${widget.attribute.id}'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          const Icon(Icons.directions_car_outlined, color: Color(0xFF1E88E5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tautkan Armada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.attribute.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            // Search input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor pelat...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Select all / Deselect all action chips
            Row(
              children: [
                TextButton.icon(
                  key: const Key('select_all_devices_button'),
                  onPressed: _isLoadingInitial ? null : _selectAll,
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text(
                    'Pilih Semua',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('clear_all_devices_button'),
                  onPressed: _isLoadingInitial ? null : _deselectAll,
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text(
                    'Batal Semua',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedDeviceIds.length} dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Device list or loading indicator
            Expanded(
              child: _isLoadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        _allDevices.isEmpty
                            ? 'Tidak ada kendaraan di armada.'
                            : 'Tidak ada kendaraan yang cocok.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final device = filtered[index];
                        final isChecked = _selectedDeviceIds.contains(
                          device.id,
                        );

                        return CheckboxListTile(
                          key: Key('device_checkbox_${device.id}'),
                          value: isChecked,
                          dense: true,
                          title: Text(
                            device.name.isNotEmpty
                                ? device.name
                                : 'Device #${device.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'IMEI/ID: ${device.uniqueId}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel_device_assignment_button'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('save_device_assignment_button'),
          onPressed: (_isLoadingInitial || _isSaving) ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
