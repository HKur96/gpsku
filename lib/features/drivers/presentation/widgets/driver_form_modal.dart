import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/driver_model.dart';
import '../providers/drivers_provider.dart';

/// Modal bottom sheet form for creating or editing a [DriverModel].
class DriverFormModal extends StatefulWidget {
  final DriverModel? initialDriver;

  const DriverFormModal({super.key, this.initialDriver});

  /// Displays the form modal bottom sheet. Returns `true` if saved successfully.
  static Future<bool?> show(
    BuildContext context, {
    DriverModel? initialDriver,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DriverFormModal(initialDriver: initialDriver),
      ),
    );
  }

  @override
  State<DriverFormModal> createState() => _DriverFormModalState();
}

class _DriverFormModalState extends State<DriverFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _uniqueIdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDriver;
    _nameController = TextEditingController(text: init?.name ?? '');
    _uniqueIdController = TextEditingController(text: init?.uniqueId ?? '');
    _phoneController = TextEditingController(text: init?.phone ?? '');
    _licenseController = TextEditingController(text: init?.license ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uniqueIdController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<DriversProvider>();
    final isEditing = widget.initialDriver != null;

    final baseAttributes = <String, dynamic>{
      if (widget.initialDriver?.attributes != null)
        ...widget.initialDriver!.attributes,
    };

    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      baseAttributes['phone'] = phone;
    } else {
      baseAttributes.remove('phone');
    }

    final license = _licenseController.text.trim();
    if (license.isNotEmpty) {
      baseAttributes['license'] = license;
    } else {
      baseAttributes.remove('license');
      baseAttributes.remove('driverLicense');
    }

    final driverToSave =
        (widget.initialDriver ??
                const DriverModel(id: 0, name: '', uniqueId: ''))
            .copyWith(
              name: _nameController.text.trim(),
              uniqueId: _uniqueIdController.text.trim(),
              attributes: baseAttributes,
            );

    final result = isEditing
        ? await provider.updateDriver(driverToSave)
        : await provider.createDriver(driverToSave);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Data pengemudi berhasil diperbarui'
                : 'Pengemudi baru berhasil ditambahkan',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      final error = provider.errorMessage ?? 'Gagal menyimpan data pengemudi';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialDriver != null;

    return PopScope(
      canPop: !_isSaving,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(
                          0xFF1E88E5,
                        ).withValues(alpha: 0.15),
                        child: Icon(
                          isEditing
                              ? Icons.edit_outlined
                              : Icons.person_add_outlined,
                          size: 20,
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Ubah Pengemudi' : 'Tambah Pengemudi Baru',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Nama Pengemudi (Required)
                  TextFormField(
                    key: const Key('driver_form_name_field'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pengemudi *',
                      hintText: 'Contoh: Budi Santoso',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama pengemudi wajib diisi';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // RFID / iButton ID (Required)
                  TextFormField(
                    key: const Key('driver_form_unique_id_field'),
                    controller: _uniqueIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID Kartu RFID / iButton *',
                      hintText: 'Contoh: RFID-987654 atau 0000123456',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nomor kartu/RFID unik wajib diisi';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nomor Telepon (Optional)
                  TextFormField(
                    key: const Key('driver_form_phone_field'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon (Opsional)',
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nomor Lisensi / SIM (Optional)
                  TextFormField(
                    key: const Key('driver_form_license_field'),
                    controller: _licenseController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Lisensi / SIM (Opsional)',
                      hintText: 'Contoh: SIM-B2-UMUM',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons: Batal & Simpan
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('driver_form_cancel_button'),
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('driver_form_submit_button'),
                          onPressed: _isSaving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
