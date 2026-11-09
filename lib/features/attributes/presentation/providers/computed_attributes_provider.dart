import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/computed_attribute_model.dart';
import '../../data/models/computed_attribute_test_result_model.dart';
import '../../domain/repositories/computed_attributes_repository.dart';

/// Provider managing state for Traccar Computed Attributes (JEXL Formulas),
/// catalog querying, search & type filtering, CRUD operations, test runner,
/// and device permissions assignments (Feature F-38).
class ComputedAttributesProvider extends ChangeNotifier {
  final ComputedAttributesRepository _repository;

  List<ComputedAttributeModel> _attributes = const [];
  final Map<int, List<int>> _deviceAttributesMap = {};
  final Map<int, List<int>> _attributeDevicesMap = {};

  bool _isLoading = false;
  bool _isTesting = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'number', 'string', 'boolean'
  ComputedAttributeModel? _selectedAttribute;
  ComputedAttributeTestResultModel? _testResult;

  ComputedAttributesProvider({required ComputedAttributesRepository repository})
    : _repository = repository;

  List<ComputedAttributeModel> get attributes => _attributes;
  bool get isLoading => _isLoading;
  bool get isTesting => _isTesting;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;
  ComputedAttributeModel? get selectedAttribute => _selectedAttribute;
  ComputedAttributeTestResultModel? get testResult => _testResult;

  /// Filtered computed attributes based on active search query and return type filter.
  List<ComputedAttributeModel> get filteredAttributes {
    final query = _searchQuery.trim().toLowerCase();
    final filter = _typeFilter.trim().toLowerCase();

    return _attributes.where((attr) {
      // Type filter match
      if (filter != 'all' && attr.type.toLowerCase() != filter) {
        return false;
      }

      // Search query match
      if (query.isEmpty) return true;

      final descMatch = attr.description.toLowerCase().contains(query);
      final attrMatch = attr.attribute.toLowerCase().contains(query);
      final exprMatch = attr.expression.toLowerCase().contains(query);

      return descMatch || attrMatch || exprMatch;
    }).toList();
  }

  /// Sets the active search query.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the active type filter ('all', 'number', 'string', 'boolean').
  void setTypeFilter(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized == 'all' ||
        ComputedAttributeModel.supportedTypes.contains(normalized)) {
      _typeFilter = normalized;
    } else {
      _typeFilter = 'all';
    }
    notifyListeners();
  }

  /// Selects a specific attribute.
  void selectAttribute(ComputedAttributeModel? attribute) {
    _selectedAttribute = attribute;
    notifyListeners();
  }

  /// Clears the last test result.
  void clearTestResult() {
    _testResult = null;
    notifyListeners();
  }

  /// Fetches computed attributes from the server.
  Future<void> fetchAttributes({bool force = false}) async {
    if (_isLoading) return;
    if (_attributes.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getComputedAttributes();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'ComputedAttributesProvider: Failed fetching attributes: ${failure.message}',
        );
      },
      (fetched) {
        _attributes = List.unmodifiable(fetched);
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches computed attributes linked to a specific [deviceId].
  Future<List<ComputedAttributeModel>> fetchAttributesForDevice(
    int deviceId,
  ) async {
    final result = await _repository.getComputedAttributes(deviceId: deviceId);

    return result.fold(
      (failure) {
        AppLogger.error(
          'ComputedAttributesProvider: Failed fetching attributes for device $deviceId: ${failure.message}',
        );
        return const <ComputedAttributeModel>[];
      },
      (deviceAttrs) {
        _deviceAttributesMap[deviceId] = deviceAttrs.map((a) => a.id).toList();
        for (final attr in deviceAttrs) {
          final list = _attributeDevicesMap.putIfAbsent(attr.id, () => <int>[]);
          if (!list.contains(deviceId)) list.add(deviceId);
        }
        return deviceAttrs;
      },
    );
  }

  /// Creates a new computed attribute.
  Future<ComputedAttributeModel?> createAttribute(
    ComputedAttributeModel attribute,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    ComputedAttributeModel? created;
    final result = await _repository.createComputedAttribute(attribute);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'ComputedAttributesProvider: Failed creating attribute: ${failure.message}',
        );
      },
      (newAttr) {
        final current = List<ComputedAttributeModel>.from(_attributes);
        current.add(newAttr);
        _attributes = List.unmodifiable(current);
        _errorMessage = null;
        created = newAttr;
      },
    );

    _isLoading = false;
    notifyListeners();
    return created;
  }

  /// Updates an existing computed attribute.
  Future<ComputedAttributeModel?> updateAttribute(
    ComputedAttributeModel attribute,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    ComputedAttributeModel? updated;
    final result = await _repository.updateComputedAttribute(attribute);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'ComputedAttributesProvider: Failed updating attribute #${attribute.id}: ${failure.message}',
        );
      },
      (updatedAttr) {
        final current = List<ComputedAttributeModel>.from(_attributes);
        final idx = current.indexWhere((a) => a.id == updatedAttr.id);
        if (idx != -1) {
          current[idx] = updatedAttr;
          _attributes = List.unmodifiable(current);
        }
        if (_selectedAttribute?.id == updatedAttr.id) {
          _selectedAttribute = updatedAttr;
        }
        _errorMessage = null;
        updated = updatedAttr;
      },
    );

    _isLoading = false;
    notifyListeners();
    return updated;
  }

  /// Deletes a computed attribute by [id].
  Future<bool> deleteAttribute(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.deleteComputedAttribute(id);
    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppLogger.error(
          'ComputedAttributesProvider: Failed deleting attribute #$id: ${failure.message}',
        );
        return false;
      },
      (_) {
        _attributes = List.unmodifiable(_attributes.where((a) => a.id != id));
        if (_selectedAttribute?.id == id) {
          _selectedAttribute = null;
        }
        _deviceAttributesMap.forEach((_, list) {
          list.remove(id);
        });
        _attributeDevicesMap.remove(id);
        _errorMessage = null;
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Evaluates an attribute expression against the latest telemetry of [deviceId].
  Future<ComputedAttributeTestResultModel?> testExpression({
    required int deviceId,
    required ComputedAttributeModel attribute,
  }) async {
    _isTesting = true;
    _errorMessage = null;
    _testResult = null;
    notifyListeners();

    final result = await _repository.testComputedAttribute(
      deviceId: deviceId,
      attribute: attribute,
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _testResult = ComputedAttributeTestResultModel.failure(
          error: failure.message,
          type: attribute.type,
        );
        AppLogger.error(
          'ComputedAttributesProvider: Test formula evaluation failed: ${failure.message}',
        );
      },
      (testRes) {
        _testResult = testRes;
        _errorMessage = null;
      },
    );

    _isTesting = false;
    notifyListeners();
    return _testResult;
  }

  /// Queries which candidate devices currently have [attributeId] assigned.
  Future<List<int>> getLinkedDeviceIdsForAttribute(
    int attributeId,
    List<int> candidateDeviceIds,
  ) async {
    final linked = <int>[];

    for (final deviceId in candidateDeviceIds) {
      final res = await _repository.getComputedAttributes(deviceId: deviceId);
      res.fold((_) {}, (deviceAttrs) {
        _deviceAttributesMap[deviceId] = deviceAttrs.map((a) => a.id).toList();
        for (final a in deviceAttrs) {
          final list = _attributeDevicesMap.putIfAbsent(a.id, () => <int>[]);
          if (!list.contains(deviceId)) list.add(deviceId);
        }
        if (deviceAttrs.any((a) => a.id == attributeId)) {
          linked.add(deviceId);
        }
      });
    }

    return linked;
  }

  /// Reconciles device permissions for [attributeId].
  Future<bool> updateDeviceAssignments({
    required int attributeId,
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
      final res = await _repository.linkDeviceAttribute(
        deviceId: deviceId,
        attributeId: attributeId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        final list = _deviceAttributesMap.putIfAbsent(deviceId, () => <int>[]);
        if (!list.contains(attributeId)) list.add(attributeId);

        final attrDevices = _attributeDevicesMap.putIfAbsent(
          attributeId,
          () => <int>[],
        );
        if (!attrDevices.contains(deviceId)) attrDevices.add(deviceId);
      }
    }

    for (final deviceId in toUnlink) {
      final res = await _repository.unlinkDeviceAttribute(
        deviceId: deviceId,
        attributeId: attributeId,
      );
      if (res.isLeft()) {
        allSuccess = false;
        res.fold((f) => _errorMessage = f.message, (_) {});
      } else {
        _deviceAttributesMap[deviceId]?.remove(attributeId);
        _attributeDevicesMap[attributeId]?.remove(deviceId);
      }
    }

    notifyListeners();
    return allSuccess;
  }

  /// Clears all cached state on logout.
  void clearState() {
    _attributes = const [];
    _deviceAttributesMap.clear();
    _attributeDevicesMap.clear();
    _isLoading = false;
    _isTesting = false;
    _errorMessage = null;
    _searchQuery = '';
    _typeFilter = 'all';
    _selectedAttribute = null;
    _testResult = null;
    notifyListeners();
  }
}
