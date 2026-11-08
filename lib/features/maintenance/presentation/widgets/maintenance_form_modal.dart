import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/maintenance_model.dart';
import '../providers/maintenance_provider.dart';

/// Modal bottom sheet form for creating or updating a vehicle [MaintenanceModel].
///
/// Automatically handles user input in familiar units (km, hours, days) and
/// converts them to Traccar backend primitives (meters, milliseconds).
class MaintenanceFormModal extends StatefulWidget {
  final MaintenanceModel? initialMaintenance;
  final double? currentTelemetryValue;

  const MaintenanceFormModal({
    super.key,
    this.initialMaintenance,
    this.currentTelemetryValue,
  });

  /// Displays the form modal. Returns `true` if saved successfully.
  static Future<bool?> show(
    BuildContext context, {
    MaintenanceModel? initialMaintenance,
    double? currentTelemetryValue,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MaintenanceFormModal(
          initialMaintenance: initialMaintenance,
          currentTelemetryValue: currentTelemetryValue,
        ),
      ),
    );
  }

  @override
  State<MaintenanceFormModal> createState() => _MaintenanceFormModalState();
}

class _MaintenanceFormModalState extends State<MaintenanceFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _periodController;

  late String _selectedType;
  bool _isSaving = false;

  static const List<({String key, String label, String unit})> _typeOptions = [
    (key: 'totalDistance', label: 'Jarak Tempuh (km)', unit: 'km'),
    (key: 'hours', label: 'Jam Mesin (jam)', unit: 'jam'),
    (key: 'serverTime', label: 'Waktu Kalender (hari)', unit: 'hari'),
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialMaintenance;

    _nameController = TextEditingController(text: init?.name ?? '');

    if (init != null) {
      if (init.isDistanceBased) {
        _selectedType = 'totalDistance';
        _startController = TextEditingController(
          text: _formatCleanNumber(init.startKm),
        );
        _periodController = TextEditingController(
          text: _formatCleanNumber(init.periodKm),
        );
      } else if (init.isHoursBased) {
        _selectedType = 'hours';
        _startController = TextEditingController(
          text: _formatCleanNumber(init.startHours),
        );
        _periodController = TextEditingController(
          text: _formatCleanNumber(init.periodHours),
        );
      } else {
        _selectedType = 'serverTime';
        _startController = TextEditingController(
          text: _formatCleanNumber(init.startDays),
        );
        _periodController = TextEditingController(
          text: _formatCleanNumber(init.periodDays),
        );
      }
    } else {
      _selectedType = 'totalDistance';
      _startController = TextEditingController(
        text: widget.currentTelemetryValue != null
            ? _formatCleanNumber(widget.currentTelemetryValue!)
            : '0',
      );
      _periodController = TextEditingController(text: '5000');
    }
  }

  String _formatCleanNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  String get _currentUnit {
    switch (_selectedType) {
      case 'totalDistance':
        return 'km';
      case 'hours':
        return 'jam';
      case 'serverTime':
      default:
        return 'hari';
    }
  }

  void _onTypeChanged(String? newType) {
    if (newType == null || newType == _selectedType) return;
    setState(() {
      _selectedType = newType;
      // Provide reasonable defaults when switching types in create mode
      if (widget.initialMaintenance == null) {
        if (newType == 'totalDistance') {
          _periodController.text = '5000';
        } else if (newType == 'hours') {
          _periodController.text = '250';
        } else {
          _periodController.text = '90';
        }
      }
    });
  }

  void _useCurrentValue() {
    if (widget.currentTelemetryValue != null) {
      _startController.text = _formatCleanNumber(widget.currentTelemetryValue!);
    } else {
      _startController.text = '0';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final startInput = double.parse(_startController.text.trim());
    final periodInput = double.parse(_periodController.text.trim());

    double backendStart;
    double backendPeriod;

    if (_selectedType == 'totalDistance') {
      backendStart = startInput * 1000.0;
      backendPeriod = periodInput * 1000.0;
    } else if (_selectedType == 'hours') {
      backendStart = startInput * 3600000.0;
      backendPeriod = periodInput * 3600000.0;
    } else {
      backendStart = startInput * 86400000.0;
      backendPeriod = periodInput * 86400000.0;
    }

    final provider = context.read<MaintenanceProvider>();
    final isEdit = widget.initialMaintenance != null;

    final model = MaintenanceModel(
      id: widget.initialMaintenance?.id ?? 0,
      name: _nameController.text.trim(),
      type: _selectedType,
      start: backendStart,
      period: backendPeriod,
      attributes: widget.initialMaintenance?.attributes ?? const {},
    );

    final success = isEdit
        ? await provider.updateMaintenance(model)
        : await provider.createMaintenance(model);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Gagal menyimpan jadwal pemeliharaan',
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
    final isEdit = widget.initialMaintenance != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 550),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEdit
                              ? 'Ubah Jadwal Pemeliharaan'
                              : 'Tambah Jadwal Pemeliharaan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 1. Name Field
                  TextFormField(
                    key: const Key('maintenance_form_name_field'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Jadwal *',
                      hintText: 'Contoh: Ganti Oli Mesin, Servis Berkala',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama jadwal tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. Type Dropdown
                  DropdownButtonFormField<String>(
                    key: const Key('maintenance_form_type_dropdown'),
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Tipe Metrik Pemeliharaan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.tune),
                    ),
                    items: _typeOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.key,
                        child: Text(opt.label),
                      );
                    }).toList(),
                    onChanged: isEdit ? null : _onTypeChanged,
                  ),

                  const SizedBox(height: 16),

                  // 3. Start Value Field
                  TextFormField(
                    key: const Key('maintenance_form_start_field'),
                    controller: _startController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Nilai Awal / Servis Terakhir ($_currentUnit) *',
                      hintText: 'Nilai pembacaan awal servis',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.flag_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        tooltip: 'Reset / Gunakan Nilai Saat Ini',
                        onPressed: _useCurrentValue,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nilai awal wajib diisi';
                      }
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal < 0) {
                        return 'Nilai awal harus angka >= 0';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // 4. Period Value Field
                  TextFormField(
                    key: const Key('maintenance_form_period_field'),
                    controller: _periodController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Interval Servis ($_currentUnit) *',
                      hintText: 'Ulangi setiap X $_currentUnit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.update),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Interval servis wajib diisi';
                      }
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) {
                        return 'Interval servis harus angka > 0';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // 5. Submit Button
                  FilledButton.icon(
                    key: const Key('maintenance_form_submit_button'),
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(isEdit ? Icons.save : Icons.add_task),
                    label: Text(
                      _isSaving
                          ? 'Menyimpan...'
                          : (isEdit ? 'Simpan Perubahan' : 'Tambah Jadwal'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
