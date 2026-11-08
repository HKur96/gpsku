import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/drivers/data/models/driver_model.dart';
import 'package:gpsku/features/drivers/domain/repositories/drivers_repository.dart';
import 'package:gpsku/features/drivers/presentation/providers/drivers_provider.dart';

class MockDriversRepository implements DriversRepository {
  List<DriverModel> mockDrivers = [];
  Map<int, List<DriverModel>> mockDeviceDrivers = {};
  Failure? failureToReturn;
  int? lastDeletedId;
  final List<({int deviceId, int driverId})> linkedHistory = [];
  final List<({int deviceId, int driverId})> unlinkedHistory = [];

  @override
  Future<Either<Failure, List<DriverModel>>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (deviceId != null) {
      return Right(mockDeviceDrivers[deviceId] ?? []);
    }
    return Right(mockDrivers);
  }

  @override
  Future<Either<Failure, DriverModel>> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final created = driver.copyWith(id: 888);
    mockDrivers.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, DriverModel>> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final idx = mockDrivers.indexWhere((d) => d.id == driver.id);
    if (idx >= 0) {
      mockDrivers[idx] = driver;
    }
    return Right(driver);
  }

  @override
  Future<Either<Failure, void>> deleteDriver(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockDrivers.removeWhere((d) => d.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    linkedHistory.add((deviceId: deviceId, driverId: driverId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    unlinkedHistory.add((deviceId: deviceId, driverId: driverId));
    return const Right(null);
  }
}

void main() {
  late MockDriversRepository mockRepo;
  late DriversProvider provider;

  const tDriver1 = DriverModel(
    id: 1,
    name: 'Budi Santoso',
    uniqueId: 'RFID-1001',
    attributes: {'phone': '08123456789', 'license': 'SIM-B2'},
  );
  const tDriver2 = DriverModel(
    id: 2,
    name: 'Agus Wijaya',
    uniqueId: 'IBUTTON-2002',
    attributes: {'phone': '08987654321', 'license': 'SIM-A'},
  );

  setUp(() {
    mockRepo = MockDriversRepository();
    provider = DriversProvider(repository: mockRepo);
  });

  group('DriversProvider Unit Tests', () {
    test('TC-DP-01: Initial state is clean and idle', () {
      expect(provider.drivers, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.searchQuery, isEmpty);
      expect(provider.selectedDriver, isNull);
      expect(provider.filteredDrivers, isEmpty);
    });

    test(
      'TC-DP-02: fetchDrivers populates drivers and sets unmodifiable collection',
      () async {
        mockRepo.mockDrivers = [tDriver1, tDriver2];

        await provider.fetchDrivers();

        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
        expect(provider.drivers.length, equals(2));
        expect(provider.drivers.first.name, equals('Budi Santoso'));
      },
    );

    test('TC-DP-03: fetchDrivers failure captures error message', () async {
      mockRepo.failureToReturn = const ServerFailure(
        'Koneksi database driver gagal',
      );

      await provider.fetchDrivers();

      expect(provider.isLoading, isFalse);
      expect(provider.drivers, isEmpty);
      expect(provider.errorMessage, contains('Koneksi database driver gagal'));
    });

    test('TC-DP-04: fetchDrivers with force=false skips re-fetch', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();

      // Change repo data without force
      mockRepo.mockDrivers = [tDriver1, tDriver2];
      await provider.fetchDrivers(force: false);

      expect(provider.drivers.length, equals(1));

      // With force=true, fetches new data
      await provider.fetchDrivers(force: true);
      expect(provider.drivers.length, equals(2));
    });

    test(
      'TC-DP-05: setSearchQuery filters drivers by name, uniqueId, phone, license',
      () async {
        mockRepo.mockDrivers = [tDriver1, tDriver2];
        await provider.fetchDrivers();

        // 1. By name
        provider.setSearchQuery('budi');
        expect(provider.filteredDrivers.length, equals(1));
        expect(provider.filteredDrivers.first.id, equals(1));

        // 2. By RFID
        provider.setSearchQuery('ibutton');
        expect(provider.filteredDrivers.length, equals(1));
        expect(provider.filteredDrivers.first.id, equals(2));

        // 3. By phone
        provider.setSearchQuery('08987');
        expect(provider.filteredDrivers.length, equals(1));
        expect(provider.filteredDrivers.first.id, equals(2));

        // 4. By license
        provider.setSearchQuery('sim-b2');
        expect(provider.filteredDrivers.length, equals(1));
        expect(provider.filteredDrivers.first.id, equals(1));

        // 5. Empty reset
        provider.setSearchQuery('');
        expect(provider.filteredDrivers.length, equals(2));
      },
    );

    test('TC-DP-06: selectDriver updates selectedDriver reference', () {
      expect(provider.selectedDriver, isNull);
      provider.selectDriver(tDriver1);
      expect(provider.selectedDriver, equals(tDriver1));
      provider.selectDriver(null);
      expect(provider.selectedDriver, isNull);
    });

    test('TC-DP-07: createDriver adds created driver to catalog', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();

      const newDriver = DriverModel(
        id: 0,
        name: 'Dedi Kusnandar',
        uniqueId: 'TAG-3003',
      );

      final created = await provider.createDriver(newDriver);

      expect(created, isNotNull);
      expect(created!.id, equals(888));
      expect(provider.drivers.length, equals(2));
      expect(provider.selectedDriver, equals(created));
      expect(provider.errorMessage, isNull);
    });

    test('TC-DP-08: createDriver failure sets errorMessage', () async {
      mockRepo.failureToReturn = const NetworkFailure('Timeout saat menambah');

      final created = await provider.createDriver(tDriver1);

      expect(created, isNull);
      expect(provider.errorMessage, contains('Timeout saat menambah'));
    });

    test('TC-DP-09: updateDriver modifies existing item', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();
      provider.selectDriver(tDriver1);

      final updatedModel = tDriver1.copyWith(name: 'Budi Santoso S.T.');
      final result = await provider.updateDriver(updatedModel);

      expect(result, isNotNull);
      expect(provider.drivers.first.name, equals('Budi Santoso S.T.'));
      expect(provider.selectedDriver?.name, equals('Budi Santoso S.T.'));
    });

    test('TC-DP-10: updateDriver failure sets errorMessage', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();
      mockRepo.failureToReturn = const ServerFailure('Update 500');

      final result = await provider.updateDriver(tDriver1.copyWith(name: 'X'));

      expect(result, isNull);
      expect(provider.errorMessage, contains('Update 500'));
    });

    test(
      'TC-DP-11: deleteDriver removes driver and clears selection',
      () async {
        mockRepo.mockDrivers = [tDriver1, tDriver2];
        await provider.fetchDrivers();
        provider.selectDriver(tDriver1);

        final success = await provider.deleteDriver(1);

        expect(success, isTrue);
        expect(provider.drivers.length, equals(1));
        expect(provider.drivers.first.id, equals(2));
        expect(provider.selectedDriver, isNull);
        expect(mockRepo.lastDeletedId, equals(1));
      },
    );

    test('TC-DP-12: deleteDriver failure preserves drivers list', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();
      mockRepo.failureToReturn = const ServerFailure('Cannot delete');

      final success = await provider.deleteDriver(1);

      expect(success, isFalse);
      expect(provider.drivers.length, equals(1));
      expect(provider.errorMessage, contains('Cannot delete'));
    });

    test(
      'TC-DP-13: resolveActiveDriver resolves driver from position',
      () async {
        mockRepo.mockDrivers = [tDriver1, tDriver2];
        await provider.fetchDrivers();

        final pos = PositionModel(
          id: 10,
          deviceId: 5,
          protocol: 'osmand',
          serverTime: DateTime.now(),
          deviceTime: DateTime.now(),
          fixTime: DateTime.now(),
          valid: true,
          latitude: -6.2,
          longitude: 106.8,
          altitude: 10,
          speed: 30,
          course: 90,
          attributes: {'driverUniqueId': 'RFID-1001'},
        );

        final resolved = provider.resolveActiveDriver(pos);
        expect(resolved, isNotNull);
        expect(resolved!.id, equals(1));
        expect(resolved.name, equals('Budi Santoso'));

        // Non-matching
        final posUnknown = pos.copyWith(
          attributes: {'driverUniqueId': 'UNKNOWN-TAG'},
        );
        expect(provider.resolveActiveDriver(posUnknown), isNull);
      },
    );

    test('TC-DP-14: getDriverByUniqueId finds driver by uniqueId', () async {
      mockRepo.mockDrivers = [tDriver1, tDriver2];
      await provider.fetchDrivers();

      final driver = provider.getDriverByUniqueId('ibutton-2002');
      expect(driver, isNotNull);
      expect(driver!.id, equals(2));
    });

    test(
      'TC-DP-15: fetchDriversForDevice caches device links and merges items',
      () async {
        mockRepo.mockDeviceDrivers[10] = [tDriver1];

        await provider.fetchDriversForDevice(10);

        final items = provider.getDriversForDevice(10);
        expect(items.length, equals(1));
        expect(items.first.id, equals(1));
        expect(provider.drivers.length, equals(1));
      },
    );

    test(
      'TC-DP-16: setDeviceDriverLinks overrides device driver mapping',
      () async {
        mockRepo.mockDrivers = [tDriver1, tDriver2];
        await provider.fetchDrivers();

        provider.setDeviceDriverLinks(42, [1, 2]);

        final items = provider.getDriversForDevice(42);
        expect(items.length, equals(2));
      },
    );

    test(
      'TC-DP-17: getLinkedDeviceIdsForDriver discovers linked candidates',
      () async {
        mockRepo.mockDeviceDrivers[100] = [tDriver1];
        mockRepo.mockDeviceDrivers[200] = [tDriver2];

        final linked = await provider.getLinkedDeviceIdsForDriver(1, [
          100,
          200,
        ]);

        expect(linked, equals([100]));
      },
    );

    test(
      'TC-DP-18: updateDeviceAssignments reconciles permissions diff accurately',
      () async {
        final success = await provider.updateDeviceAssignments(
          driverId: 1,
          selectedDeviceIds: [100, 300], // link 300
          initialDeviceIds: [100, 200], // unlink 200
        );

        expect(success, isTrue);
        expect(mockRepo.linkedHistory.length, equals(1));
        expect(
          mockRepo.linkedHistory.first,
          equals((deviceId: 300, driverId: 1)),
        );
        expect(mockRepo.unlinkedHistory.length, equals(1));
        expect(
          mockRepo.unlinkedHistory.first,
          equals((deviceId: 200, driverId: 1)),
        );
      },
    );

    test('TC-DP-19: clearDrivers resets all state to baseline', () async {
      mockRepo.mockDrivers = [tDriver1];
      await provider.fetchDrivers();
      provider.selectDriver(tDriver1);
      provider.setSearchQuery('test');

      provider.clearDrivers();

      expect(provider.drivers, isEmpty);
      expect(provider.selectedDriver, isNull);
      expect(provider.searchQuery, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });
}
