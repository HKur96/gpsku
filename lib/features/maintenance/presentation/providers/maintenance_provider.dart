import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../data/models/maintenance_model.dart';
import '../../domain/helpers/maintenance_progress_helper.dart';
import '../../domain/repositories/maintenance_repository.dart';

/// Provider managing state for vehicle maintenance scheduling, filtering,
/// telemetry evaluations, CRUD operations, and device permissions assignment.
class MaintenanceProvider extends ChangeNotifier {
  final MaintenanceRepository _repository;

  List<MaintenanceModel> _maintenances = const [];
  final Map<int, List<int>> _deviceMaintenanceMap = {};
  final Map<int, PositionModel> _devicePositions = {};

  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedAlertFilter = 'all'; // 'all', 'overdue', 'warning', 'normal'
  MaintenanceModel? _selectedMaintenance;

  MaintenanceProvider({required MaintenanceRepository repository})
    : _repository = repository;

  List<MaintenanceModel> get maintenances => _maintenances;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedAlertFilter => _selectedAlertFilter;
  MaintenanceModel? get selectedMaintenance => _selectedMaintenance;

  /// Filtered maintenance schedules based on text search query and alert filter chip.
  List<MaintenanceModel> get filteredMaintenances {
    final query = _searchQuery.trim().toLowerCase();

    return _maintenances.where((maintenance) {
      // 1. Alert Filter
      if (_selectedAlertFilter != 'all') {
        final alert = calculateAlertLevel(maintenance);
        if (_selectedAlertFilter == 'overdue' &&
            alert != MaintenanceAlertLevel.overdue) {
          return false;
        }
        if (_selectedAlertFilter == 'warning' &&
            alert != MaintenanceAlertLevel.warning) {
          return false;
        }
        if (_selectedAlertFilter == 'normal' &&
            alert != MaintenanceAlertLevel.normal) {
          return false;
        }
      }

      // 2. Search Query Filter
      if (query.isNotEmpty) {
        final nameMatch = maintenance.name.toLowerCase().contains(query);
        final typeMatch = maintenance.type.toLowerCase().contains(query);
        if (!nameMatch && !typeMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Fetches maintenance schedules from the server.
  Future<void> fetchMaintenances({bool force = false}) async {
    if (_isLoading) return;
    if (_maintenances.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getMaintenances();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'MaintenanceProvider: Failed fetching maintenances: ${failure.message}',
        );
      },
      (fetched) {
        _maintenances = List.unmodifiable(fetched);
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches maintenance items linked to a specific [deviceId].
  Future<void> fetchMaintenanceForDevice(int deviceId) async {
    final result = await _repository.getMaintenances(deviceId: deviceId);

    result.fold(
      (failure) {
        AppLogger.error(
          'MaintenanceProvider: Failed fetching maintenance for device $deviceId: ${failure.message}',
        );
      },
      (deviceMaintenances) {
        _deviceMaintenanceMap[deviceId] = deviceMaintenances
            .map((m) => m.id)
            .toList();

        final currentMap = {for (final m in _maintenances) m.id: m};
        for (final m in deviceMaintenances) {
          currentMap[m.id] = m;
        }
        _maintenances = List.unmodifiable(currentMap.values);
        notifyListeners();
      },
    );
  }

  /// Returns cached maintenance items assigned to [deviceId].
  List<MaintenanceModel> getMaintenanceForDevice(int deviceId) {
    final linkedIds = _deviceMaintenanceMap[deviceId];
    if (linkedIds == null || linkedIds.isEmpty) {
      return const [];
    }
    return _maintenances.where((m) => linkedIds.contains(m.id)).toList();
  }

  /// Programmatically caches known maintenance IDs for a [deviceId].
  void setDeviceMaintenanceLinks(int deviceId, List<int> maintenanceIds) {
    _deviceMaintenanceMap[deviceId] = List.from(maintenanceIds);
    notifyListeners();
  }

  /// Updates cached latest positions for telemetry calculations.
  void updateDevicePositions(Map<int, PositionModel> positions) {
    _devicePositions.addAll(positions);
    notifyListeners();
  }

  /// Updates position for a single device.
  void updateDevicePosition(int deviceId, PositionModel position) {
    _devicePositions[deviceId] = position;
    notifyListeners();
  }

  /// Evaluates the highest alert level for [deviceId] given its telemetry [position].
  MaintenanceAlertLevel evaluateDeviceAlertLevel(
    int deviceId,
    PositionModel? position,
  ) {
    final items = getMaintenanceForDevice(deviceId);
    if (items.isEmpty) return MaintenanceAlertLevel.normal;

    MaintenanceAlertLevel highest = MaintenanceAlertLevel.normal;
    for (final m in items) {
      final currentVal = MaintenanceProgressHelper.extractValue(
        m,
        position: position ?? _devicePositions[deviceId],
      );
      final res = MaintenanceProgressHelper.calculate(
        maintenance: m,
        currentValue: currentVal,
      );

      if (res.alertLevel == MaintenanceAlertLevel.overdue) {
        return MaintenanceAlertLevel.overdue;
      }
      if (res.alertLevel == MaintenanceAlertLevel.warning) {
        highest = MaintenanceAlertLevel.warning;
      }
    }
    return highest;
  }

  /// Alias for [evaluateDeviceAlertLevel].
  MaintenanceAlertLevel getHighestAlertForDevice(
    int deviceId,
    PositionModel? position,
  ) {
    return evaluateDeviceAlertLevel(deviceId, position);
  }

  /// Evaluates aggregate alert level for a [maintenance] across all linked vehicles.
  MaintenanceAlertLevel calculateAlertLevel(MaintenanceModel maintenance) {
    final linkedDeviceIds = <int>[];
    _deviceMaintenanceMap.forEach((deviceId, maintIds) {
      if (maintIds.contains(maintenance.id)) {
        linkedDeviceIds.add(deviceId);
      }
    });

    if (linkedDeviceIds.isEmpty) {
      return MaintenanceAlertLevel.normal;
    }

    MaintenanceAlertLevel highest = MaintenanceAlertLevel.normal;
    for (final deviceId in linkedDeviceIds) {
      final pos = _devicePositions[deviceId];
      final currentVal = MaintenanceProgressHelper.extractValue(
        maintenance,
        position: pos,
      );
      final res = MaintenanceProgressHelper.calculate(
        maintenance: maintenance,
        currentValue: currentVal,
      );

      if (res.alertLevel == MaintenanceAlertLevel.overdue) {
        return MaintenanceAlertLevel.overdue;
      }
      if (res.alertLevel == MaintenanceAlertLevel.warning) {
        highest = MaintenanceAlertLevel.warning;
      }
    }
    return highest;
  }

  /// Returns the worst-case progress result for a [maintenance] across linked devices.
  MaintenanceProgressResult getProgressForMaintenance(
    MaintenanceModel maintenance,
  ) {
    final linkedDeviceIds = <int>[];
    _deviceMaintenanceMap.forEach((deviceId, maintIds) {
      if (maintIds.contains(maintenance.id)) {
        linkedDeviceIds.add(deviceId);
      }
    });

    if (linkedDeviceIds.isEmpty) {
      return MaintenanceProgressHelper.calculate(
        maintenance: maintenance,
        currentValue: maintenance.start,
      );
    }

    MaintenanceProgressResult? worst;
    for (final deviceId in linkedDeviceIds) {
      final pos = _devicePositions[deviceId];
      final currentVal = MaintenanceProgressHelper.extractValue(
        maintenance,
        position: pos,
      );
      final res = MaintenanceProgressHelper.calculate(
        maintenance: maintenance,
        currentValue: currentVal,
      );
      if (worst == null || res.progressRatio > worst.progressRatio) {
        worst = res;
      }
    }

    return worst ??
        MaintenanceProgressHelper.calculate(
          maintenance: maintenance,
          currentValue: maintenance.start,
        );
  }

  /// Sets the active text search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the active alert filter ('all', 'overdue', 'warning', 'normal').
  void setAlertFilter(String filter) {
    if (_selectedAlertFilter == filter) return;
    _selectedAlertFilter = filter;
    notifyListeners();
  }

  /// Selects or deselects a maintenance item.
  void selectMaintenance(MaintenanceModel? maintenance) {
    if (_selectedMaintenance?.id == maintenance?.id) return;
    _selectedMaintenance = maintenance;
    notifyListeners();
  }

  /// Creates a new maintenance schedule.
  Future<bool> createMaintenance(MaintenanceModel maintenance) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.createMaintenance(maintenance);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'MaintenanceProvider: Failed creating maintenance: ${failure.message}',
        );
        return false;
      },
      (created) {
        _maintenances = List.unmodifiable([..._maintenances, created]);
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Updates an existing maintenance schedule.
  Future<bool> updateMaintenance(MaintenanceModel maintenance) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.updateMaintenance(maintenance);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'MaintenanceProvider: Failed updating maintenance: ${failure.message}',
        );
        return false;
      },
      (updated) {
        _maintenances = List.unmodifiable(
          _maintenances.map((m) => m.id == updated.id ? updated : m),
        );
        if (_selectedMaintenance?.id == updated.id) {
          _selectedMaintenance = updated;
        }
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Deletes a maintenance schedule by [id].
  Future<bool> deleteMaintenance(int id) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.deleteMaintenance(id);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'MaintenanceProvider: Failed deleting maintenance #$id: ${failure.message}',
        );
        return false;
      },
      (_) {
        _maintenances = List.unmodifiable(
          _maintenances.where((m) => m.id != id),
        );
        if (_selectedMaintenance?.id == id) {
          _selectedMaintenance = null;
        }
        _deviceMaintenanceMap.forEach((_, list) {
          list.remove(id);
        });
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Quick action to reset maintenance cycle to telemetry reading or specified [newStartValue].
  Future<bool> resetMaintenance(
    MaintenanceModel maintenance, {
    double? newStartValue,
    PositionModel? position,
  }) async {
    double targetStart = newStartValue ?? 0.0;
    if (newStartValue == null) {
      if (position != null) {
        targetStart = MaintenanceProgressHelper.extractValue(
          maintenance,
          position: position,
        );
      } else {
        final linked = <int>[];
        _deviceMaintenanceMap.forEach((dId, mIds) {
          if (mIds.contains(maintenance.id)) linked.add(dId);
        });
        if (linked.isNotEmpty && _devicePositions[linked.first] != null) {
          targetStart = MaintenanceProgressHelper.extractValue(
            maintenance,
            position: _devicePositions[linked.first],
          );
        }
      }
    }

    final updated = maintenance.copyWith(start: targetStart);
    return updateMaintenance(updated);
  }

  /// Queries which candidate devices currently have [maintenanceId] assigned.
  Future<List<int>> getLinkedDeviceIdsForMaintenance(
    int maintenanceId,
    List<int> candidateDeviceIds,
  ) async {
    final linked = <int>[];

    for (final deviceId in candidateDeviceIds) {
      final res = await _repository.getMaintenances(deviceId: deviceId);
      res.fold((_) {}, (deviceMaintenances) {
        _deviceMaintenanceMap[deviceId] = deviceMaintenances
            .map((m) => m.id)
            .toList();
        if (deviceMaintenances.any((m) => m.id == maintenanceId)) {
          linked.add(deviceId);
        }
      });
    }

    return linked;
  }

  /// Reconciles device permissions for [maintenanceId].
  Future<bool> updateDeviceAssignments({
    required int maintenanceId,
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
      final res = await _repository.linkDeviceMaintenance(
        deviceId: deviceId,
        maintenanceId: maintenanceId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        _deviceMaintenanceMap
            .putIfAbsent(deviceId, () => [])
            .add(maintenanceId);
      }
    }

    for (final deviceId in toUnlink) {
      final res = await _repository.unlinkDeviceMaintenance(
        deviceId: deviceId,
        maintenanceId: maintenanceId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        _deviceMaintenanceMap[deviceId]?.remove(maintenanceId);
      }
    }

    notifyListeners();
    return allSuccess;
  }

  /// Clears all cached maintenances, device mappings, filters, and resets state.
  /// Called on session termination or user logout.
  void clearMaintenance() {
    _maintenances = const [];
    _deviceMaintenanceMap.clear();
    _devicePositions.clear();
    _selectedMaintenance = null;
    _searchQuery = '';
    _selectedAlertFilter = 'all';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
