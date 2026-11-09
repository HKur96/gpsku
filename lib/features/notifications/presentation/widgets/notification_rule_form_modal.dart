import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_settings_provider.dart';

/// Modal bottom sheet form for creating or editing Traccar notification rules.
class NotificationRuleFormModal extends StatefulWidget {
  final NotificationModel? initialNotification;

  const NotificationRuleFormModal({super.key, this.initialNotification});

  /// Displays the modal sheet.
  static Future<bool?> show(
    BuildContext context, {
    NotificationModel? notification,
  }) {
    final provider = context.read<NotificationSettingsProvider>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ChangeNotifierProvider<NotificationSettingsProvider>.value(
            value: provider,
            child: NotificationRuleFormModal(initialNotification: notification),
          ),
    );
  }

  @override
  State<NotificationRuleFormModal> createState() =>
      _NotificationRuleFormModalState();
}

class _NotificationRuleFormModalState extends State<NotificationRuleFormModal> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedType;
  late bool _always;
  late TextEditingController _descriptionController;
  final Set<String> _selectedNotificators = {};
  final Set<String> _selectedAlarms = {};
  String? _validationError;

  bool get isEditMode => widget.initialNotification != null;

  static const List<String> standardAlarms = [
    'sos',
    'overspeed',
    'tamper',
    'powerCut',
    'vibration',
    'accident',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialNotification;

    _selectedType = init?.type ?? 'alarm';
    _always = init?.always ?? false;
    _descriptionController = TextEditingController(
      text: init?.description ?? '',
    );

    if (init != null) {
      _selectedNotificators.addAll(init.notificatorList);
      final alarmsStr = init.attributes['alarms'] as String?;
      if (alarmsStr != null && alarmsStr.isNotEmpty) {
        _selectedAlarms.addAll(
          alarmsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }
    } else {
      // Default initial channels
      _selectedNotificators.addAll(['web', 'firebase']);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _testSelectedChannels(
    NotificationSettingsProvider provider,
  ) async {
    if (_selectedNotificators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu kanal untuk diuji.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final channelsToTest = _selectedNotificators.toList();
    int successCount = 0;

    for (final channel in channelsToTest) {
      final success = await provider.testNotificator(channel);
      if (success) successCount++;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    if (successCount == channelsToTest.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uji coba berhasil terkirim ke $successCount kanal terpilih.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uji coba: $successCount dari ${channelsToTest.length} kanal berhasil dikirim.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _submit(NotificationSettingsProvider provider) async {
    setState(() => _validationError = null);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedNotificators.isEmpty) {
      setState(() {
        _validationError = 'Wajib memilih minimal satu kanal pengiriman.';
      });
      return;
    }

    final notificatorsString = _selectedNotificators.join(',');
    final attributes = <String, dynamic>{
      if (widget.initialNotification != null)
        ...widget.initialNotification!.attributes,
    };

    if (_selectedType == 'alarm' && _selectedAlarms.isNotEmpty) {
      attributes['alarms'] = _selectedAlarms.join(',');
    } else {
      attributes.remove('alarms');
    }

    final desc = _descriptionController.text.trim();

    final model = NotificationModel(
      id: widget.initialNotification?.id ?? 0,
      type: _selectedType,
      description: desc.isNotEmpty ? desc : null,
      always: _always,
      notificators: notificatorsString,
      calendarId: widget.initialNotification?.calendarId ?? 0,
      commandId: widget.initialNotification?.commandId ?? 0,
      attributes: attributes,
    );

    final bool success;
    if (isEditMode) {
      success = await provider.updateNotification(model);
    } else {
      success = await provider.createNotification(model);
    }

    if (!mounted) return;

    if (success) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Aturan notifikasi berhasil diperbarui.'
                : 'Aturan notifikasi baru berhasil disimpan.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Gagal menyimpan aturan notifikasi.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<NotificationSettingsProvider>();
    final types = settingsProvider.types.isNotEmpty
        ? settingsProvider.types
        : NotificationSettingsProvider.defaultTypes;
    final notificators = settingsProvider.notificators.isNotEmpty
        ? settingsProvider.notificators
        : NotificationSettingsProvider.defaultNotificators;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditMode
                            ? 'Ubah Aturan Notifikasi'
                            : 'Tambah Aturan Notifikasi',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        key: const Key('notification_form_close_button'),
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Event Type Dropdown
                  const Text(
                    'Tipe Kejadian (Event)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const Key('notification_form_type_dropdown'),
                    initialValue: types.any((t) => t.type == _selectedType)
                        ? _selectedType
                        : types.first.type,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: types.map((t) {
                      final label =
                          t.name ??
                          NotificationSettingsProvider.formatEventType(t.type);
                      return DropdownMenuItem<String>(
                        value: t.type,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Alarms Filter Multi-Select (if type == 'alarm')
                  if (_selectedType == 'alarm') ...[
                    const Text(
                      'Pilihan Jenis Alarm',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: standardAlarms.map((alarm) {
                        final isSelected = _selectedAlarms.contains(alarm);
                        return FilterChip(
                          key: Key('alarm_chip_$alarm'),
                          label: Text(
                            alarm.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAlarms.add(alarm);
                              } else {
                                _selectedAlarms.remove(alarm);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Delivery Channels Checkboxes
                  const Text(
                    'Kanal Pengiriman Notifikasi',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: notificators.map((notificator) {
                      final isChecked = _selectedNotificators.contains(
                        notificator.type,
                      );
                      final label =
                          notificator.name ??
                          NotificationSettingsProvider.formatChannelName(
                            notificator.type,
                          );
                      return FilterChip(
                        key: Key('channel_chip_${notificator.type}'),
                        avatar: Icon(
                          _getChannelIcon(notificator.type),
                          size: 16,
                          color: isChecked ? Colors.blue.shade900 : Colors.grey,
                        ),
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isChecked,
                        selectedColor: Colors.blue.shade100,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedNotificators.add(notificator.type);
                            } else {
                              _selectedNotificators.remove(notificator.type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _validationError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Test Selected Channels Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('notification_form_test_channels_button'),
                      icon: settingsProvider.testingNotificator != null
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 14),
                      label: Text(
                        settingsProvider.testingNotificator != null
                            ? 'Menguji ${settingsProvider.testingNotificator}...'
                            : 'Uji Kanal Terpilih',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: settingsProvider.testingNotificator != null
                          ? null
                          : () => _testSelectedChannels(settingsProvider),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // "Always" Switch
                  SwitchListTile.adaptive(
                    key: const Key('notification_form_always_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kirim ke Semua Armada (Always)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Jika aktif, notifikasi berlaku untuk seluruh armada tanpa perlu ditautkan satu per satu.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: _always,
                    onChanged: (val) => setState(() => _always = val),
                  ),
                  const SizedBox(height: 6),

                  // Description TextField
                  TextFormField(
                    key: const Key('notification_form_description_input'),
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan Tambahan (Opsional)',
                      hintText: 'Misal: Notifikasi darurat manajer armada',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Submit Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('notification_form_cancel_button'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const Key('notification_form_save_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: settingsProvider.isSaving
                            ? null
                            : () => _submit(settingsProvider),
                        child: settingsProvider.isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isEditMode ? 'Perbarui' : 'Simpan'),
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

  IconData _getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'web':
        return Icons.language;
      case 'firebase':
        return Icons.notifications_active;
      case 'mail':
        return Icons.email_outlined;
      case 'sms':
        return Icons.sms_outlined;
      case 'telegram':
        return Icons.send;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.podcasts;
    }
  }
}
