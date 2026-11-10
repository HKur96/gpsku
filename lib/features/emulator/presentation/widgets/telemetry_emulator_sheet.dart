import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../../../fleet/presentation/providers/live_fleet_provider.dart';
import '../providers/telemetry_emulator_provider.dart';

/// Interactive modal bottom sheet providing real-time telemetry injection,
/// manual coordinate controls, sliders, and path simulation engine controls.
class TelemetryEmulatorSheet extends StatefulWidget {
  final DeviceModel? initialDevice;

  const TelemetryEmulatorSheet({super.key, this.initialDevice});

  /// Displays the [TelemetryEmulatorSheet] as a responsive modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    DeviceModel? initialDevice,
  }) async {
    final provider = Provider.of<TelemetryEmulatorProvider>(
      context,
      listen: false,
    );

    if (initialDevice != null) {
      LiveFleetProvider? liveFleet;
      try {
        liveFleet = Provider.of<LiveFleetProvider>(context, listen: false);
      } catch (_) {}
      final lastPos = liveFleet?.positions[initialDevice.id];
      provider.setTargetDevice(initialDevice, lastPos);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChangeNotifierProvider.value(
        value: provider,
        child: TelemetryEmulatorSheet(initialDevice: initialDevice),
      ),
    );
  }

  @override
  State<TelemetryEmulatorSheet> createState() => _TelemetryEmulatorSheetState();
}

class _TelemetryEmulatorSheetState extends State<TelemetryEmulatorSheet> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TelemetryEmulatorProvider>();
    _latController = TextEditingController(
      text: provider.currentLat.toStringAsFixed(6),
    );
    _lonController = TextEditingController(
      text: provider.currentLon.toStringAsFixed(6),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialDevice != null &&
          provider.targetUniqueId != widget.initialDevice!.uniqueId) {
        LiveFleetProvider? liveFleet;
        try {
          liveFleet = context.read<LiveFleetProvider>();
        } catch (_) {}
        final lastPos = liveFleet?.positions[widget.initialDevice!.id];
        provider.setTargetDevice(widget.initialDevice!, lastPos);
      }

      // Auto-probe port 5055 if state is unknown
      if (provider.portStatus == OsmandPortStatus.unknown) {
        provider.probePort();
      }
    });
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _syncControllers(double lat, double lon) {
    if (_latController.text != lat.toStringAsFixed(6)) {
      _latController.text = lat.toStringAsFixed(6);
    }
    if (_lonController.text != lon.toStringAsFixed(6)) {
      _lonController.text = lon.toStringAsFixed(6);
    }
  }

  String _getCompassHeading(double bearing) {
    const directions = ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index % 8];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TelemetryEmulatorProvider>();

    // Keep text controllers synchronized during continuous simulations
    _syncControllers(provider.currentLat, provider.currentLon);

    LiveFleetProvider? liveFleet;
    try {
      liveFleet = context.watch<LiveFleetProvider>();
    } catch (_) {}
    final devices = liveFleet?.devices.values.toList() ?? <DeviceModel>[];

    return FractionallySizedBox(
      heightFactor: 0.90,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          appBar: AppBar(
            elevation: 1,
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
            title: Row(
              children: [
                const Icon(Icons.sensors, color: Color(0xFF1E88E5), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Simulator Telemetri (Port 5055)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              _buildPortProbeBadge(provider, isDark),
              IconButton(
                key: const Key('emulator_sheet_close_button'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Target Fleet Selection Section
                _buildTargetDeviceSection(
                  context,
                  provider,
                  devices,
                  liveFleet,
                  isDark,
                ),
                const SizedBox(height: 16),

                // 2. Coordinate Inputs Section
                _buildCoordinatesSection(provider, liveFleet, isDark),
                const SizedBox(height: 16),

                // 3. Telemetry Controls (Speed, Bearing, Battery, Ignition)
                _buildTelemetryControls(provider, isDark),
                const SizedBox(height: 20),

                // 4. Single Fix Action
                _buildSingleFixButton(provider),
                const SizedBox(height: 24),

                // 5. Path Simulation Controls Section
                _buildSimulationSection(provider, isDark),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortProbeBadge(TelemetryEmulatorProvider provider, bool isDark) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (provider.portStatus) {
      case OsmandPortStatus.reachable:
        badgeColor = const Color(0xFF16A34A);
        badgeText = 'Port 5055 Aktif';
        badgeIcon = Icons.check_circle;
        break;
      case OsmandPortStatus.unreachable:
        badgeColor = const Color(0xFFDC2626);
        badgeText = 'Port 5055 Tertutup';
        badgeIcon = Icons.error_outline;
        break;
      case OsmandPortStatus.probing:
        badgeColor = const Color(0xFFD97706);
        badgeText = 'Memeriksa...';
        badgeIcon = Icons.sync;
        break;
      case OsmandPortStatus.unknown:
        badgeColor = const Color(0xFF64748B);
        badgeText = 'Uji Port';
        badgeIcon = Icons.help_outline;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: InkWell(
        key: const Key('emulator_port_probe_badge'),
        onTap: () => provider.probePort(),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 14, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetDeviceSection(
    BuildContext context,
    TelemetryEmulatorProvider provider,
    List<DeviceModel> devices,
    LiveFleetProvider? liveFleet,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target Armada Pelacakan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('emulator_device_dropdown'),
            initialValue: provider.targetUniqueId.isNotEmpty
                ? provider.targetUniqueId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih Kendaraan Target',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: devices.map((d) {
              return DropdownMenuItem<String>(
                value: d.uniqueId,
                child: Text('${d.name} (${d.uniqueId})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final matched = devices.firstWhere(
                  (d) => d.uniqueId == val,
                  orElse: () => DeviceModel(id: 0, name: val, uniqueId: val),
                );
                final lastPos = liveFleet?.positions[matched.id];
                provider.setTargetDevice(matched, lastPos);
              }
            },
          ),
          if (provider.targetUniqueId.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    key: const Key('emulator_target_unique_id_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Unique ID: ${provider.targetUniqueId}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('emulator_use_last_known_position_button'),
                    icon: const Icon(Icons.my_location, size: 14),
                    label: const Text(
                      'Gunakan Posisi Terakhir',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      final matched = devices.firstWhere(
                        (d) => d.uniqueId == provider.targetUniqueId,
                        orElse: () => DeviceModel(
                          id: 0,
                          name: '',
                          uniqueId: provider.targetUniqueId,
                        ),
                      );
                      final lastPos = liveFleet?.positions[matched.id];
                      if (lastPos != null) {
                        provider.setTargetDevice(matched, lastPos);
                        _syncControllers(
                          provider.currentLat,
                          provider.currentLon,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoordinatesSection(
    TelemetryEmulatorProvider provider,
    LiveFleetProvider? liveFleet,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop, color: Color(0xFF1E88E5), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Koordinat Posisi GPS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                key: const Key('emulator_reset_coordinates_button'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  provider.updateCoordinates(lat: -6.2088, lon: 106.8456);
                  _syncControllers(-6.2088, 106.8456);
                },
                child: const Text(
                  'Reset Jakarta',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('emulator_latitude_field'),
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final lat = double.tryParse(val);
                    if (lat != null && lat >= -90.0 && lat <= 90.0) {
                      provider.updateCoordinates(
                        lat: lat,
                        lon: provider.currentLon,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('emulator_longitude_field'),
                  controller: _lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final lon = double.tryParse(val);
                    if (lon != null && lon >= -180.0 && lon <= 180.0) {
                      provider.updateCoordinates(
                        lat: provider.currentLat,
                        lon: lon,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryControls(
    TelemetryEmulatorProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kontrol Parameter Telemetri',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Speed Slider
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: Color(0xFF1E88E5)),
              const SizedBox(width: 6),
              const Text('Kecepatan Kendaraan', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                '${provider.currentSpeed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('emulator_speed_slider'),
            value: provider.currentSpeed,
            min: 0.0,
            max: 160.0,
            divisions: 32,
            activeColor: const Color(0xFF1E88E5),
            onChanged: (val) => provider.updateSpeed(val),
          ),

          // Bearing Slider
          Row(
            children: [
              const Icon(Icons.explore, size: 16, color: Color(0xFF1E88E5)),
              const SizedBox(width: 6),
              const Text(
                'Arah Gerak (Bearing)',
                style: TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${provider.currentBearing.toStringAsFixed(0)}° (${_getCompassHeading(provider.currentBearing)})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('emulator_bearing_slider'),
            value: provider.currentBearing,
            min: 0.0,
            max: 360.0,
            divisions: 72,
            activeColor: const Color(0xFF1E88E5),
            onChanged: (val) => provider.updateBearing(val),
          ),

          // Battery Slider
          Row(
            children: [
              Icon(
                provider.currentBattery > 20
                    ? Icons.battery_full
                    : Icons.battery_alert,
                size: 16,
                color: provider.currentBattery > 20
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              const Text('Level Baterai', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                '${provider.currentBattery.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('emulator_battery_slider'),
            value: provider.currentBattery,
            min: 0.0,
            max: 100.0,
            divisions: 20,
            activeColor: provider.currentBattery > 20
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
            onChanged: (val) => provider.updateBattery(val),
          ),

          // Ignition Toggle
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('emulator_ignition_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Row(
                children: [
                  Icon(
                    Icons.power_settings_new,
                    size: 18,
                    color: provider.isIgnitionOn
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kontak Mesin (Ignition ACC)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: provider.isIgnitionOn
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              value: provider.isIgnitionOn,
              onChanged: (val) => provider.setIgnition(val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleFixButton(TelemetryEmulatorProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        key: const Key('emulator_send_single_fix_button'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: provider.isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          provider.isBusy
              ? 'Mentransmisikan...'
              : 'Kirim Titik Tunggal (HTTP 200)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: provider.isBusy
            ? null
            : () async {
                final ok = await provider.sendSingleFix();
                if (!mounted) return;
                final msg = ok
                    ? 'Posisi berhasil dikirim ke server Traccar (HTTP 200 OK)'
                    : (provider.lastErrorMessage ?? 'Gagal mengirim posisi');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: ok
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildSimulationSection(
    TelemetryEmulatorProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.isSimulating
              ? const Color(0xFF1E88E5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alt_route,
                color: provider.isSimulating
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Simulasi Rute Bergerak (Path Simulator)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildSimulationStatusPill(provider),
            ],
          ),
          const SizedBox(height: 12),

          // Interval Selector Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Interval:', style: TextStyle(fontSize: 12)),
              ActionChip(
                key: const Key('emulator_interval_1s'),
                label: const Text('1 Detik', style: TextStyle(fontSize: 11)),
                backgroundColor: provider.simulationInterval.inSeconds == 1
                    ? const Color(0xFF1E88E5).withValues(alpha: 0.2)
                    : null,
                onPressed: () =>
                    provider.setSimulationInterval(const Duration(seconds: 1)),
              ),
              ActionChip(
                key: const Key('emulator_interval_2s'),
                label: const Text('2 Detik', style: TextStyle(fontSize: 11)),
                backgroundColor: provider.simulationInterval.inSeconds == 2
                    ? const Color(0xFF1E88E5).withValues(alpha: 0.2)
                    : null,
                onPressed: () =>
                    provider.setSimulationInterval(const Duration(seconds: 2)),
              ),
              ActionChip(
                key: const Key('emulator_interval_5s'),
                label: const Text('5 Detik', style: TextStyle(fontSize: 11)),
                backgroundColor: provider.simulationInterval.inSeconds == 5
                    ? const Color(0xFF1E88E5).withValues(alpha: 0.2)
                    : null,
                onPressed: () =>
                    provider.setSimulationInterval(const Duration(seconds: 5)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Simulation Controls (Start, Pause, Stop)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('emulator_start_simulation_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Mulai', overflow: TextOverflow.ellipsis),
                  onPressed: provider.isSimulating
                      ? null
                      : () => provider.startSimulation(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('emulator_pause_simulation_button'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                  ),
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('Jeda', overflow: TextOverflow.ellipsis),
                  onPressed: provider.isSimulating
                      ? () => provider.pauseSimulation()
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('emulator_stop_simulation_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                  ),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text(
                    'Berhenti',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: (provider.isSimulating || provider.isPaused)
                      ? () => provider.stopSimulation()
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Statistics & Transmission Counters
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      key: const Key('emulator_success_counter_text'),
                      'Terkirim: ${provider.transmissionSuccessCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    if (provider.transmissionFailureCount > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        key: const Key('emulator_failure_counter_text'),
                        'Gagal: ${provider.transmissionFailureCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
                if (provider.lastTransmissionTime != null)
                  Text(
                    'Terakhir: ${provider.lastTransmissionTime!.toLocal().toIso8601String().substring(11, 19)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationStatusPill(TelemetryEmulatorProvider provider) {
    Color color;
    String label;

    switch (provider.simulationStatus) {
      case EmulatorSimulationStatus.simulating:
        color = const Color(0xFF16A34A);
        label = 'BERGERAK';
        break;
      case EmulatorSimulationStatus.paused:
        color = const Color(0xFFD97706);
        label = 'DIJEDA';
        break;
      case EmulatorSimulationStatus.sendingSingleFix:
        color = const Color(0xFF1E88E5);
        label = 'MENGIRIM';
        break;
      case EmulatorSimulationStatus.idle:
        color = const Color(0xFF64748B);
        label = 'IDLE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
