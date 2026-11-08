import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
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

  @override
  void initState() {
    super.initState();
    _markerManager.onMarkerTapped = _onMarkerTapped;
    // Connect WebSocket and fetch geofences when entering authenticated shell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final ws = context.read<TraccarWebSocketService>();
        ws.connect();
      } on ProviderNotFoundException {
        // Ignored when running with partial test harness
      }
      try {
        final geofencesProvider = context.read<GeofencesProvider>();
        geofencesProvider.fetchGeofences();
      } on ProviderNotFoundException {
        // Ignored when running with partial test harness
      }
    });
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

  @override
  void dispose() {
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

    return PopScope(
      canPop: !hasActiveSheet,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                final ws = context.read<TraccarWebSocketService>();
                ws.disconnect();
                fleet.clearFleet();
                geofences?.clearGeofences();
                await _geofenceRenderer.clearGeofences();
                await auth.logout();
              },
            ),
          ],
        ),
        body: ListView(
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
                            final ws = context.read<TraccarWebSocketService>();
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
                        Icon(Icons.map, size: 20, color: Color(0xFF1E88E5)),
                        SizedBox(width: 8),
                        Text(
                          'MapLibre Verification Surface (OpenFreeMap Liberty)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1565C0),
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
                              fleetProvider: context.read<LiveFleetProvider>(),
                            );
                            _geofenceRenderer.attach(
                              MapLibreGeofenceAdapter(controller),
                            );
                            GeofencesProvider? geofences;
                            try {
                              geofences = context.read<GeofencesProvider>();
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
                        if (selectedDevice != null)
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
                                        VehicleDetailSheet.estimatedSheetHeight,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                        color: device.isOnline ? Colors.green : Colors.grey,
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
