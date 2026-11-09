import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/attributes/data/datasources/computed_attributes_remote_data_source.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_test_result_model.dart';
import 'package:gpsku/features/attributes/data/repositories/computed_attributes_repository_impl.dart';

class MockComputedAttributesRemoteDataSource
    implements ComputedAttributesRemoteDataSource {
  List<ComputedAttributeModel> mockAttributes = [];
  ComputedAttributeModel? mockCreatedAttribute;
  ComputedAttributeModel? mockUpdatedAttribute;
  ComputedAttributeTestResultModel? mockTestResult;
  Exception? exceptionToThrow;

  bool deleteCalled = false;
  int? lastDeletedId;
  int? lastLinkDeviceId;
  int? lastLinkAttributeId;
  int? lastUnlinkDeviceId;
  int? lastUnlinkAttributeId;
  int? lastLinkGroupId;
  int? lastUnlinkGroupId;

  @override
  Future<List<ComputedAttributeModel>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockAttributes;
  }

  @override
  Future<ComputedAttributeModel> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockCreatedAttribute ?? attribute;
  }

  @override
  Future<ComputedAttributeModel> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockUpdatedAttribute ?? attribute;
  }

  @override
  Future<void> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    deleteCalled = true;
    lastDeletedId = id;
  }

  @override
  Future<ComputedAttributeTestResultModel> testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockTestResult ??
        ComputedAttributeTestResultModel.success(
          value: 'mock_result',
          type: attribute.type,
        );
  }

  @override
  Future<void> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastLinkDeviceId = deviceId;
    lastLinkAttributeId = attributeId;
  }

  @override
  Future<void> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastUnlinkDeviceId = deviceId;
    lastUnlinkAttributeId = attributeId;
  }

  @override
  Future<void> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastLinkGroupId = groupId;
    lastLinkAttributeId = attributeId;
  }

  @override
  Future<void> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastUnlinkGroupId = groupId;
    lastUnlinkAttributeId = attributeId;
  }
}

void main() {
  late MockComputedAttributesRemoteDataSource mockDataSource;
  late ComputedAttributesRepositoryImpl repository;

  final tModel = const ComputedAttributeModel(
    id: 10,
    description: 'RPM Sensor',
    attribute: 'rpm',
    expression: 'can.rpm * 1.0',
    type: 'number',
  );

  setUp(() {
    mockDataSource = MockComputedAttributesRemoteDataSource();
    repository = ComputedAttributesRepositoryImpl(
      remoteDataSource: mockDataSource,
    );
  });

  group('ComputedAttributesRepositoryImpl Tests', () {
    test(
      'TC-CARI-01: getComputedAttributes returns Right with unmodifiable list',
      () async {
        mockDataSource.mockAttributes = [tModel];

        final result = await repository.getComputedAttributes();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Should succeed'), (items) {
          expect(items.length, equals(1));
          expect(items.first, equals(tModel));
          expect(() => items.add(tModel), throwsUnsupportedError);
        });
      },
    );

    test(
      'TC-CARI-02: createComputedAttribute returns Right with created model',
      () async {
        final created = tModel.copyWith(id: 101);
        mockDataSource.mockCreatedAttribute = created;

        final result = await repository.createComputedAttribute(tModel);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Should succeed'),
          (item) => expect(item.id, equals(101)),
        );
      },
    );

    test(
      'TC-CARI-03: updateComputedAttribute returns Right with updated model',
      () async {
        final updated = tModel.copyWith(description: 'Updated RPM');
        mockDataSource.mockUpdatedAttribute = updated;

        final result = await repository.updateComputedAttribute(tModel);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Should succeed'),
          (item) => expect(item.description, equals('Updated RPM')),
        );
      },
    );

    test('TC-CARI-04: deleteComputedAttribute returns Right(null)', () async {
      final result = await repository.deleteComputedAttribute(10);

      expect(result.isRight(), isTrue);
      expect(mockDataSource.deleteCalled, isTrue);
      expect(mockDataSource.lastDeletedId, equals(10));
    });

    test(
      'TC-CARI-05: testComputedAttribute returns Right with evaluation result',
      () async {
        final expectedResult = ComputedAttributeTestResultModel.success(
          value: 3500,
          type: 'number',
        );
        mockDataSource.mockTestResult = expectedResult;

        final result = await repository.testComputedAttribute(
          deviceId: 77,
          attribute: tModel,
        );

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Should succeed'), (res) {
          expect(res.rawValue, equals(3500));
          expect(res.stringValue, equals('3500'));
        });
      },
    );

    test(
      'TC-CARI-06: linkDeviceAttribute and unlinkDeviceAttribute return Right(null)',
      () async {
        final linkRes = await repository.linkDeviceAttribute(
          deviceId: 77,
          attributeId: 10,
        );
        expect(linkRes.isRight(), isTrue);
        expect(mockDataSource.lastLinkDeviceId, equals(77));
        expect(mockDataSource.lastLinkAttributeId, equals(10));

        final unlinkRes = await repository.unlinkDeviceAttribute(
          deviceId: 77,
          attributeId: 10,
        );
        expect(unlinkRes.isRight(), isTrue);
        expect(mockDataSource.lastUnlinkDeviceId, equals(77));
        expect(mockDataSource.lastUnlinkAttributeId, equals(10));
      },
    );

    test(
      'TC-CARI-07: linkGroupAttribute and unlinkGroupAttribute return Right(null)',
      () async {
        final linkRes = await repository.linkGroupAttribute(
          groupId: 3,
          attributeId: 10,
        );
        expect(linkRes.isRight(), isTrue);
        expect(mockDataSource.lastLinkGroupId, equals(3));
        expect(mockDataSource.lastLinkAttributeId, equals(10));

        final unlinkRes = await repository.unlinkGroupAttribute(
          groupId: 3,
          attributeId: 10,
        );
        expect(unlinkRes.isRight(), isTrue);
        expect(mockDataSource.lastUnlinkGroupId, equals(3));
        expect(mockDataSource.lastUnlinkAttributeId, equals(10));
      },
    );

    test('TC-CARI-08: Maps AuthException to Left(AuthFailure)', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Unauthorized',
        401,
      );

      final result = await repository.getComputedAttributes();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.statusCode, equals(401));
      }, (_) => fail('Should fail'));
    });

    test(
      'TC-CARI-09: Maps ForbiddenException to Left(ForbiddenFailure)',
      () async {
        mockDataSource.exceptionToThrow = const ForbiddenException(
          'Forbidden',
          403,
        );

        final result = await repository.createComputedAttribute(tModel);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ForbiddenFailure>());
          expect(failure.statusCode, equals(403));
        }, (_) => fail('Should fail'));
      },
    );

    test(
      'TC-CARI-10: Maps ConflictException to Left(ConflictFailure)',
      () async {
        mockDataSource.exceptionToThrow = const ConflictException(
          'Already exists',
          409,
        );

        final result = await repository.linkDeviceAttribute(
          deviceId: 77,
          attributeId: 10,
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ConflictFailure>());
          expect(failure.statusCode, equals(409));
        }, (_) => fail('Should fail'));
      },
    );

    test(
      'TC-CARI-11: Maps ConnectionTimeoutException to Left(TimeoutFailure)',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timeout',
        );

        final result = await repository.updateComputedAttribute(tModel);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<TimeoutFailure>()),
          (_) => fail('Should fail'),
        );
      },
    );

    test('TC-CARI-12: Maps NetworkException to Left(NetworkFailure)', () async {
      mockDataSource.exceptionToThrow = const NetworkException('No connection');

      final result = await repository.deleteComputedAttribute(10);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('TC-CARI-13: Maps ServerException to Left(ServerFailure)', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Server error',
        500,
      );

      final result = await repository.testComputedAttribute(
        deviceId: 77,
        attribute: tModel,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.statusCode, equals(500));
      }, (_) => fail('Should fail'));
    });

    test(
      'TC-CARI-14: Maps generic Exception to Left(UnexpectedFailure)',
      () async {
        mockDataSource.exceptionToThrow = Exception('Unknown bug');

        final result = await repository.getComputedAttributes();

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<UnexpectedFailure>()),
          (_) => fail('Should fail'),
        );
      },
    );
  });
}
