import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/geofences_provider.dart';

/// Floating map button allowing operators to toggle the visibility of
/// geofence polygons, outlines, and text labels on the MapLibre canvas.
class GeofenceMapLayerToggleButton extends StatelessWidget {
  final ValueChanged<bool>? onToggle;

  const GeofenceMapLayerToggleButton({super.key, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GeofencesProvider>();
    final isVisible = provider.isLayersVisible;

    return FloatingActionButton.small(
      heroTag: 'geofence_layer_toggle_btn',
      backgroundColor: isVisible ? Colors.white : Colors.grey.shade200,
      foregroundColor: isVisible
          ? const Color(0xFF1E88E5)
          : Colors.grey.shade600,
      tooltip: isVisible ? 'Sembunyikan Geofence' : 'Tampilkan Geofence',
      elevation: 3,
      onPressed: () {
        provider.toggleLayersVisible();
        onToggle?.call(provider.isLayersVisible);
      },
      child: Icon(isVisible ? Icons.layers : Icons.layers_clear, size: 20),
    );
  }
}
