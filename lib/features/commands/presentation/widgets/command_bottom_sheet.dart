import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/errors/failures.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../data/models/command_payload_model.dart';
import '../../data/models/command_type_model.dart';
import '../../domain/repositories/commands_repository.dart';
import 'slide_to_confirm_widget.dart';

/// Modal bottom sheet presenting available telematics commands, dynamic parameter inputs,
/// speed safety interlocks, and slide-to-confirm protection for high-risk actions.
class CommandBottomSheet extends StatefulWidget {
  final DeviceModel device;
  final PositionModel? position;
  final CommandsRepository? commandsRepository;

  const CommandBottomSheet({
    super.key,
    required this.device,
    this.position,
    this.commandsRepository,
  });

  /// Displays the [CommandBottomSheet] modally.
  static Future<CommandPayloadModel?> show(
    BuildContext context, {
    required DeviceModel device,
    PositionModel? position,
    CommandsRepository? commandsRepository,
  }) {
    return showModalBottomSheet<CommandPayloadModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommandBottomSheet(
        device: device,
        position: position,
        commandsRepository: commandsRepository,
      ),
    );
  }

  @override
  State<CommandBottomSheet> createState() => _CommandBottomSheetState();
}

class _CommandBottomSheetState extends State<CommandBottomSheet> {
  bool _isLoadingTypes = true;
  String? _typesError;
  List<CommandTypeModel> _supportedCommands = [];

  String? _selectedCommandType;
  bool _riskAcknowledged = false;
  bool _isExecuting = false;
  String? _executionError;

  final TextEditingController _customDataController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchSupportedCommands();
  }

  @override
  void dispose() {
    _customDataController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  CommandsRepository _resolveRepository() {
    if (widget.commandsRepository != null) {
      return widget.commandsRepository!;
    }
    return context.read<CommandsRepository>();
  }

  Future<void> _fetchSupportedCommands() async {
    setState(() {
      _isLoadingTypes = true;
      _typesError = null;
    });

    final repo = _resolveRepository();
    final result = await repo.getSupportedCommands(deviceId: widget.device.id);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoadingTypes = false;
          _typesError = failure.message;
        });
      },
      (commands) {
        setState(() {
          _isLoadingTypes = false;
          _supportedCommands = commands;
          if (commands.isNotEmpty) {
            // Prefer engineStop or first command
            final hasEngineStop = commands.any(
              (c) => c.type == CommandTypeModel.typeEngineStop,
            );
            _selectedCommandType = hasEngineStop
                ? CommandTypeModel.typeEngineStop
                : commands.first.type;
          }
        });
      },
    );
  }

  Future<void> _executeCommand() async {
    if (_selectedCommandType == null) return;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isExecuting = true;
      _executionError = null;
    });

    final attributes = <String, dynamic>{};
    if (_selectedCommandType == CommandTypeModel.typeCustom) {
      attributes['data'] = _customDataController.text.trim();
    } else if (_selectedCommandType == CommandTypeModel.typePositionPeriodic) {
      final freq = int.tryParse(_frequencyController.text.trim()) ?? 60;
      attributes['frequency'] = freq;
    }

    final payload = CommandPayloadModel(
      deviceId: widget.device.id,
      type: _selectedCommandType!,
      attributes: attributes,
    );

    final repo = _resolveRepository();
    final result = await repo.sendCommand(payload);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isExecuting = false;
          _executionError = _getFriendlyErrorMessage(failure);
        });
      },
      (executedPayload) {
        setState(() {
          _isExecuting = false;
        });

        Navigator.of(context).pop(executedPayload);

        // Feedback notification
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          if (executedPayload.isQueued) {
            messenger.showSnackBar(
              const SnackBar(
                key: Key('command_queued_snackbar'),
                backgroundColor: Color(0xFFD97706), // Amber 600
                content: Text(
                  'Perintah disimpan di antrean server (perangkat offline)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            messenger.showSnackBar(
              const SnackBar(
                key: Key('command_success_snackbar'),
                backgroundColor: Color(0xFF16A34A), // Green 600
                content: Text(
                  'Perintah berhasil dikirim ke perangkat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }

  String _getFriendlyErrorMessage(Failure failure) {
    if (failure is AuthFailure) {
      return 'Sesi otentikasi telah berakhir. Silakan login kembali.';
    } else if (failure is ForbiddenFailure) {
      return 'Akses ditolak: Anda tidak memiliki izin untuk mengirim perintah ke perangkat ini.';
    } else if (failure is TimeoutFailure) {
      return 'Koneksi ke server timeout. Silakan coba beberapa saat lagi.';
    }
    return failure.message.isNotEmpty
        ? failure.message
        : 'Gagal mengirim perintah ke server.';
  }

  String _formatCommandLabel(String type) {
    switch (type) {
      case CommandTypeModel.typeEngineStop:
        return 'Matikan Mesin (Cut-Off)';
      case CommandTypeModel.typeEngineResume:
        return 'Aktifkan Mesin (Resume)';
      case CommandTypeModel.typeCustom:
        return 'Perintah Kustom (Protokol)';
      case CommandTypeModel.typePositionSingle:
        return 'Cek Posisi Seketika (Single)';
      case CommandTypeModel.typePositionPeriodic:
        return 'Set Periode Pelaporan';
      case CommandTypeModel.typeAlarmArm:
        return 'Aktifkan Mode Alarm (Arm)';
      case CommandTypeModel.typeAlarmDisarm:
        return 'Nonaktifkan Alarm (Disarm)';
      case CommandTypeModel.typeRebootDevice:
        return 'Restart Perangkat Tracker';
      case CommandTypeModel.typePowerOff:
        return 'Matikan Daya Tracker (Power Off)';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final speedKmh = widget.position?.speedKmh ?? 0.0;
    final isEngineStop =
        _selectedCommandType == CommandTypeModel.typeEngineStop;
    final isHighSpeed = speedKmh > 20.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Device Info & Close Button
              _buildHeader(context),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Body Content
              if (_isLoadingTypes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: CircularProgressIndicator(
                      key: Key('command_sheet_loading'),
                    ),
                  ),
                )
              else if (_typesError != null)
                _buildErrorState()
              else if (_supportedCommands.isEmpty)
                _buildEmptyState()
              else
                _buildCommandForm(isDark, isEngineStop, isHighSpeed, speedKmh),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOnline = widget.device.status.toLowerCase() == 'online';

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0066FF).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.send_rounded,
            color: Color(0xFF0066FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.device.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isOnline
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey[600]!)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? const Color(0xFF16A34A)
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.device.uniqueId +
                    (widget.device.model != null
                        ? ' • ${widget.device.model}'
                        : ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('command_sheet_close_button'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Tutup',
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
        const SizedBox(height: 8),
        Text(
          _typesError ?? 'Gagal memuat perintah perangkat',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          key: const Key('command_sheet_retry_button'),
          onPressed: _fetchSupportedCommands,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Coba Lagi'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'Tidak ada tipe perintah yang didukung untuk perangkat ini.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCommandForm(
    bool isDark,
    bool isEngineStop,
    bool isHighSpeed,
    double speedKmh,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Command Selector Dropdown
          const Text(
            'Tipe Perintah Remote',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: const Key('command_type_dropdown'),
            initialValue: _selectedCommandType,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: _supportedCommands.map((c) {
              return DropdownMenuItem<String>(
                value: c.type,
                child: Text(
                  _formatCommandLabel(c.type),
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCommandType = value;
                _riskAcknowledged = false;
                _executionError = null;
              });
            },
          ),

          const SizedBox(height: 14),

          // Dynamic Parameter Inputs
          if (_selectedCommandType == CommandTypeModel.typeCustom) ...[
            const Text(
              'Payload Data Protokol (ASCII / Hex)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('custom_command_input'),
              controller: _customDataController,
              decoration: InputDecoration(
                hintText: 'Contoh: STATUS# atau RELAY,1#',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Payload perintah kustom tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ] else if (_selectedCommandType ==
              CommandTypeModel.typePositionPeriodic) ...[
            const Text(
              'Interval Pelaporan (Detik)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('frequency_command_input'),
              controller: _frequencyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Contoh: 30',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // engineStop Warning Card
          if (isEngineStop) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Peringatan: Mematikan mesin akan memutus aliran bahan bakar atau pengapian kendaraan seketika.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Speed Safety Interlock (speed > 20 km/h)
            if (isHighSpeed) ...[
              Container(
                key: const Key('speed_interlock_warning'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kendaraan Melaju: ${speedKmh.toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bahaya keselamatan tinggi: Mematikan mesin saat melaju dapat menyebabkan sistem pengereman dan kemudi kehilangan tenaga, meningkatkan risiko kecelakaan fatal!',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          key: const Key('speed_interlock_checkbox'),
                          value: _riskAcknowledged,
                          activeColor: const Color(0xFFDC2626),
                          onChanged: (val) {
                            setState(() {
                              _riskAcknowledged = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Saya memahami risiko mematikan mesin saat kendaraan melaju.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],

          // Error Feedback Banner
          if (_executionError != null) ...[
            Container(
              key: const Key('command_error_banner'),
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 20,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _executionError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Execution Trigger (Slide-To-Confirm vs Standard Button)
          if (isEngineStop)
            SlideToConfirmWidget(
              key: const Key('command_slide_to_confirm'),
              label: 'Geser untuk Matikan Mesin',
              confirmedLabel: 'Memproses Perintah...',
              activeColor: const Color(0xFFDC2626),
              enabled: !_isExecuting && (!isHighSpeed || _riskAcknowledged),
              isLoading: _isExecuting,
              onConfirmed: _executeCommand,
            )
          else
            ElevatedButton.icon(
              key: const Key('command_send_button'),
              onPressed: _isExecuting ? null : _executeCommand,
              icon: _isExecuting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isExecuting ? 'Mengirim...' : 'Kirim Perintah',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
