import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_test_result_model.dart';
import 'package:gpsku/features/attributes/domain/repositories/computed_attributes_repository.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';

class MockComputedAttributesRepository implements ComputedAttributesRepository {
  List<ComputedAttributeModel> mockAttributes = [];
  Map<int, List<ComputedAttributeModel>> mockDeviceAttributes = {};
  Failure? failureToReturn;
  int? lastDeletedId;
  ComputedAttributeTestResultModel? testResultToReturn;
  final List<({int deviceId, int attributeId})> linkedHistory = [];
  final List<({int deviceId, int attributeId})> unlinkedHistory = [];

  @override
  Future<Either<Failure, List<ComputedAttributeModel>>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (deviceId != null) {
      return Right(mockDeviceAttributes[deviceId] ?? []);
    }
    return Right(mockAttributes);
  }

  @override
  Future<Either<Failure, ComputedAttributeModel>> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final created = attribute.copyWith(id: 999);
    mockAttributes.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, ComputedAttributeModel>> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final idx = mockAttributes.indexWhere((a) => a.id == attribute.id);
    if (idx >= 0) {
      mockAttributes[idx] = attribute;
    }
    return Right(attribute);
  }

  @override
  Future<Either<Failure, void>> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockAttributes.removeWhere((a) => a.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, ComputedAttributeTestResultModel>>
  testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (testResultToReturn != null) return Right(testResultToReturn!);
    return Right(
      ComputedAttributeTestResultModel.success(value: 42.5, type: 'number'),
    );
  }

  @override
  Future<Either<Failure, void>> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    linkedHistory.add((deviceId: deviceId, attributeId: attributeId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    unlinkedHistory.add((deviceId: deviceId, attributeId: attributeId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }
}

void main() {
  late MockComputedAttributesRepository mockRepo;
  late ComputedAttributesProvider provider;

  const tAttr1 = ComputedAttributeModel(
    id: 1,
    description: 'Baterai Rendah',
    attribute: 'batteryLow',
    expression: 'battery < 3.5 ? true : false',
    type: 'boolean',
  );

  const tAttr2 = ComputedAttributeModel(
    id: 2,
    description: 'Konsumsi Bahan Bakar',
    attribute: 'fuelRate',
    expression: 'speed > 60 ? (speed * 0.1) : 0',
    type: 'number',
  );

  const tAttr3 = ComputedAttributeModel(
    id: 3,
    description: 'Status Mesin Teks',
    attribute: 'engineStatus',
    expression: 'ignition ? "ON" : "OFF"',
    type: 'string',
  );

  setUp(() {
    mockRepo = MockComputedAttributesRepository();
    provider = ComputedAttributesProvider(repository: mockRepo);
  });

  group('ComputedAttributesProvider Unit Tests', () {
    test('TC-CAP-01: Initial state is clean, empty, and idle', () {
      expect(provider.attributes, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isTesting, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.searchQuery, isEmpty);
      expect(provider.typeFilter, 'all');
      expect(provider.selectedAttribute, isNull);
      expect(provider.testResult, isNull);
    });

    test(
      'TC-CAP-02: fetchAttributes loads unmodifiable attribute list on success',
      () async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];

        await provider.fetchAttributes();

        expect(provider.attributes.length, 2);
        expect(provider.attributes[0].attribute, 'batteryLow');
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
        expect(
          () => (provider.attributes as dynamic).add(tAttr3),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'TC-CAP-03: fetchAttributes records error message on failure',
      () async {
        mockRepo.failureToReturn = const ServerFailure(
          'Database query timeout',
          statusCode: 500,
        );

        await provider.fetchAttributes();

        expect(provider.attributes, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, 'Database query timeout');
      },
    );

    test(
      'TC-CAP-04: setSearchQuery filters attributes by description, key, or expression',
      () async {
        mockRepo.mockAttributes = [tAttr1, tAttr2, tAttr3];
        await provider.fetchAttributes();

        // Search by description
        provider.setSearchQuery('baterai');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.id, 1);

        // Search by target attribute key
        provider.setSearchQuery('fuelRate');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.id, 2);

        // Search by expression snippet
        provider.setSearchQuery('ignition');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.id, 3);

        // Empty query returns all
        provider.setSearchQuery('');
        expect(provider.filteredAttributes.length, 3);
      },
    );

    test(
      'TC-CAP-05: setTypeFilter restricts attributes strictly by return type',
      () async {
        mockRepo.mockAttributes = [tAttr1, tAttr2, tAttr3];
        await provider.fetchAttributes();

        provider.setTypeFilter('number');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.type, 'number');

        provider.setTypeFilter('string');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.type, 'string');

        provider.setTypeFilter('boolean');
        expect(provider.filteredAttributes.length, 1);
        expect(provider.filteredAttributes.first.type, 'boolean');

        provider.setTypeFilter('all');
        expect(provider.filteredAttributes.length, 3);
      },
    );

    test(
      'TC-CAP-06: createAttribute appends newly created attribute to catalog',
      () async {
        mockRepo.mockAttributes = [tAttr1];
        await provider.fetchAttributes();

        const newAttr = ComputedAttributeModel(
          id: 0,
          description: 'Temperatur Mesin',
          attribute: 'tempEngine',
          expression: 'adc1 * 0.05',
          type: 'number',
        );

        final created = await provider.createAttribute(newAttr);

        expect(created, isNotNull);
        expect(created!.id, 999);
        expect(provider.attributes.length, 2);
        expect(provider.attributes.any((a) => a.id == 999), isTrue);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'TC-CAP-07: updateAttribute modifies matching item and maintains selected reference',
      () async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];
        await provider.fetchAttributes();

        provider.selectAttribute(tAttr1);
        final modified = tAttr1.copyWith(description: 'Baterai Kritis');

        final updated = await provider.updateAttribute(modified);

        expect(updated, isNotNull);
        expect(provider.attributes.first.description, 'Baterai Kritis');
        expect(provider.selectedAttribute?.description, 'Baterai Kritis');
      },
    );

    test(
      'TC-CAP-08: deleteAttribute removes item and cleans up device caches',
      () async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];
        await provider.fetchAttributes();

        final success = await provider.deleteAttribute(1);

        expect(success, isTrue);
        expect(mockRepo.lastDeletedId, 1);
        expect(provider.attributes.length, 1);
        expect(provider.attributes.first.id, 2);
      },
    );

    test(
      'TC-CAP-09: testExpression executes formula test and sets testResult',
      () async {
        mockRepo.testResultToReturn = ComputedAttributeTestResultModel.success(
          value: 12.8,
          type: 'number',
        );

        final result = await provider.testExpression(
          deviceId: 101,
          attribute: tAttr2,
        );

        expect(result, isNotNull);
        expect(result!.success, isTrue);
        expect(result.value, 12.8);
        expect(provider.testResult?.value, 12.8);
        expect(provider.isTesting, isFalse);
      },
    );

    test(
      'TC-CAP-10: testExpression failure records error in result and provider',
      () async {
        mockRepo.failureToReturn = const ServerFailure(
          'JEXL evaluation syntax error',
          statusCode: 400,
        );

        final result = await provider.testExpression(
          deviceId: 101,
          attribute: tAttr2,
        );

        expect(result, isNotNull);
        expect(result!.success, isFalse);
        expect(result.error, 'JEXL evaluation syntax error');
        expect(provider.errorMessage, 'JEXL evaluation syntax error');
        expect(provider.isTesting, isFalse);
      },
    );

    test(
      'TC-CAP-11: getLinkedDeviceIdsForAttribute correctly resolves assigned devices',
      () async {
        mockRepo.mockDeviceAttributes = {
          101: [tAttr1, tAttr2],
          102: [tAttr2],
          103: [tAttr1],
        };

        final linked = await provider.getLinkedDeviceIdsForAttribute(1, [
          101,
          102,
          103,
        ]);

        expect(linked, containsAll([101, 103]));
        expect(linked, isNot(contains(102)));
      },
    );

    test(
      'TC-CAP-12: updateDeviceAssignments diffs and executes link and unlink calls',
      () async {
        final success = await provider.updateDeviceAssignments(
          attributeId: 1,
          selectedDeviceIds: [102, 103],
          initialDeviceIds: [101, 102],
        );

        expect(success, isTrue);
        // 103 was linked
        expect(
          mockRepo.linkedHistory.any(
            (h) => h.deviceId == 103 && h.attributeId == 1,
          ),
          isTrue,
        );
        // 101 was unlinked
        expect(
          mockRepo.unlinkedHistory.any(
            (h) => h.deviceId == 101 && h.attributeId == 1,
          ),
          isTrue,
        );
      },
    );

    test(
      'TC-CAP-13: clearState resets all fields, caches, filters, and test states',
      () async {
        mockRepo.mockAttributes = [tAttr1];
        await provider.fetchAttributes();
        provider.setSearchQuery('baterai');
        provider.setTypeFilter('boolean');
        provider.selectAttribute(tAttr1);

        provider.clearState();

        expect(provider.attributes, isEmpty);
        expect(provider.searchQuery, isEmpty);
        expect(provider.typeFilter, 'all');
        expect(provider.selectedAttribute, isNull);
        expect(provider.testResult, isNull);
      },
    );
  });
}
