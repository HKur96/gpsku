import 'package:flutter/material.dart';
import 'package:gpsku/core/utils/app_logger.dart';
import '../../data/models/geofence_model.dart';
import '../../domain/repositories/geofences_repository.dart';

/// Provider managing state for Geofence inventory, filtering, selection,
/// CRUD operations, and device permissions assignment.
class GeofencesProvider extends ChangeNotifier {
  final GeofencesRepository _repository;

  List<GeofenceModel> _geofences = const [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedGeometryFilter =
      'all'; // 'all', 'POLYGON', 'CIRCLE', 'LINESTRING'
  GeofenceModel? _selectedGeofence;
  bool _isLayersVisible = true;

  GeofencesProvider({required GeofencesRepository repository})
    : _repository = repository;

  List<GeofenceModel> get geofences => _geofences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedGeometryFilter => _selectedGeometryFilter;
  GeofenceModel? get selectedGeofence => _selectedGeofence;
  bool get isLayersVisible => _isLayersVisible;

  /// Filtered geofences based on search query and geometry filter chip.
  List<GeofenceModel> get filteredGeofences {
    final query = _searchQuery.trim().toLowerCase();

    return _geofences.where((geofence) {
      // 1. Geometry Filter
      if (_selectedGeometryFilter != 'all') {
        if (_selectedGeometryFilter == 'POLYGON' && !geofence.isPolygon) {
          return false;
        }
        if (_selectedGeometryFilter == 'CIRCLE' && !geofence.isCircle) {
          return false;
        }
        if (_selectedGeometryFilter == 'LINESTRING' && !geofence.isPolyline) {
          return false;
        }
      }

      // 2. Search Query Filter
      if (query.isNotEmpty) {
        final nameMatch = geofence.name.toLowerCase().contains(query);
        final descMatch =
            geofence.description?.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !descMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Fetches geofences from the server.
  Future<void> fetchGeofences({bool force = false}) async {
    if (_isLoading) return;
    if (_geofences.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getGeofences();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'GeofencesProvider: Failed fetching geofences: ${failure.message}',
        );
      },
      (fetchedGeofences) {
        _geofences = List.unmodifiable(fetchedGeofences);
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Sets the active text search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the geometry type filter ('all', 'POLYGON', 'CIRCLE', 'LINESTRING').
  void setGeometryFilter(String filter) {
    if (_selectedGeometryFilter == filter) return;
    _selectedGeometryFilter = filter;
    notifyListeners();
  }

  /// Selects or deselects a geofence.
  void selectGeofence(GeofenceModel? geofence) {
    if (_selectedGeofence?.id == geofence?.id) return;
    _selectedGeofence = geofence;
    notifyListeners();
  }

  /// Explicitly sets geofence map layers visibility.
  void setLayersVisible(bool visible) {
    if (_isLayersVisible == visible) return;
    _isLayersVisible = visible;
    notifyListeners();
  }

  /// Toggles geofence map layers visibility.
  void toggleLayersVisible() {
    setLayersVisible(!_isLayersVisible);
  }

  /// Creates a new geofence and adds it to the active collection.
  Future<bool> createGeofence(GeofenceModel geofence) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.createGeofence(geofence);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'GeofencesProvider: Failed creating geofence: ${failure.message}',
        );
        return false;
      },
      (created) {
        _geofences = List.unmodifiable([..._geofences, created]);
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Updates an existing geofence.
  Future<bool> updateGeofence(GeofenceModel geofence) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.updateGeofence(geofence);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'GeofencesProvider: Failed updating geofence: ${failure.message}',
        );
        return false;
      },
      (updated) {
        _geofences = List.unmodifiable(
          _geofences.map((g) => g.id == updated.id ? updated : g),
        );
        if (_selectedGeofence?.id == updated.id) {
          _selectedGeofence = updated;
        }
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Deletes a geofence by [id].
  Future<bool> deleteGeofence(int id) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.deleteGeofence(id);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'GeofencesProvider: Failed deleting geofence #$id: ${failure.message}',
        );
        return false;
      },
      (_) {
        _geofences = List.unmodifiable(_geofences.where((g) => g.id != id));
        if (_selectedGeofence?.id == id) {
          _selectedGeofence = null;
        }
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Queries which candidate devices currently have [geofenceId] assigned.
  Future<List<int>> getLinkedDeviceIdsForGeofence(
    int geofenceId,
    List<int> candidateDeviceIds,
  ) async {
    final linked = <int>[];

    for (final deviceId in candidateDeviceIds) {
      final res = await _repository.getGeofences(deviceId: deviceId);
      res.fold((_) {}, (deviceGeofences) {
        if (deviceGeofences.any((g) => g.id == geofenceId)) {
          linked.add(deviceId);
        }
      });
    }

    return linked;
  }

  /// Reconciles device permissions for [geofenceId].
  /// Links newly selected devices and unlinks unselected devices.
  Future<bool> updateDeviceAssignments({
    required int geofenceId,
    required List<int> selectedDeviceIds,
    required List<int> initialDeviceIds,
  }) async {
    final toLink = selectedDeviceIds
        .where((id) => !initialDeviceIds.contains(id))
        .toList();
    final toUnlink = initialDeviceIds
        .where((id) => !selectedDeviceIds.contains(id))
        .toList();

    bool allSuccess = true;

    for (final deviceId in toLink) {
      final res = await _repository.linkDeviceGeofence(
        deviceId: deviceId,
        geofenceId: geofenceId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      }
    }

    for (final deviceId in toUnlink) {
      final res = await _repository.unlinkDeviceGeofence(
        deviceId: deviceId,
        geofenceId: geofenceId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      }
    }

    notifyListeners();
    return allSuccess;
  }

  /// Clears all cached geofences, filters, selection, and resets state.
  /// Called on session termination or user logout.
  void clearGeofences() {
    _geofences = const [];
    _selectedGeofence = null;
    _searchQuery = '';
    _selectedGeometryFilter = 'all';
    _isLayersVisible = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
