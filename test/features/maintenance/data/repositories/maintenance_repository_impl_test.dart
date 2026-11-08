import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/data/repositories/maintenance_repository_impl.dart';

class MockMaintenanceRemoteDataSource implements MaintenanceRemoteDataSource {
  List<MaintenanceModel> mockListResult = [];
  MaintenanceModel? mockSingleResult;
  Exception? exceptionToThrow;

  bool getMaintenancesCalled = false;
  bool createMaintenanceCalled = false;
  bool updateMaintenanceCalled = false;
  bool deleteMaintenanceCalled = false;
  bool linkCalled = false;
  bool unlinkCalled = false;

  int? lastDeletedId;
  int? lastLinkedDeviceId;
  int? lastLinkedMaintenanceId;
  int? lastUnlinkedDeviceId;
  int? lastUnlinkedMaintenanceId;

  @override
  Future<List<MaintenanceModel>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    getMaintenancesCalled = true;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockListResult;
  }

  @override
  Future<MaintenanceModel> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    createMaintenanceCalled = true;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSingleResult ?? maintenance.copyWith(id: 999);
  }

  @override
  Future<MaintenanceModel> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    updateMaintenanceCalled = true;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSingleResult ?? maintenance;
  }

  @override
  Future<void> deleteMaintenance(int id, {CancelToken? cancelToken}) async {
    deleteMaintenanceCalled = true;
    lastDeletedId = id;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    linkCalled = true;
    lastLinkedDeviceId = deviceId;
    lastLinkedMaintenanceId = maintenanceId;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    unlinkCalled = true;
    lastUnlinkedDeviceId = deviceId;
    lastUnlinkedMaintenanceId = maintenanceId;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }
}

void main() {
  group('MaintenanceRepositoryImpl Tests', () {
    late MockMaintenanceRemoteDataSource mockDataSource;
    late MaintenanceRepositoryImpl repository;

    final tMaintenance = const MaintenanceModel(
      id: 301,
      name: 'Rotasi Ban',
      type: 'totalDistance',
      start: 10000000.0,
      period: 10000000.0,
    );

    setUp(() {
      mockDataSource = MockMaintenanceRemoteDataSource();
      repository = MaintenanceRepositoryImpl(remoteDataSource: mockDataSource);
    });

    test(
      'TC-MRI-01: getMaintenances returns Right(unmodifiable list) on success',
      () async {
        mockDataSource.mockListResult = [tMaintenance];

        final result = await repository.getMaintenances();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Should succeed'), (items) {
          expect(items.length, equals(1));
          expect(items.first.id, equals(301));
          expect(() => items.add(tMaintenance), throwsUnsupportedError);
        });
      },
    );

    test(
      'TC-MRI-02: createMaintenance returns Right(created) on success',
      () async {
        mockDataSource.mockSingleResult = tMaintenance;

        final result = await repository.createMaintenance(tMaintenance);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Should succeed'),
          (created) => expect(created.id, equals(301)),
        );
      },
    );

    test(
      'TC-MRI-03: updateMaintenance returns Right(updated) on success',
      () async {
        mockDataSource.mockSingleResult = tMaintenance;

        final result = await repository.updateMaintenance(tMaintenance);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Should succeed'),
          (updated) => expect(updated.id, equals(301)),
        );
      },
    );

    test(
      'TC-MRI-04: deleteMaintenance returns Right(null) on success',
      () async {
        final result = await repository.deleteMaintenance(301);

        expect(result.isRight(), isTrue);
        expect(mockDataSource.deleteMaintenanceCalled, isTrue);
        expect(mockDataSource.lastDeletedId, equals(301));
      },
    );

    test(
      'TC-MRI-05: linkDeviceMaintenance returns Right(null) on success',
      () async {
        final result = await repository.linkDeviceMaintenance(
          deviceId: 12,
          maintenanceId: 301,
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.linkCalled, isTrue);
        expect(mockDataSource.lastLinkedDeviceId, equals(12));
        expect(mockDataSource.lastLinkedMaintenanceId, equals(301));
      },
    );

    test(
      'TC-MRI-06: unlinkDeviceMaintenance returns Right(null) on success',
      () async {
        final result = await repository.unlinkDeviceMaintenance(
          deviceId: 12,
          maintenanceId: 301,
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.unlinkCalled, isTrue);
        expect(mockDataSource.lastUnlinkedDeviceId, equals(12));
        expect(mockDataSource.lastUnlinkedMaintenanceId, equals(301));
      },
    );

    test('TC-MRI-07: Maps AuthException to AuthFailure', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Unauthorized',
        401,
      );

      final result = await repository.getMaintenances();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.statusCode, equals(401));
      }, (_) => fail('Should fail'));
    });

    test('TC-MRI-08: Maps ForbiddenException to ForbiddenFailure', () async {
      mockDataSource.exceptionToThrow = const ForbiddenException(
        'Forbidden',
        403,
      );

      final result = await repository.createMaintenance(tMaintenance);

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ForbiddenFailure>());
        expect(failure.statusCode, equals(403));
      }, (_) => fail('Should fail'));
    });

    test(
      'TC-MRI-09: Maps ConnectionTimeoutException to TimeoutFailure',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timed out',
          408,
        );

        final result = await repository.updateMaintenance(tMaintenance);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<TimeoutFailure>());
          expect(failure.statusCode, equals(408));
        }, (_) => fail('Should fail'));
      },
    );

    test('TC-MRI-10: Maps NetworkException to NetworkFailure', () async {
      mockDataSource.exceptionToThrow = const NetworkException('Network down');

      final result = await repository.deleteMaintenance(301);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('TC-MRI-11: Maps ServerException to ServerFailure', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Server error',
        500,
      );

      final result = await repository.linkDeviceMaintenance(
        deviceId: 1,
        maintenanceId: 2,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.statusCode, equals(500));
      }, (_) => fail('Should fail'));
    });

    test('TC-MRI-12: Maps generic Exception to UnexpectedFailure', () async {
      mockDataSource.exceptionToThrow = FormatException('Bad JSON');

      final result = await repository.unlinkDeviceMaintenance(
        deviceId: 1,
        maintenanceId: 2,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<UnexpectedFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });
}
