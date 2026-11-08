import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/domain/helpers/maintenance_progress_helper.dart';
import 'package:gpsku/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';

class MockMaintenanceRepository implements MaintenanceRepository {
  List<MaintenanceModel> mockMaintenances = [];
  Map<int, List<MaintenanceModel>> mockDeviceMaintenances = {};
  Failure? failureToReturn;
  int? lastDeletedId;
  final List<({int deviceId, int maintenanceId})> linkedHistory = [];
  final List<({int deviceId, int maintenanceId})> unlinkedHistory = [];

  @override
  Future<Either<Failure, List<MaintenanceModel>>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    if (deviceId != null) {
      return Right(mockDeviceMaintenances[deviceId] ?? []);
    }
    return Right(mockMaintenances);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final created = maintenance.copyWith(id: 999);
    mockMaintenances.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final index = mockMaintenances.indexWhere((m) => m.id == maintenance.id);
    if (index >= 0) {
      mockMaintenances[index] = maintenance;
    }
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockMaintenances.removeWhere((m) => m.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    linkedHistory.add((deviceId: deviceId, maintenanceId: maintenanceId));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    unlinkedHistory.add((deviceId: deviceId, maintenanceId: maintenanceId));
    return const Right(null);
  }
}

void main() {
  late MockMaintenanceRepository mockRepo;
  late MaintenanceProvider provider;

  const tMaintenance1 = MaintenanceModel(
    id: 1,
    name: 'Ganti Oli Mesin',
    type: 'totalDistance',
    start: 10000000.0, // 10,000 km
    period: 5000000.0, // 5,000 km
  );

  const tMaintenance2 = MaintenanceModel(
    id: 2,
    name: 'Servis Jam Operasional',
    type: 'hours',
    start: 360000000.0, // 100 h
    period: 180000000.0, // 50 h
  );

  const tMaintenance3 = MaintenanceModel(
    id: 3,
    name: 'Uji Kalender Pajak',
    type: 'serverTime',
    start: 8640000000.0, // 100 days
    period: 2592000000.0, // 30 days
  );

  setUp(() {
    mockRepo = MockMaintenanceRepository();
    mockRepo.mockMaintenances = [tMaintenance1, tMaintenance2, tMaintenance3];
    provider = MaintenanceProvider(repository: mockRepo);
  });

  group('MaintenanceProvider Unit Tests', () {
    test('TC-MP-01: Initial state is clean with defaults', () {
      final p = MaintenanceProvider(repository: mockRepo);
      expect(p.maintenances, isEmpty);
      expect(p.isLoading, isFalse);
      expect(p.errorMessage, isNull);
      expect(p.searchQuery, isEmpty);
      expect(p.selectedAlertFilter, equals('all'));
      expect(p.selectedMaintenance, isNull);
      expect(p.filteredMaintenances, isEmpty);
    });

    test(
      'TC-MP-02: fetchMaintenances success populates unmodifiable list',
      () async {
        await provider.fetchMaintenances();

        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
        expect(provider.maintenances.length, equals(3));
        expect(provider.maintenances.first.id, equals(1));
      },
    );

    test(
      'TC-MP-03: fetchMaintenances failure captures error message',
      () async {
        mockRepo.failureToReturn = const ServerFailure(
          'Koneksi database gagal',
        );

        await provider.fetchMaintenances();

        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, equals('Koneksi database gagal'));
        expect(provider.maintenances, isEmpty);
      },
    );

    test(
      'TC-MP-04: setSearchQuery updates query and filters by name or type',
      () async {
        await provider.fetchMaintenances();

        provider.setSearchQuery('oli');
        expect(provider.searchQuery, equals('oli'));
        expect(provider.filteredMaintenances.length, equals(1));
        expect(
          provider.filteredMaintenances.first.name,
          equals('Ganti Oli Mesin'),
        );

        provider.setSearchQuery('hours');
        expect(provider.filteredMaintenances.length, equals(1));
        expect(provider.filteredMaintenances.first.id, equals(2));

        provider.setSearchQuery('tidak-ada-yang-cocok');
        expect(provider.filteredMaintenances, isEmpty);

        provider.setSearchQuery('');
        expect(provider.filteredMaintenances.length, equals(3));
      },
    );

    test('TC-MP-05: selectMaintenance updates selection', () async {
      await provider.fetchMaintenances();

      provider.selectMaintenance(tMaintenance1);
      expect(provider.selectedMaintenance, equals(tMaintenance1));

      provider.selectMaintenance(null);
      expect(provider.selectedMaintenance, isNull);
    });

    test('TC-MP-06: createMaintenance appends created model', () async {
      await provider.fetchMaintenances();

      const newM = MaintenanceModel(
        id: 0,
        name: 'Ganti Filter Solar',
        type: 'totalDistance',
        start: 0,
        period: 10000000,
      );

      final success = await provider.createMaintenance(newM);

      expect(success, isTrue);
      expect(provider.maintenances.length, equals(4));
      expect(provider.maintenances.last.id, equals(999));
      expect(provider.maintenances.last.name, equals('Ganti Filter Solar'));
    });

    test(
      'TC-MP-07: updateMaintenance replaces existing model in collection',
      () async {
        await provider.fetchMaintenances();
        provider.selectMaintenance(tMaintenance1);

        final updated = tMaintenance1.copyWith(
          name: 'Ganti Oli Mesin Sintetis',
        );
        final success = await provider.updateMaintenance(updated);

        expect(success, isTrue);
        expect(
          provider.maintenances.firstWhere((m) => m.id == 1).name,
          equals('Ganti Oli Mesin Sintetis'),
        );
        expect(
          provider.selectedMaintenance?.name,
          equals('Ganti Oli Mesin Sintetis'),
        );
      },
    );

    test(
      'TC-MP-08: deleteMaintenance removes model and cleans up selection',
      () async {
        await provider.fetchMaintenances();
        provider.selectMaintenance(tMaintenance2);

        final success = await provider.deleteMaintenance(2);

        expect(success, isTrue);
        expect(mockRepo.lastDeletedId, equals(2));
        expect(provider.maintenances.any((m) => m.id == 2), isFalse);
        expect(provider.selectedMaintenance, isNull);
      },
    );

    test(
      'TC-MP-09: resetMaintenance updates start value to new baseline',
      () async {
        await provider.fetchMaintenances();

        // Reset with explicit value
        final success = await provider.resetMaintenance(
          tMaintenance1,
          newStartValue: 12000000.0,
        );

        expect(success, isTrue);
        expect(
          provider.maintenances.firstWhere((m) => m.id == 1).start,
          equals(12000000.0),
        );
      },
    );

    test(
      'TC-MP-10: fetchMaintenanceForDevice and getMaintenanceForDevice manage device link mapping',
      () async {
        mockRepo.mockDeviceMaintenances[10] = [tMaintenance1, tMaintenance2];

        await provider.fetchMaintenanceForDevice(10);

        final deviceMaints = provider.getMaintenanceForDevice(10);
        expect(deviceMaints.length, equals(2));
        expect(deviceMaints.map((m) => m.id), containsAll([1, 2]));

        // Unknown device returns empty list
        expect(provider.getMaintenanceForDevice(999), isEmpty);
      },
    );

    test(
      'TC-MP-11: evaluateDeviceAlertLevel detects normal, warning, and overdue correctly',
      () async {
        await provider.fetchMaintenances();
        provider.setDeviceMaintenanceLinks(
          10,
          [1],
        ); // tMaintenance1: start 10,000 km, period 5,000 km (due at 15,000 km)

        // 1. Normal (< 90% -> current < 14,500 km)
        final posNormal = PositionModel(
          id: 1,
          deviceId: 10,
          protocol: 'osmand',
          serverTime: DateTime.now(),
          deviceTime: DateTime.now(),
          fixTime: DateTime.now(),
          valid: true,
          latitude: -6.2,
          longitude: 106.8,
          altitude: 10,
          speed: 10,
          course: 0,
          attributes: {'totalDistance': 12000000.0}, // 12,000 km -> 40% ratio
        );
        expect(
          provider.evaluateDeviceAlertLevel(10, posNormal),
          equals(MaintenanceAlertLevel.normal),
        );

        // 2. Warning (>= 90% and < 100% -> 14,500 km to 14,999 km)
        final posWarning = posNormal.copyWith(
          attributes: {'totalDistance': 14600000.0}, // 14,600 km -> 92% ratio
        );
        expect(
          provider.evaluateDeviceAlertLevel(10, posWarning),
          equals(MaintenanceAlertLevel.warning),
        );

        // 3. Overdue (>= 15,000 km)
        final posOverdue = posNormal.copyWith(
          attributes: {'totalDistance': 15100000.0}, // 15,100 km -> 102% ratio
        );
        expect(
          provider.evaluateDeviceAlertLevel(10, posOverdue),
          equals(MaintenanceAlertLevel.overdue),
        );
      },
    );

    test(
      'TC-MP-12: setAlertFilter filters items based on evaluated alert severity',
      () async {
        await provider.fetchMaintenances();

        // Device 10 is overdue on item 1 (totalDistance: 15,100 km, due at 15,000 km)
        provider.setDeviceMaintenanceLinks(10, [1]);
        provider.updateDevicePosition(
          10,
          PositionModel(
            id: 1,
            deviceId: 10,
            protocol: 'osmand',
            serverTime: DateTime.now(),
            deviceTime: DateTime.now(),
            fixTime: DateTime.now(),
            valid: true,
            latitude: -6.2,
            longitude: 106.8,
            altitude: 0,
            speed: 0,
            course: 0,
            attributes: {'totalDistance': 16000000.0},
          ),
        );

        // Device 20 is normal on item 2
        provider.setDeviceMaintenanceLinks(20, [2]);

        provider.setAlertFilter('overdue');
        expect(provider.filteredMaintenances.length, equals(1));
        expect(provider.filteredMaintenances.first.id, equals(1));

        provider.setAlertFilter('normal');
        expect(provider.filteredMaintenances.any((m) => m.id == 1), isFalse);

        provider.setAlertFilter('all');
        expect(provider.filteredMaintenances.length, equals(3));
      },
    );

    test(
      'TC-MP-13: getLinkedDeviceIdsForMaintenance identifies assigned candidate devices',
      () async {
        mockRepo.mockDeviceMaintenances[101] = [tMaintenance1];
        mockRepo.mockDeviceMaintenances[102] = [tMaintenance2];
        mockRepo.mockDeviceMaintenances[103] = [tMaintenance1, tMaintenance2];

        final linked = await provider.getLinkedDeviceIdsForMaintenance(1, [
          101,
          102,
          103,
        ]);

        expect(linked, equals([101, 103]));
      },
    );

    test(
      'TC-MP-14: updateDeviceAssignments diffs and links/unlinks devices',
      () async {
        final success = await provider.updateDeviceAssignments(
          maintenanceId: 1,
          selectedDeviceIds: [101, 103],
          initialDeviceIds: [101, 102],
        );

        expect(success, isTrue);
        // Device 103 was linked
        expect(mockRepo.linkedHistory.length, equals(1));
        expect(mockRepo.linkedHistory.first.deviceId, equals(103));
        expect(mockRepo.linkedHistory.first.maintenanceId, equals(1));

        // Device 102 was unlinked
        expect(mockRepo.unlinkedHistory.length, equals(1));
        expect(mockRepo.unlinkedHistory.first.deviceId, equals(102));
        expect(mockRepo.unlinkedHistory.first.maintenanceId, equals(1));
      },
    );

    test(
      'TC-MP-15: clearMaintenance completely resets provider state',
      () async {
        await provider.fetchMaintenances();
        provider.selectMaintenance(tMaintenance1);
        provider.setSearchQuery('test');
        provider.setAlertFilter('overdue');

        provider.clearMaintenance();

        expect(provider.maintenances, isEmpty);
        expect(provider.selectedMaintenance, isNull);
        expect(provider.searchQuery, isEmpty);
        expect(provider.selectedAlertFilter, equals('all'));
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
      },
    );
  });
}
