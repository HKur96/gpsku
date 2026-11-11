import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import '../widgets/drawer/fleet_list_drawer.dart';
import '../widgets/map/camera_calculation_helper.dart';
import '../widgets/map/fleet_camera_controller.dart';
import '../widgets/map/fleet_map_widget.dart';
import '../widgets/map/fleet_marker_manager.dart';
import '../widgets/sheet/vehicle_detail_sheet.dart';
import 'package:gpsku/features/reports/presentation/screens/route_history_screen.dart';
import 'package:gpsku/features/commands/presentation/widgets/command_bottom_sheet.dart';
import 'package:gpsku/features/geofences/presentation/map/geofence_map_renderer.dart';
import 'package:gpsku/features/geofences/presentation/map/map_geofence_controller.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_list_drawer.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_map_layer_toggle_button.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_list_drawer.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';
import 'package:gpsku/features/drivers/presentation/widgets/driver_list_drawer.dart';
import 'package:gpsku/features/notifications/domain/services/event_stream_service.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';
import 'package:gpsku/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:gpsku/features/notifications/presentation/widgets/emergency_alert_banner.dart';
import 'package:gpsku/features/notifications/presentation/widgets/notifications_drawer.dart';
import 'package:gpsku/features/share/presentation/providers/share_provider.dart';
import 'package:gpsku/features/share/presentation/widgets/share_link_bottom_sheet.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attributes_drawer.dart';
import 'package:gpsku/features/emulator/presentation/providers/telemetry_emulator_provider.dart';
import 'package:gpsku/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';
import 'package:gpsku/features/settings/presentation/screens/app_settings_screen.dart';

/// Bootstrap Fleet Shell screen to verify authentication, DI wiring,
/// and live telematics socket state without production map or report widgets.
class FleetShellScreen extends StatefulWidget {
  const FleetShellScreen({super.key});

  @override
  State<FleetShellScreen> createState() => _FleetShellScreenState();
}

class _FleetShellScreenState extends State<FleetShellScreen> {
  final FleetMarkerManager _markerManager = FleetMarkerManager();
  final GeofenceMapRenderer _geofenceRenderer = GeofenceMapRenderer();
  FleetCameraController? _cameraController;
  AuthProvider? _authProvider;
  bool _hasInitiatedShellSync = false;
  bool _lastKnownAuthenticated = false;
  bool _isSyncPostFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    _markerManager.onMarkerTapped = _onMarkerTapped;
    // Defer initial fleet sync / fallback connection until auth and dependencies are ready
    _scheduleShellInitCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }
    if (!identical(_authProvider, auth)) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = auth;
      _authProvider?.addListener(_onAuthChanged);
    }
    final isAuthenticated = auth?.isAuthenticated ?? false;
    if (isAuthenticated &&
        !_lastKnownAuthenticated &&
        !_hasInitiatedShellSync) {
      _scheduleShellInitCheck();
    }
    _lastKnownAuthenticated = isAuthenticated;
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final isAuthenticated = _authProvider?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      _hasInitiatedShellSync = false;
      _lastKnownAuthenticated = false;
      return;
    }
    if (!_lastKnownAuthenticated && !_hasInitiatedShellSync) {
      _lastKnownAuthenticated = true;
      _scheduleShellInitCheck();
    }
  }

  void _scheduleShellInitCheck() {
    if (_isSyncPostFrameScheduled) return;
    _isSyncPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSyncPostFrameScheduled = false;
      if (!mounted) return;
      _initializeShellOrFallback();
    });
  }

  void _initializeShellOrFallback() {
    if (_hasInitiatedShellSync) return;

    InitialFleetSyncCoordinator? syncCoordinator;
    try {
      syncCoordinator = context.read<InitialFleetSyncCoordinator>();
    } on ProviderNotFoundException {
      syncCoordinator = null;
    }

    GeofencesProvider? geofencesProvider;
    try {
      geofencesProvider = context.read<GeofencesProvider>();
    } on ProviderNotFoundException {
      geofencesProvider = null;
    }

    if (syncCoordinator != null) {
      final isAuthenticated = _authProvider?.isAuthenticated ?? false;
      if (!isAuthenticated) {
        // Wait until authentication succeeds before synchronizing fleet or opening WebSocket.
        return;
      }
      _hasInitiatedShellSync = true;
      if (!syncCoordinator.isLoading && !syncCoordinator.isReady) {
        syncCoordinator.synchronizeFleet();
      }
      geofencesProvider?.fetchGeofences();
      return;
    }

    // Fallback only when InitialFleetSyncCoordinator is not provided (partial test harness)
    _hasInitiatedShellSync = true;
    try {
      final ws = context.read<TraccarWebSocketService>();
      ws.connect();
    } on ProviderNotFoundException {
      // Ignored when running with partial test harness
    }
    geofencesProvider?.fetchGeofences();
  }

  void _onMarkerTapped(int deviceId) {
    final fleet = context.read<LiveFleetProvider>();
    fleet.selectDevice(deviceId);
    final pos = fleet.positions[deviceId];
    if (pos != null &&
        CameraCalculationHelper.isValidCoordinate(
          pos.latitude,
          pos.longitude,
        )) {
      _cameraController?.animateToDevice(
        LatLng(pos.latitude, pos.longitude),
        verticalOffsetPixels: VehicleDetailSheet.estimatedSheetHeight,
      );
    }
  }

  void _handleMapClick(
    BuildContext context,
    LatLng coordinates,
    AuthProvider auth,
    TelemetryEmulatorProvider? telemetryEmulator,
  ) {
    if (telemetryEmulator == null ||
        !auth.canAccessDeveloperTools ||
        !telemetryEmulator.isDeveloperAuthorized ||
        !telemetryEmulator.isMapPickMode) {
      return;
    }

    final accepted = telemetryEmulator.setMapPickedCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (!accepted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            telemetryEmulator.lastErrorMessage ??
                'Koordinat ketukan peta tidak valid.',
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    }
  }

  Future<void> _openSettings(
    BuildContext context,
    AuthProvider auth,
    TelemetryEmulatorProvider? telemetryEmulator,
    DeviceModel? selectedDevice,
  ) async {
    final navigator = Navigator.of(context);
    SettingsLaunchAction? action;
    try {
      action = await context.push<SettingsLaunchAction>('/settings');
    } catch (_) {
      action = await navigator.push<SettingsLaunchAction>(
        MaterialPageRoute<SettingsLaunchAction>(
          builder: (_) => const AppSettingsScreen(),
        ),
      );
    }

    if (!context.mounted || action == null) return;
    if (!auth.canAccessDeveloperTools ||
        telemetryEmulator == null ||
        !telemetryEmulator.isDeveloperAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses ditolak: Mode Pengembang hanya untuk Administrator non-readonly.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    switch (action) {
      case SettingsLaunchAction.openEmulatorSheet:
        final initial = telemetryEmulator.targetUniqueId.isEmpty
            ? selectedDevice
            : null;
        await TelemetryEmulatorSheet.show(context, initialDevice: initial);
        break;
      case SettingsLaunchAction.activateMapPick:
        telemetryEmulator.setMapPickMode(true);
        break;
    }
  }

  Widget _buildMapPickHudPositioned(
    BuildContext context,
    AuthProvider auth,
    TelemetryEmulatorProvider activeEmulator,
    bool hasGeofences,
  ) {
    return Positioned(
      top: 12,
      left: 12,
      right: hasGeofences ? 64 : 12,
      child: _EmulatorMapPickHud(
        provider: activeEmulator,
        onDone: () => activeEmulator.setMapPickMode(false),
        onOpenSheet: () => TelemetryEmulatorSheet.show(context),
        onSendFix: () async {
          if (!auth.canAccessDeveloperTools ||
              !activeEmulator.isDeveloperAuthorized) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Akses ditolak: Administrator non-readonly diperlukan.',
                ),
                backgroundColor: Color(0xFFDC2626),
              ),
            );
            return;
          }
          if (activeEmulator.targetUniqueId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Pilih kendaraan target dahulu sebelum mengirim titik.',
                ),
                backgroundColor: const Color(0xFFD97706),
                action: SnackBarAction(
                  label: 'Pilih Unit',
                  textColor: Colors.white,
                  onPressed: () {
                    if (context.mounted) {
                      TelemetryEmulatorSheet.show(context);
                    }
                  },
                ),
              ),
            );
            return;
          }
          final ok = await activeEmulator.sendSingleFix();
          if (!context.mounted) return;
          final diag = activeEmulator.lastTransportDiagnostics;
          final msg = ok
              ? (diag != null && diag.isFallbackProxy
                    ? 'Posisi terkirim via Fallback Proxy :${diag.endpointUri.port} (HTTP 200 OK)'
                    : 'Posisi berhasil dikirim ke server Traccar (HTTP 200 OK)')
              : (activeEmulator.lastErrorMessage ?? 'Gagal mengirim posisi');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: ok
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _authProvider = null;
    _markerManager.dispose();
    _geofenceRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fleet = context.watch<LiveFleetProvider>();
    GeofencesProvider? geofences;
    try {
      geofences = context.watch<GeofencesProvider>();
    } on ProviderNotFoundException {
      geofences = null;
    }
    MaintenanceProvider? maintenance;
    try {
      maintenance = context.watch<MaintenanceProvider>();
    } on ProviderNotFoundException {
      maintenance = null;
    }
    DriversProvider? drivers;
    try {
      drivers = context.watch<DriversProvider>();
    } on ProviderNotFoundException {
      drivers = null;
    }
    NotificationsProvider? notifications;
    try {
      notifications = context.watch<NotificationsProvider>();
    } on ProviderNotFoundException {
      notifications = null;
    }
    ComputedAttributesProvider? computedAttributes;
    try {
      computedAttributes = context.watch<ComputedAttributesProvider>();
    } on ProviderNotFoundException {
      computedAttributes = null;
    }
    TelemetryEmulatorProvider? telemetryEmulator;
    try {
      telemetryEmulator = context.watch<TelemetryEmulatorProvider>();
    } on ProviderNotFoundException {
      telemetryEmulator = null;
    }
    final user = auth.currentUser;

    if (_geofenceRenderer.isReady && geofences != null) {
      _geofenceRenderer.renderGeofences(geofences.geofences);
      _geofenceRenderer.setVisibility(geofences.isLayersVisible);
    }

    final selectedId = fleet.selectedDeviceId;
    final selectedDevice = selectedId != null
        ? fleet.devices[selectedId]
        : null;
    final selectedPosition = selectedId != null
        ? fleet.positions[selectedId]
        : null;

    Color statusColor = Colors.red;
    String statusText = 'Disconnected';
    switch (fleet.connectionState) {
      case WebSocketConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      case WebSocketConnectionState.connecting:
        statusColor = Colors.blue;
        statusText = 'Connecting...';
        break;
      case WebSocketConnectionState.reconnecting:
        statusColor = Colors.orange;
        statusText = 'Reconnecting...';
        break;
      case WebSocketConnectionState.disconnected:
        statusColor = Colors.red;
        statusText = 'Disconnected';
        break;
    }

    final hasActiveSheet = selectedId != null;
    final hasActiveMapPick =
        auth.canAccessDeveloperTools &&
        (telemetryEmulator?.isDeveloperAuthorized ?? false) &&
        (telemetryEmulator?.isMapPickMode ?? false);

    return PopScope(
      canPop: !hasActiveSheet && !hasActiveMapPick,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasActiveMapPick) {
          telemetryEmulator?.setMapPickMode(false);
          return;
        }
        if (hasActiveSheet) {
          fleet.selectDevice(null);
        }
      },
      child: Scaffold(
        drawer: FleetListDrawer(
          onDeviceSelected: (device, position) {
            _onMarkerTapped(device.id);
          },
        ),
        endDrawer: geofences != null
            ? GeofenceListDrawer(
                onGeofenceSelected: (geofence) {
                  Navigator.of(context).pop();
                  _geofenceRenderer.fitGeofenceBounds(geofence);
                },
              )
            : null,
        appBar: AppBar(
          title: const Text('GPSku Fleet Bootstrap'),
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          actions: [
            if (geofences != null)
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.fence),
                  tooltip: 'Daftar Geofence',
                  onPressed: () {
                    Scaffold.of(ctx).openEndDrawer();
                  },
                ),
              ),
            if (maintenance != null)
              IconButton(
                key: const Key('maintenance_drawer_action_button'),
                icon: const Icon(Icons.build_circle_outlined),
                tooltip: 'Daftar Pemeliharaan',
                onPressed: () {
                  MaintenanceListDrawer.show(context);
                },
              ),
            if (drivers != null)
              IconButton(
                key: const Key('driver_drawer_action_button'),
                icon: const Icon(Icons.badge_outlined),
                tooltip: 'Daftar Pengemudi',
                onPressed: () {
                  DriverListDrawer.show(context);
                },
              ),
            if (computedAttributes != null)
              IconButton(
                key: const Key('computed_attributes_drawer_action_button'),
                icon: const Icon(Icons.calculate_outlined),
                tooltip: 'Atribut Sensor Terhitung',
                onPressed: () {
                  ComputedAttributesDrawer.show(context);
                },
              ),
            if (notifications != null)
              IconButton(
                key: const Key('notifications_drawer_action_button'),
                icon: Badge(
                  isLabelVisible: notifications.unreadCount > 0,
                  label: Text('${notifications.unreadCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Riwayat Notifikasi',
                onPressed: () {
                  NotificationsDrawer.show(
                    context,
                    onSelectDevice: (deviceId) => _onMarkerTapped(deviceId),
                  );
                },
              ),
            IconButton(
              key: const Key('app_settings_action_button'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Pengaturan',
              onPressed: () => _openSettings(
                context,
                auth,
                telemetryEmulator,
                selectedDevice,
              ),
            ),
            IconButton(
              key: const Key('fleet_app_bar_logout_button'),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                _hasInitiatedShellSync = false;
                _lastKnownAuthenticated = false;
                try {
                  context.read<InitialFleetSyncCoordinator>().reset();
                } on ProviderNotFoundException {
                  // Ignored in partial test harness
                }
                final ws = context.read<TraccarWebSocketService>();
                ws.disconnect();
                fleet.clearFleet();
                geofences?.clearGeofences();
                maintenance?.clearMaintenance();
                drivers?.clearDrivers();
                computedAttributes?.clearState();
                telemetryEmulator?.clearState();
                notifications?.clearAll();
                try {
                  context.read<NotificationSettingsProvider>().clearSettings();
                } on ProviderNotFoundException {
                  // Ignored in partial test harness
                }
                try {
                  context.read<EventStreamService>().clearBuffer();
                } on ProviderNotFoundException {
                  // Ignored in partial test harness
                }
                try {
                  context.read<ShareProvider>().clearState();
                } on ProviderNotFoundException {
                  // Ignored in partial test harness
                }
                await _geofenceRenderer.clearGeofences();
                await auth.logout();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (notifications != null)
              EmergencyAlertBanner(
                onCenterDevice: (deviceId) => _onMarkerTapped(deviceId),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // User Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF1E88E5),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name.isNotEmpty == true
                                          ? user!.name
                                          : 'User #${user?.id}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      user?.email ?? 'Unknown Email',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (user?.administrator == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // WebSocket Telemetry Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Real-Time Telemetry Socket',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reconnect'),
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  final ws = context
                                      .read<TraccarWebSocketService>();
                                  ws.connect();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Temporary Map Verification Harness for P7.3.1.1 Real Rendering Test
                  Card(
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: Colors.blue.shade50,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.map,
                                size: 20,
                                color: Color(0xFF1E88E5),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'MapLibre Verification Surface (OpenFreeMap Liberty)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1565C0),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 480,
                          child: Stack(
                            children: [
                              FleetMapWidget(
                                showAttribution: true,
                                onMapClick: (_, coordinates) => _handleMapClick(
                                  context,
                                  coordinates,
                                  auth,
                                  telemetryEmulator,
                                ),
                                onMapReady: (controller, cameraController) {
                                  _cameraController = cameraController;
                                  AppLogger.info(
                                    '[EMULATOR_VERIFY] onMapCreated successfully fired!',
                                  );
                                },
                                onStyleLoaded: (controller) {
                                  AppLogger.info(
                                    '[FLEET_MAP] onStyleLoaded successfully fired! Attaching FleetMarkerManager & GeofenceMapRenderer.',
                                  );
                                  _markerManager.attach(
                                    controller,
                                    fleetProvider: context
                                        .read<LiveFleetProvider>(),
                                  );
                                  _geofenceRenderer.attach(
                                    MapLibreGeofenceAdapter(controller),
                                  );
                                  GeofencesProvider? geofences;
                                  try {
                                    geofences = context
                                        .read<GeofencesProvider>();
                                  } on ProviderNotFoundException {
                                    geofences = null;
                                  }
                                  if (geofences != null &&
                                      geofences.geofences.isNotEmpty) {
                                    _geofenceRenderer.renderGeofences(
                                      geofences.geofences,
                                    );
                                  }
                                },
                              ),
                              if (geofences != null)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: GeofenceMapLayerToggleButton(
                                    onToggle: (visible) {
                                      _geofenceRenderer.setVisibility(visible);
                                    },
                                  ),
                                ),
                              if (hasActiveMapPick && telemetryEmulator != null)
                                _buildMapPickHudPositioned(
                                  context,
                                  auth,
                                  telemetryEmulator,
                                  geofences != null,
                                ),
                              if (selectedDevice != null && !hasActiveMapPick)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: VehicleDetailSheet(
                                    device: selectedDevice,
                                    position: selectedPosition,
                                    onDismiss: () => fleet.selectDevice(null),
                                    onCommandsPressed: () {
                                      CommandBottomSheet.show(
                                        context,
                                        device: selectedDevice,
                                        position: selectedPosition,
                                      );
                                    },
                                    onSharePressed: () {
                                      ShareLinkBottomSheet.show(
                                        context,
                                        device: selectedDevice,
                                      );
                                    },
                                    onHistoryPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RouteHistoryScreen(
                                            deviceId: selectedDevice.id,
                                            deviceName: selectedDevice.name,
                                          ),
                                        ),
                                      );
                                    },
                                    onCenterToVehicle: () {
                                      if (selectedPosition != null &&
                                          CameraCalculationHelper.isValidCoordinate(
                                            selectedPosition.latitude,
                                            selectedPosition.longitude,
                                          )) {
                                        _cameraController?.animateToDevice(
                                          LatLng(
                                            selectedPosition.latitude,
                                            selectedPosition.longitude,
                                          ),
                                          verticalOffsetPixels:
                                              VehicleDetailSheet
                                                  .estimatedSheetHeight,
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Live Devices & Positions Overview
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fleet Buffer Stats (150ms Coalesced)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatColumn(
                                label: 'Total Devices',
                                value: fleet.devices.length.toString(),
                                icon: Icons.directions_car,
                                color: Colors.indigo,
                              ),
                              _StatColumn(
                                label: 'Active Positions',
                                value: fleet.positions.length.toString(),
                                icon: Icons.my_location,
                                color: Colors.teal,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Device List Preview
                  if (fleet.devices.isNotEmpty) ...[
                    const Text(
                      'Connected Devices:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...fleet.devices.values.map((device) {
                      final position = fleet.positions[device.id];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.directions_car,
                            color: device.isOnline ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            position != null
                                ? 'Speed: ${position.speedKmh.toStringAsFixed(1)} km/h | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}'
                                : 'No GPS fix yet',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            device.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: device.isOnline
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No devices reported yet.\nWaiting for telemetry packets over WebSocket...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _EmulatorMapPickHud extends StatelessWidget {
  final TelemetryEmulatorProvider provider;
  final VoidCallback onDone;
  final VoidCallback onOpenSheet;
  final Future<void> Function() onSendFix;

  const _EmulatorMapPickHud({
    required this.provider,
    required this.onDone,
    required this.onOpenSheet,
    required this.onSendFix,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = provider.targetUniqueId.isNotEmpty;

    return Card(
      key: const Key('emulator_map_pick_hud'),
      elevation: 4,
      color: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Color(0xFF1E88E5)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Mode Pilih Koordinat Emulator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  key: const Key('emulator_hud_done_button'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: onDone,
                  child: const Text('Selesai', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              key: const Key('emulator_hud_coordinates_text'),
              'Ketuk peta untuk mengisi koordinat • '
              'Lat: ${provider.currentLat.toStringAsFixed(6)}, '
              'Lon: ${provider.currentLon.toStringAsFixed(6)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 4),
            if (hasTarget)
              Text(
                'Target: ${provider.targetDeviceName ?? provider.targetUniqueId} (${provider.targetUniqueId})',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              )
            else
              const Text(
                key: Key('emulator_hud_no_target_warning'),
                'Pilih kendaraan target dahulu untuk mengirim titik',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  key: const Key('emulator_hud_send_fix_button'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.send, size: 14),
                  label: Text(
                    provider.isBusy ? 'Mengirim...' : 'Kirim Titik Ini',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: provider.isBusy ? null : onSendFix,
                ),
                OutlinedButton.icon(
                  key: const Key('emulator_hud_open_sheet_button'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text(
                    'Panel Lengkap',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: onOpenSheet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
