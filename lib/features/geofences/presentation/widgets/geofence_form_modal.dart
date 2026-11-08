import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/geofence_model.dart';
import '../../domain/models/geofence_geometry.dart';
import '../map/geofence_geojson_builder.dart';
import '../providers/geofences_provider.dart';

/// Modal bottom sheet form for creating or editing Traccar Geofences.
class GeofenceFormModal extends StatefulWidget {
  final GeofenceModel? geofence;

  const GeofenceFormModal({super.key, this.geofence});

  /// Displays the modal sheet and returns the saved [GeofenceModel] on success.
  static Future<GeofenceModel?> show(
    BuildContext context, {
    GeofenceModel? geofence,
  }) {
    return showModalBottomSheet<GeofenceModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => GeofenceFormModal(geofence: geofence),
    );
  }

  @override
  State<GeofenceFormModal> createState() => _GeofenceFormModalState();
}

class _GeofenceFormModalState extends State<GeofenceFormModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _speedLimitController;

  // Geometry-specific controllers
  late TextEditingController _circleRadiusController;
  late TextEditingController _circleLatController;
  late TextEditingController _circleLonController;
  late TextEditingController _wktAreaController;
  late TextEditingController _polylineDistanceController;

  late String _selectedGeometryType; // 'POLYGON', 'CIRCLE', 'LINESTRING'
  late String _selectedColorHex;
  bool _isSubmitting = false;

  static const List<String> _presetColors = [
    '#1E88E5', // Primary Blue
    '#4CAF50', // Material Green
    '#E53935', // Crimson Red
    '#FB8C00', // Amber Orange
    '#8E24AA', // Purple
    '#00ACC1', // Cyan
    '#3949AB', // Indigo
    '#757575', // Slate Grey
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;

    _nameController = TextEditingController(text: g?.name ?? '');
    _descriptionController = TextEditingController(text: g?.description ?? '');
    _speedLimitController = TextEditingController(
      text: g?.speedLimit != null ? g!.speedLimit!.toStringAsFixed(0) : '',
    );

    _selectedColorHex = GeofenceGeoJsonBuilder.normalizeHexColor(
      g?.color ?? _presetColors.first,
    );

    // Geometry type deduction
    if (g != null) {
      if (g.isCircle) {
        _selectedGeometryType = 'CIRCLE';
      } else if (g.isPolyline) {
        _selectedGeometryType = 'LINESTRING';
      } else {
        _selectedGeometryType = 'POLYGON';
      }
    } else {
      _selectedGeometryType = 'CIRCLE'; // Default for new geofences
    }

    // Initialize geometry fields
    final geom = g?.tryGeometry;
    if (geom is CircleGeometry) {
      _circleRadiusController = TextEditingController(
        text: geom.radiusMeters.toStringAsFixed(0),
      );
      _circleLatController = TextEditingController(
        text: geom.center.latitude.toStringAsFixed(6),
      );
      _circleLonController = TextEditingController(
        text: geom.center.longitude.toStringAsFixed(6),
      );
    } else {
      _circleRadiusController = TextEditingController(text: '500');
      _circleLatController = TextEditingController(text: '-6.208800');
      _circleLonController = TextEditingController(text: '106.845600');
    }

    _wktAreaController = TextEditingController(
      text: g != null
          ? g.area
          : 'POLYGON ((-6.2000 106.8100, -6.2100 106.8200, -6.2200 106.8000, -6.2000 106.8100))',
    );

    _polylineDistanceController = TextEditingController(
      text: (g?.polylineDistance ?? 25.0).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _speedLimitController.dispose();
    _circleRadiusController.dispose();
    _circleLatController.dispose();
    _circleLonController.dispose();
    _wktAreaController.dispose();
    _polylineDistanceController.dispose();
    super.dispose();
  }

  String _buildWktArea() {
    switch (_selectedGeometryType) {
      case 'CIRCLE':
        final lat =
            double.tryParse(_circleLatController.text.trim()) ?? -6.2088;
        final lon =
            double.tryParse(_circleLonController.text.trim()) ?? 106.8456;
        final radius =
            double.tryParse(_circleRadiusController.text.trim()) ?? 500.0;
        return 'CIRCLE ($lat $lon, $radius)';

      case 'LINESTRING':
      case 'POLYGON':
      default:
        return _wktAreaController.text.trim();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<GeofencesProvider>();

    final double? speedLimit = _speedLimitController.text.trim().isNotEmpty
        ? double.tryParse(_speedLimitController.text.trim())
        : null;

    final double? polylineDist = _selectedGeometryType == 'LINESTRING'
        ? double.tryParse(_polylineDistanceController.text.trim())
        : null;

    final areaWkt = _buildWktArea();

    final attributes = <String, dynamic>{
      if (widget.geofence?.attributes != null) ...widget.geofence!.attributes,
      'color': _selectedColorHex,
      if (speedLimit != null) 'speedLimit': speedLimit,
      if (polylineDist != null) 'polylineDistance': polylineDist,
    };

    final isEdit = widget.geofence != null;
    final model = GeofenceModel(
      id: isEdit ? widget.geofence!.id : 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      area: areaWkt,
      calendarId: widget.geofence?.calendarId,
      attributes: attributes,
    );

    final success = isEdit
        ? await provider.updateGeofence(model)
        : await provider.createGeofence(model);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(model);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Geofence "${model.name}" berhasil diperbarui'
                  : 'Geofence "${model.name}" berhasil dibuat',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menyimpan geofence'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.geofence != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEdit
                            ? Icons.edit_location_alt
                            : Icons.add_location_alt,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEdit ? 'Ubah Geofence' : 'Tambah Geofence Baru',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // 1. Geometry Type Selector
              const Text(
                'Tipe Geometri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'CIRCLE',
                    label: Text('Lingkaran'),
                    icon: Icon(Icons.radio_button_checked, size: 16),
                  ),
                  ButtonSegment(
                    value: 'POLYGON',
                    label: Text('Poligon'),
                    icon: Icon(Icons.crop_square, size: 16),
                  ),
                  ButtonSegment(
                    value: 'LINESTRING',
                    label: Text('Rute'),
                    icon: Icon(Icons.timeline, size: 16),
                  ),
                ],
                selected: {_selectedGeometryType},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedGeometryType = set.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 2. Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Geofence *',
                  hintText: 'Misal: Gudang Utama Cakung',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama geofence wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 3. Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  hintText: 'Zona pembatasan parkir & bongkar muat',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 4. Color Presets Selector
              const Text(
                'Warna Perimeter',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final hex = _presetColors[idx];
                    final isSelected =
                        _selectedColorHex.toUpperCase() == hex.toUpperCase();
                    final color = Color(
                      int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                    );

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedColorHex = hex);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.white,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 5. Geometry-Specific Form Fields
              if (_selectedGeometryType == 'CIRCLE') ...[
                const Text(
                  'Parameter Lingkaran',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _circleRadiusController,
                        decoration: const InputDecoration(
                          labelText: 'Radius (meter) *',
                          border: OutlineInputBorder(),
                          suffixText: 'm',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          final r = double.tryParse(val ?? '');
                          if (r == null || r <= 0) {
                            return 'Radius harus > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _circleLatController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude Titik Pusat *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) {
                          final lat = double.tryParse(val ?? '');
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Latitude -90 s/d 90';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _circleLonController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude Titik Pusat *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) {
                          final lon = double.tryParse(val ?? '');
                          if (lon == null || lon < -180 || lon > 180) {
                            return 'Longitude -180 s/d 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedGeometryType == 'LINESTRING') ...[
                const Text(
                  'Parameter Rute Koridor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _polylineDistanceController,
                  decoration: const InputDecoration(
                    labelText: 'Lebar Koridor Penyangga (meter)',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _wktAreaController,
                  decoration: const InputDecoration(
                    labelText: 'WKT LINESTRING *',
                    hintText: 'LINESTRING (lat1 lon1, lat2 lon2, ...)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Definisi WKT rute wajib diisi';
                    }
                    return null;
                  },
                ),
              ] else ...[
                const Text(
                  'Perimeter Poligon (WKT)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _wktAreaController,
                  decoration: const InputDecoration(
                    labelText: 'Koordinat Simpul WKT POLYGON *',
                    hintText: 'POLYGON ((lat1 lon1, lat2 lon2, ...))',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Definisi WKT poligon wajib diisi';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // 6. Speed Limit (Optional)
              TextFormField(
                controller: _speedLimitController,
                decoration: const InputDecoration(
                  labelText: 'Batas Kecepatan Maksimum (Opsional)',
                  hintText: 'Misal: 40',
                  suffixText: 'km/j',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // 7. Submit Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSubmitting ? 'Menyimpan...' : 'Simpan Geofence',
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
