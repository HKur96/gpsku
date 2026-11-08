import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../data/models/driver_model.dart';
import '../../domain/helpers/active_driver_resolver.dart';
import '../../domain/repositories/drivers_repository.dart';

/// Provider managing state for Traccar Drivers catalog, searching,
/// telemetry RFID resolution, CRUD operations, and device permissions assignments.
class DriversProvider extends ChangeNotifier {
  final DriversRepository _repository;

  List<DriverModel> _drivers = const [];
  final Map<int, List<int>> _deviceDriversMap = {};
  final Map<int, List<int>> _driverDevicesMap = {};

  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  DriverModel? _selectedDriver;

  DriversProvider({required DriversRepository repository})
    : _repository = repository;

  List<DriverModel> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  DriverModel? get selectedDriver => _selectedDriver;

  /// Filtered drivers based on text search query (matches name, uniqueId, phone, license).
  List<DriverModel> get filteredDrivers {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _drivers;

    return _drivers.where((driver) {
      final nameMatch = driver.name.toLowerCase().contains(query);
      final idMatch = driver.uniqueId.toLowerCase().contains(query);
      final phoneMatch = driver.phone?.toLowerCase().contains(query) ?? false;
      final licenseMatch =
          driver.license?.toLowerCase().contains(query) ?? false;
      return nameMatch || idMatch || phoneMatch || licenseMatch;
    }).toList();
  }

  /// Sets the active search query.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Selects a specific driver.
  void selectDriver(DriverModel? driver) {
    _selectedDriver = driver;
    notifyListeners();
  }

  /// Fetches drivers from the server.
  Future<void> fetchDrivers({bool force = false}) async {
    if (_isLoading) return;
    if (_drivers.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getDrivers();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'DriversProvider: Failed fetching drivers: ${failure.message}',
        );
      },
      (fetched) {
        _drivers = List.unmodifiable(fetched);
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches driver items linked to a specific [deviceId].
  Future<void> fetchDriversForDevice(int deviceId) async {
    final result = await _repository.getDrivers(deviceId: deviceId);

    result.fold(
      (failure) {
        AppLogger.error(
          'DriversProvider: Failed fetching drivers for device $deviceId: ${failure.message}',
        );
      },
      (deviceDrivers) {
        _deviceDriversMap[deviceId] = deviceDrivers.map((d) => d.id).toList();

        for (final d in deviceDrivers) {
          final list = _driverDevicesMap.putIfAbsent(d.id, () => <int>[]);
          if (!list.contains(deviceId)) list.add(deviceId);
        }

        final currentMap = {for (final d in _drivers) d.id: d};
        for (final d in deviceDrivers) {
          currentMap[d.id] = d;
        }
        _drivers = List.unmodifiable(currentMap.values);
        notifyListeners();
      },
    );
  }

  /// Returns cached drivers assigned to [deviceId].
  List<DriverModel> getDriversForDevice(int deviceId) {
    final linkedIds = _deviceDriversMap[deviceId];
    if (linkedIds == null || linkedIds.isEmpty) {
      return const [];
    }
    return _drivers.where((d) => linkedIds.contains(d.id)).toList();
  }

  /// Programmatically caches known driver IDs for a [deviceId].
  void setDeviceDriverLinks(int deviceId, List<int> driverIds) {
    _deviceDriversMap[deviceId] = List.from(driverIds);
    for (final driverId in driverIds) {
      final list = _driverDevicesMap.putIfAbsent(driverId, () => <int>[]);
      if (!list.contains(deviceId)) list.add(deviceId);
    }
    notifyListeners();
  }

  /// Resolves the active [DriverModel] from a given telemetry [position].
  DriverModel? resolveActiveDriver(PositionModel? position) {
    return ActiveDriverResolver.resolveFromPosition(
      position: position,
      drivers: _drivers,
    );
  }

  /// Resolves a [DriverModel] by its RFID / iButton [uniqueId].
  DriverModel? getDriverByUniqueId(String uniqueId) {
    return ActiveDriverResolver.resolveByUniqueId(
      driverUniqueId: uniqueId,
      drivers: _drivers,
    );
  }

  /// Creates a new driver.
  Future<DriverModel?> createDriver(DriverModel driver) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.createDriver(driver);
    DriverModel? createdDriver;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'DriversProvider: Failed creating driver: ${failure.message}',
        );
      },
      (created) {
        final current = List<DriverModel>.from(_drivers);
        current.add(created);
        _drivers = List.unmodifiable(current);
        _selectedDriver = created;
        _errorMessage = null;
        createdDriver = created;
      },
    );

    _isLoading = false;
    notifyListeners();
    return createdDriver;
  }

  /// Updates an existing driver.
  Future<DriverModel?> updateDriver(DriverModel driver) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.updateDriver(driver);
    DriverModel? updatedDriver;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'DriversProvider: Failed updating driver #${driver.id}: ${failure.message}',
        );
      },
      (updated) {
        final current = List<DriverModel>.from(_drivers);
        final idx = current.indexWhere((d) => d.id == updated.id);
        if (idx != -1) {
          current[idx] = updated;
          _drivers = List.unmodifiable(current);
        }
        if (_selectedDriver?.id == updated.id) {
          _selectedDriver = updated;
        }
        _errorMessage = null;
        updatedDriver = updated;
      },
    );

    _isLoading = false;
    notifyListeners();
    return updatedDriver;
  }

  /// Deletes a driver by [id].
  Future<bool> deleteDriver(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.deleteDriver(id);
    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'DriversProvider: Failed deleting driver #$id: ${failure.message}',
        );
        return false;
      },
      (_) {
        _drivers = List.unmodifiable(_drivers.where((d) => d.id != id));
        if (_selectedDriver?.id == id) {
          _selectedDriver = null;
        }
        _deviceDriversMap.forEach((_, list) {
          list.remove(id);
        });
        _driverDevicesMap.remove(id);
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Queries which candidate devices currently have [driverId] assigned.
  Future<List<int>> getLinkedDeviceIdsForDriver(
    int driverId,
    List<int> candidateDeviceIds,
  ) async {
    final linked = <int>[];

    for (final deviceId in candidateDeviceIds) {
      final res = await _repository.getDrivers(deviceId: deviceId);
      res.fold((_) {}, (deviceDrivers) {
        _deviceDriversMap[deviceId] = deviceDrivers.map((d) => d.id).toList();
        for (final d in deviceDrivers) {
          final list = _driverDevicesMap.putIfAbsent(d.id, () => <int>[]);
          if (!list.contains(deviceId)) list.add(deviceId);
        }
        if (deviceDrivers.any((d) => d.id == driverId)) {
          linked.add(deviceId);
        }
      });
    }

    return linked;
  }

  /// Reconciles device permissions for [driverId].
  Future<bool> updateDeviceAssignments({
    required int driverId,
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
      final res = await _repository.linkDeviceDriver(
        deviceId: deviceId,
        driverId: driverId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        final list = _deviceDriversMap.putIfAbsent(deviceId, () => <int>[]);
        if (!list.contains(driverId)) list.add(driverId);

        final driverDevices = _driverDevicesMap.putIfAbsent(
          driverId,
          () => <int>[],
        );
        if (!driverDevices.contains(deviceId)) driverDevices.add(deviceId);
      }
    }

    for (final deviceId in toUnlink) {
      final res = await _repository.unlinkDeviceDriver(
        deviceId: deviceId,
        driverId: driverId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        _deviceDriversMap[deviceId]?.remove(driverId);
        _driverDevicesMap[driverId]?.remove(deviceId);
      }
    }

    notifyListeners();
    return allSuccess;
  }

  /// Clears all cached state on logout.
  void clearDrivers() {
    _drivers = const [];
    _deviceDriversMap.clear();
    _driverDevicesMap.clear();
    _isLoading = false;
    _errorMessage = null;
    _searchQuery = '';
    _selectedDriver = null;
    notifyListeners();
  }
}
