import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/driver_model.dart';
import '../providers/drivers_provider.dart';

/// Modal dialog for assigning or unassigning vehicles to a [DriverModel]
/// via the Traccar `/api/permissions` endpoint.
class DriverDeviceAssignmentDialog extends StatefulWidget {
  final DriverModel driver;

  const DriverDeviceAssignmentDialog({super.key, required this.driver});

  /// Displays the assignment dialog. Returns `true` if changes were saved.
  static Future<bool?> show(
    BuildContext context, {
    required DriverModel driver,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DriverDeviceAssignmentDialog(driver: driver),
    );
  }

  @override
  State<DriverDeviceAssignmentDialog> createState() =>
      _DriverDeviceAssignmentDialogState();
}

class _DriverDeviceAssignmentDialogState
    extends State<DriverDeviceAssignmentDialog> {
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
    final driversProvider = context.read<DriversProvider>();

    _allDevices = fleetProvider.devices.values.toList();
    final deviceIds = _allDevices.map((d) => d.id).toList();

    final linked = await driversProvider.getLinkedDeviceIdsForDriver(
      widget.driver.id,
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

    final driversProvider = context.read<DriversProvider>();
    final success = await driversProvider.updateDeviceAssignments(
      driverId: widget.driver.id,
      selectedDeviceIds: _selectedDeviceIds.toList(),
      initialDeviceIds: _initialLinkedDeviceIds.toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penautan armada berhasil diperbarui'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      final err =
          driversProvider.errorMessage ?? 'Gagal memperbarui penautan armada';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFC62828)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 24.0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title & Close Button
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF1E88E5),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tautkan Armada',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.driver.name.isNotEmpty
                                ? widget.driver.name
                                : 'Driver #${widget.driver.id}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Search Filter
                TextField(
                  key: const Key('driver_assignment_search_field'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kendaraan atau nomor polisi...',
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
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 10),

                // Select All / Deselect All Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${_selectedDeviceIds.length} kendaraan dipilih',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          key: const Key('driver_assignment_select_all_button'),
                          onPressed: _selectAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Pilih Semua',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          key: const Key(
                            'driver_assignment_deselect_all_button',
                          ),
                          onPressed: _deselectAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
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

                // Device List / Loading / Empty
                Expanded(
                  child: _isLoadingInitial
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredDevices.isEmpty
                      ? Center(
                          child: Text(
                            _allDevices.isEmpty
                                ? 'Tidak ada kendaraan terdaftar'
                                : 'Tidak ada kendaraan yang cocok',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredDevices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            final device = _filteredDevices[index];
                            final isChecked = _selectedDeviceIds.contains(
                              device.id,
                            );

                            return CheckboxListTile(
                              key: Key(
                                'driver_assignment_device_checkbox_${device.id}',
                              ),
                              value: isChecked,
                              onChanged: _isSaving
                                  ? null
                                  : (bool? val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedDeviceIds.add(device.id);
                                        } else {
                                          _selectedDeviceIds.remove(device.id);
                                        }
                                      });
                                    },
                              title: Text(
                                device.name.isNotEmpty
                                    ? device.name
                                    : 'Device #${device.id}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${device.uniqueId}${device.model != null ? ' • ${device.model}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            );
                          },
                        ),
                ),

                const SizedBox(height: 14),

                // Action Buttons: Batal & Simpan
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('driver_assignment_cancel_button'),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('driver_assignment_save_button'),
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
