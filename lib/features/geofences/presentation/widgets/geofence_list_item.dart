import 'package:flutter/material.dart';
import '../../data/models/geofence_model.dart';
import '../../domain/models/geofence_geometry.dart';
import '../map/geofence_geojson_builder.dart';

/// Single item tile in [GeofenceListDrawer] presenting geofence metadata,
/// geometry indicator icon, telematics attributes, and context actions.
class GeofenceListItem extends StatelessWidget {
  final GeofenceModel geofence;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssignDevices;
  final bool isSelected;

  const GeofenceListItem({
    super.key,
    required this.geofence,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAssignDevices,
    this.isSelected = false,
  });

  Color _parseColor(String? rawColor) {
    final hex = GeofenceGeoJsonBuilder.normalizeHexColor(rawColor);
    final clean = hex.replaceAll('#', '');
    final val = int.tryParse('FF$clean', radix: 16);
    return val != null ? Color(val) : const Color(0xFF1E88E5);
  }

  IconData _getGeometryIcon() {
    if (geofence.isCircle) return Icons.radio_button_checked;
    if (geofence.isPolyline) return Icons.timeline;
    return Icons.crop_square_rounded;
  }

  String _getGeometryLabel() {
    if (geofence.isCircle) return 'Lingkaran';
    if (geofence.isPolyline) return 'Rute / Polyline';
    return 'Poligon';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geomColor = _parseColor(geofence.color);

    final geom = geofence.tryGeometry;
    String? geometryDetail;
    if (geom is CircleGeometry) {
      geometryDetail = 'r = ${geom.radiusMeters.toStringAsFixed(0)} m';
    } else if (geom is PolylineGeometry) {
      geometryDetail =
          'koridor = ${geom.polylineDistance.toStringAsFixed(0)} m';
    } else if (geom is PolygonGeometry) {
      geometryDetail = '${geom.coordinates.length} titik simpul';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: isSelected
            ? BorderSide(color: theme.primaryColor, width: 2.0)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              // 1. Geometry Icon Badge with Color Ring
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: geomColor.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: geomColor, width: 2),
                ),
                child: Icon(_getGeometryIcon(), color: geomColor, size: 22),
              ),
              const SizedBox(width: 12),

              // 2. Geofence Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      geofence.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (geofence.description != null &&
                        geofence.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        geofence.description!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Geometry Type Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _getGeometryLabel(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Geometry Detail (radius, etc.)
                        if (geometryDetail != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              geometryDetail,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        // Speed Limit Badge if present
                        if (geofence.speedLimit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.speed,
                                  size: 12,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${geofence.speedLimit!.toStringAsFixed(0)} km/j',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                tooltip: 'Opsi Geofence',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'assign':
                      onAssignDevices?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Ubah', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'assign',
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 18,
                          color: Colors.green,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tautkan Kendaraan',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
