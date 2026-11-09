import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../../data/models/computed_attribute_model.dart';
import '../../data/models/computed_attribute_test_result_model.dart';
import '../providers/computed_attributes_provider.dart';

/// Modal bottom sheet form for creating, editing, and live testing
/// a [ComputedAttributeModel] expression against fleet telematics.
class ComputedAttributeFormModal extends StatefulWidget {
  final ComputedAttributeModel? initialAttribute;
  final int? initialDeviceId;

  const ComputedAttributeFormModal({
    super.key,
    this.initialAttribute,
    this.initialDeviceId,
  });

  /// Displays the form modal bottom sheet. Returns `true` if saved successfully.
  static Future<bool?> show(
    BuildContext context, {
    ComputedAttributeModel? initialAttribute,
    int? initialDeviceId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ComputedAttributeFormModal(
          initialAttribute: initialAttribute,
          initialDeviceId: initialDeviceId,
        ),
      ),
    );
  }

  @override
  State<ComputedAttributeFormModal> createState() =>
      _ComputedAttributeFormModalState();
}

class _ComputedAttributeFormModalState
    extends State<ComputedAttributeFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _attributeController;
  late final TextEditingController _expressionController;
  final FocusNode _expressionFocusNode = FocusNode();

  late String _selectedType;
  int? _testDeviceId;
  bool _isSaving = false;

  // Pre-configured JEXL Syntax Helper Chips
  static const List<String> _variableChips = [
    'adc1',
    'speed',
    'ignition',
    'power',
    'battery',
    'course',
    'valid',
    'totalDistance',
  ];

  static const List<String> _operatorChips = [
    ' ?  : ',
    ' > ',
    ' < ',
    ' >= ',
    ' <= ',
    ' == ',
    ' != ',
    ' && ',
    ' || ',
    ' !',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialAttribute;
    _descriptionController = TextEditingController(
      text: init?.description ?? '',
    );
    _attributeController = TextEditingController(text: init?.attribute ?? '');
    _expressionController = TextEditingController(text: init?.expression ?? '');

    _selectedType =
        (init != null &&
            ComputedAttributeModel.supportedTypes.contains(
              init.type.toLowerCase(),
            ))
        ? init.type.toLowerCase()
        : 'number';

    _testDeviceId = widget.initialDeviceId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _attributeController.dispose();
    _expressionController.dispose();
    _expressionFocusNode.dispose();
    super.dispose();
  }

  void _insertSnippet(String snippet) {
    final text = _expressionController.text;
    final selection = _expressionController.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, snippet);
    _expressionController.text = newText;
    _expressionController.selection = TextSelection.collapsed(
      offset: start + snippet.length,
    );
    _expressionFocusNode.requestFocus();
  }

  Future<void> _runTestExpression() async {
    final expression = _expressionController.text.trim();
    if (expression.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan ekspresi JEXL terlebih dahulu')),
      );
      return;
    }

    if (_testDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan sampel untuk pengujian')),
      );
      return;
    }

    final provider = context.read<ComputedAttributesProvider>();
    final tempModel = ComputedAttributeModel(
      id: widget.initialAttribute?.id ?? 0,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : 'Test Attribute',
      attribute: _attributeController.text.trim().isNotEmpty
          ? _attributeController.text.trim()
          : 'testAttr',
      expression: expression,
      type: _selectedType,
      priority: widget.initialAttribute?.priority ?? 0,
    );

    await provider.testExpression(
      deviceId: _testDeviceId!,
      attribute: tempModel,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<ComputedAttributesProvider>();
    final isEditing = widget.initialAttribute != null;

    final attribute = ComputedAttributeModel(
      id: widget.initialAttribute?.id ?? 0,
      description: _descriptionController.text.trim(),
      attribute: _attributeController.text.trim(),
      expression: _expressionController.text.trim(),
      type: _selectedType,
      priority: widget.initialAttribute?.priority ?? 0,
      attributes: widget.initialAttribute?.attributes ?? const {},
    );

    bool success = false;
    if (isEditing) {
      final res = await provider.updateAttribute(attribute);
      success = res != null;
    } else {
      final res = await provider.createAttribute(attribute);
      success = res != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final err = provider.errorMessage ?? 'Gagal menyimpan atribut terhitung';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialAttribute != null;
    final attrProvider = context.watch<ComputedAttributesProvider>();

    LiveFleetProvider? liveFleet;
    try {
      liveFleet = context.watch<LiveFleetProvider>();
    } on ProviderNotFoundException {
      liveFleet = null;
    }

    final devices = liveFleet?.devices.values.toList() ?? <DeviceModel>[];
    if (_testDeviceId == null && devices.isNotEmpty) {
      _testDeviceId = devices.first.id;
    }

    final testResult = attrProvider.testResult;
    final isTesting = attrProvider.isTesting;

    return FractionallySizedBox(
      heightFactor: 0.90,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              isEditing ? 'Ubah Atribut Terhitung' : 'Tambah Atribut Terhitung',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: FilledButton(
                  key: const Key('computed_attribute_save_button'),
                  onPressed: _isSaving ? null : _submit,
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
                      : Text(isEditing ? 'Simpan' : 'Tambah'),
                ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Description field
                TextFormField(
                  key: const Key('attribute_description_field'),
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi / Label *',
                    hintText: 'mis. Baterai Rendah, Level Bahan Bakar',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Deskripsi wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Attribute target key & Output type row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target property name
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: const Key('attribute_target_key_field'),
                        controller: _attributeController,
                        decoration: InputDecoration(
                          labelText: 'Nama Atribut Target *',
                          hintText: 'mis. batteryLow, fuelStatus',
                          prefixIcon: const Icon(Icons.key_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama atribut wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Type selector
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: const Key('attribute_type_dropdown'),
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Tipe Data *',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'number',
                            child: Text('Number'),
                          ),
                          DropdownMenuItem(
                            value: 'string',
                            child: Text('String'),
                          ),
                          DropdownMenuItem(
                            value: 'boolean',
                            child: Text('Boolean'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Expression text field
                TextFormField(
                  key: const Key('attribute_expression_field'),
                  controller: _expressionController,
                  focusNode: _expressionFocusNode,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Ekspresi JEXL *',
                    hintText: 'mis. battery < 3.5 ? true : false',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(Icons.functions),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ekspresi JEXL wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Helper chips label
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Color(0xFF1E88E5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bantuan Sintaks (Ketuk untuk menyisipkan):',
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
                const SizedBox(height: 8),

                // Variable helper chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _variableChips.map((v) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ActionChip(
                          key: Key('syntax_chip_$v'),
                          label: Text(
                            v,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE0F2FE),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFBAE6FD),
                          ),
                          onPressed: () => _insertSnippet(v),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),

                // Operator helper chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _operatorChips.map((op) {
                      final label = op.trim();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ActionChip(
                          key: Key('syntax_chip_${label.replaceAll(' ', '_')}'),
                          label: Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                          onPressed: () => _insertSnippet(op),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Test Runner Section
                Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            color: Color(0xFF1E88E5),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Uji Formula JEXL Langsung',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Evaluasi formula di atas terhadap telemetri terakhir kendaraan:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Device selection and Test button
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: const Key('attribute_test_device_dropdown'),
                              initialValue: _testDeviceId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Pilih Kendaraan',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: devices.map((d) {
                                return DropdownMenuItem<int>(
                                  value: d.id,
                                  child: Text(
                                    d.name.isNotEmpty
                                        ? d.name
                                        : 'Device #${d.id}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _testDeviceId = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            key: const Key('attribute_test_formula_button'),
                            onPressed: (isTesting || devices.isEmpty)
                                ? null
                                : _runTestExpression,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            icon: isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Uji Formula'),
                          ),
                        ],
                      ),

                      // Test Result Display Card
                      if (testResult != null) ...[
                        const SizedBox(height: 14),
                        _buildTestResultCard(context, testResult, isDark),
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

  Widget _buildTestResultCard(
    BuildContext context,
    ComputedAttributeTestResultModel result,
    bool isDark,
  ) {
    if (!result.success || result.error != null) {
      // JEXL Evaluation Failure
      return Container(
        key: const Key('test_result_failure_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                SizedBox(width: 8),
                Text(
                  'Galat Evaluasi Formula',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.error ??
                  'Terjadi kesalahan sintaks JEXL atau variabel tidak ditemukan.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
      );
    }

    if (result.value == null) {
      // 204 No Content / Null Position
      return Container(
        key: const Key('test_result_no_content_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tidak ada data telemetri (204 No Content) pada perangkat ini untuk dihitung.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Success evaluation
    return Container(
      key: const Key('test_result_success_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Evaluasi Berhasil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.resultType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Nilai Hasil: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: Text(
                  '${result.value}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
