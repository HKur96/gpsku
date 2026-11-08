import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/drivers/data/datasources/drivers_remote_data_source.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/data/repositories/drivers_repository_impl.dart';

class MockDriversRemoteDataSource implements DriversRemoteDataSource {
  List<DriverModel> mockDrivers = [];
  DriverModel? lastCreated;
  DriverModel? lastUpdated;
  int? lastDeletedId;
  int? lastLinkedDeviceId;
  int? lastLinkedDriverId;
  int? lastUnlinkedDeviceId;
  int? lastUnlinkedDriverId;
  Exception? exceptionToThrow;

  @override
  Future<List<DriverModel>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockDrivers;
  }

  @override
  Future<DriverModel> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastCreated = driver.copyWith(id: 77);
    return lastCreated!;
  }

  @override
  Future<DriverModel> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastUpdated = driver;
    return driver;
  }

  @override
  Future<void> deleteDriver(int id, {CancelToken? cancelToken}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastDeletedId = id;
  }

  @override
  Future<void> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastLinkedDeviceId = deviceId;
    lastLinkedDriverId = driverId;
  }

  @override
  Future<void> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastUnlinkedDeviceId = deviceId;
    lastUnlinkedDriverId = driverId;
  }
}

void main() {
  late MockDriversRemoteDataSource mockDataSource;
  late DriversRepositoryImpl repository;

  const tDriver = DriverModel(
    id: 1,
    name: 'Budi Santoso',
    uniqueId: 'RFID-123',
    attributes: {'phone': '08123456789'},
  );

  setUp(() {
    mockDataSource = MockDriversRemoteDataSource();
    repository = DriversRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('DriversRepositoryImpl Success Paths', () {
    test(
      'TC-DRI-01: getDrivers returns Right(unmodifiable list) on success',
      () async {
        mockDataSource.mockDrivers = [tDriver];

        final result = await repository.getDrivers();

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should succeed'), (drivers) {
          expect(drivers.length, equals(1));
          expect(drivers.first.name, equals('Budi Santoso'));
          expect(() => drivers.add(tDriver), throwsA(isA<UnsupportedError>()));
        });
      },
    );

    test(
      'TC-DRI-02: createDriver returns Right(createdDriver) on success',
      () async {
        final result = await repository.createDriver(tDriver);

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should succeed'), (created) {
          expect(created.id, equals(77));
          expect(created.name, equals('Budi Santoso'));
        });
      },
    );

    test(
      'TC-DRI-03: updateDriver returns Right(updatedDriver) on success',
      () async {
        final result = await repository.updateDriver(tDriver);

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Should succeed'),
          (updated) => expect(updated.id, equals(1)),
        );
      },
    );

    test('TC-DRI-04: deleteDriver returns Right(null) on success', () async {
      final result = await repository.deleteDriver(1);

      expect(result.isRight(), isTrue);
      expect(mockDataSource.lastDeletedId, equals(1));
    });

    test(
      'TC-DRI-05: linkDeviceDriver returns Right(null) on success',
      () async {
        final result = await repository.linkDeviceDriver(
          deviceId: 10,
          driverId: 1,
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastLinkedDeviceId, equals(10));
        expect(mockDataSource.lastLinkedDriverId, equals(1));
      },
    );

    test(
      'TC-DRI-06: unlinkDeviceDriver returns Right(null) on success',
      () async {
        final result = await repository.unlinkDeviceDriver(
          deviceId: 10,
          driverId: 1,
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastUnlinkedDeviceId, equals(10));
        expect(mockDataSource.lastUnlinkedDriverId, equals(1));
      },
    );
  });

  group('DriversRepositoryImpl Failure Mappings', () {
    test('TC-DRI-07: Maps AuthException to AuthFailure', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Session expired',
        401,
      );

      final result = await repository.getDrivers();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.message, equals('Session expired'));
      }, (_) => fail('Should fail'));
    });

    test('TC-DRI-08: Maps ForbiddenException to ForbiddenFailure', () async {
      mockDataSource.exceptionToThrow = const ForbiddenException('Denied', 403);

      final result = await repository.createDriver(tDriver);

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ForbiddenFailure>());
        expect(failure.message, equals('Denied'));
      }, (_) => fail('Should fail'));
    });

    test(
      'TC-DRI-09: Maps ConnectionTimeoutException to TimeoutFailure',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timed out',
          408,
        );

        final result = await repository.updateDriver(tDriver);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<TimeoutFailure>());
          expect(failure.message, equals('Timed out'));
        }, (_) => fail('Should fail'));
      },
    );

    test('TC-DRI-10: Maps NetworkException to NetworkFailure', () async {
      mockDataSource.exceptionToThrow = const NetworkException('No connection');

      final result = await repository.deleteDriver(1);

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<NetworkFailure>());
        expect(failure.message, equals('No connection'));
      }, (_) => fail('Should fail'));
    });

    test('TC-DRI-11: Maps ServerException to ServerFailure', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Database failure',
        500,
      );

      final result = await repository.linkDeviceDriver(
        deviceId: 10,
        driverId: 1,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.message, equals('Database failure'));
      }, (_) => fail('Should fail'));
    });

    test(
      'TC-DRI-12: Maps unexpected generic exception to UnexpectedFailure',
      () async {
        mockDataSource.exceptionToThrow = Exception('Corrupted memory state');

        final result = await repository.unlinkDeviceDriver(
          deviceId: 10,
          driverId: 1,
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<UnexpectedFailure>());
          expect(failure.message, contains('Corrupted memory state'));
        }, (_) => fail('Should fail'));
      },
    );
  });
}
