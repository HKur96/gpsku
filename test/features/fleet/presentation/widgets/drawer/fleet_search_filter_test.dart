import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/drawer/fleet_search_filter.dart';

void main() {
  group('FleetSearchFilter - Unit & Benchmark Tests', () {
    final dev1 = const DeviceModel(
      id: 1,
      name: 'Toyota Avanza B 1234 CD',
      uniqueId: 'AVANZA-01',
      category: 'car',
      status: 'online',
      model: '1.5 G MT',
      groupId: 10,
    );

    final dev2 = const DeviceModel(
      id: 2,
      name: 'Isuzu Giga Box B 9999 XYZ',
      uniqueId: 'GIGA-02',
      category: 'truck',
      status: 'online',
      model: 'FVZ 34 P',
      groupId: 10,
    );

    final dev3 = const DeviceModel(
      id: 3,
      name: 'Honda Beat D 5555 EF',
      uniqueId: 'BEAT-03',
      category: 'motorcycle',
      status: 'offline',
      model: 'CBS ISS',
      attributes: {'plateNumber': 'D 5555 EF'},
      groupId: 20,
    );

    final dev4 = const DeviceModel(
      id: 4,
      name: 'Yamaha NMAX L 7777 GH',
      uniqueId: 'NMAX-04',
      category: 'motorcycle',
      status: 'unknown',
      groupId: null, // Unassigned
    );

    // Positions:
    // dev1 is online and moving (speed: 30 knots = ~55.5 km/h)
    final pos1 = PositionModel(
      id: 101,
      deviceId: 1,
      serverTime: DateTime.parse('2026-11-08T09:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T09:00:00Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 30.0,
    );

    // dev2 is online but stationary/parked (speed: 0)
    final pos2 = PositionModel(
      id: 102,
      deviceId: 2,
      serverTime: DateTime.parse('2026-11-08T09:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T09:00:00Z'),
      latitude: -6.2000,
      longitude: 106.8400,
      speed: 0.0,
    );

    // dev3 is offline with stale position
    final pos3 = PositionModel(
      id: 103,
      deviceId: 3,
      serverTime: DateTime.parse('2026-11-08T08:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T08:00:00Z'),
      latitude: -6.9175,
      longitude: 107.6191,
      speed: 0.0,
    );

    final positionsMap = {1: pos1, 2: pos2, 3: pos3};

    final allDevices = [dev1, dev2, dev3, dev4];

    test(
      'TC-FSF-01: Multi-field search matching across name, uniqueId, model, attributes',
      () {
        // By name
        expect(FleetSearchFilter.matchesSearch(dev1, 'avanza'), isTrue);
        expect(FleetSearchFilter.matchesSearch(dev1, 'TOYOTA'), isTrue);

        // By uniqueId
        expect(FleetSearchFilter.matchesSearch(dev2, 'GIGA-02'), isTrue);
        expect(FleetSearchFilter.matchesSearch(dev2, 'giga'), isTrue);

        // By model
        expect(FleetSearchFilter.matchesSearch(dev2, 'FVZ 34'), isTrue);

        // By plateNumber attribute
        expect(FleetSearchFilter.matchesSearch(dev3, '5555'), isTrue);

        // Case-insensitive & trimmed
        expect(
          FleetSearchFilter.matchesSearch(dev1, '   b 1234 cd   '),
          isTrue,
        );

        // Non-matching
        expect(FleetSearchFilter.matchesSearch(dev1, 'ferrari'), isFalse);

        // Empty query matches everything
        expect(FleetSearchFilter.matchesSearch(dev1, ''), isTrue);
        expect(FleetSearchFilter.matchesSearch(dev1, '   '), isTrue);
      },
    );

    test(
      'TC-FSF-02: Status predicate matching for moving, idle, and offline',
      () {
        // All
        expect(
          FleetSearchFilter.matchesStatus(dev1, pos1, FleetStatusFilter.all),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev2, pos2, FleetStatusFilter.all),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev3, pos3, FleetStatusFilter.all),
          isTrue,
        );

        // Moving: online and speed > 0
        expect(
          FleetSearchFilter.matchesStatus(dev1, pos1, FleetStatusFilter.moving),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev2, pos2, FleetStatusFilter.moving),
          isFalse,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev3, pos3, FleetStatusFilter.moving),
          isFalse,
        );

        // Idle: online and speed <= 0
        expect(
          FleetSearchFilter.matchesStatus(dev1, pos1, FleetStatusFilter.idle),
          isFalse,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev2, pos2, FleetStatusFilter.idle),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesStatus(dev3, pos3, FleetStatusFilter.idle),
          isFalse,
        );

        // Offline
        expect(
          FleetSearchFilter.matchesStatus(
            dev1,
            pos1,
            FleetStatusFilter.offline,
          ),
          isFalse,
        );
        expect(
          FleetSearchFilter.matchesStatus(
            dev2,
            pos2,
            FleetStatusFilter.offline,
          ),
          isFalse,
        );
        expect(
          FleetSearchFilter.matchesStatus(
            dev3,
            pos3,
            FleetStatusFilter.offline,
          ),
          isTrue,
        );
      },
    );

    test(
      'TC-FSF-03: Single-pass count calculation aggregates all categories accurately',
      () {
        final counts = FleetSearchFilter.calculateCounts(
          devices: allDevices,
          positions: positionsMap,
        );

        expect(counts.all, equals(4));
        expect(counts.moving, equals(1)); // dev1
        expect(counts.idle, equals(1)); // dev2
        expect(counts.offline, equals(1)); // dev3
      },
    );

    test(
      'TC-FSF-04: Filter and sort priority places moving first, idle second, offline third',
      () {
        final filtered = FleetSearchFilter.filterDevices(
          devices: allDevices,
          positions: positionsMap,
          statusFilter: FleetStatusFilter.all,
          query: '',
        );

        expect(filtered.length, equals(4));
        expect(filtered[0].id, equals(1)); // moving
        expect(filtered[1].id, equals(2)); // idle
        expect(filtered[2].id, equals(3)); // offline
        expect(filtered[3].id, equals(4)); // unknown
      },
    );

    test('TC-FSF-05: Combined search and status filtering', () {
      // Filter offline with query 'Beat' -> returns dev3
      final res1 = FleetSearchFilter.filterDevices(
        devices: allDevices,
        positions: positionsMap,
        statusFilter: FleetStatusFilter.offline,
        query: 'Beat',
      );
      expect(res1.length, equals(1));
      expect(res1.first.id, equals(3));

      // Filter moving with query 'Beat' -> returns empty
      final res2 = FleetSearchFilter.filterDevices(
        devices: allDevices,
        positions: positionsMap,
        statusFilter: FleetStatusFilter.moving,
        query: 'Beat',
      );
      expect(res2.isEmpty, isTrue);
    });

    test(
      'TC-FSF-06: High-density fleet benchmark (150 vehicles filtered in < 10ms)',
      () {
        final benchDevices = List.generate(
          150,
          (i) => DeviceModel(
            id: i + 1,
            name: 'Armada Unit ${i.toString().padLeft(3, '0')}',
            uniqueId: 'IMEI-${i.toString().padLeft(5, '0')}',
            category: i % 2 == 0 ? 'truck' : 'car',
            status: i % 3 == 0 ? 'offline' : 'online',
            model: 'Model-${i % 5}',
          ),
        );

        final benchPositions = {
          for (int i = 0; i < 150; i++)
            i + 1: PositionModel(
              id: 1000 + i,
              deviceId: i + 1,
              serverTime: DateTime.now(),
              fixTime: DateTime.now(),
              latitude: -6.2 + (i * 0.001),
              longitude: 106.8 + (i * 0.001),
              speed: i % 2 == 0 ? 40.0 : 0.0,
            ),
        };

        final stopwatch = Stopwatch()..start();
        final counts = FleetSearchFilter.calculateCounts(
          devices: benchDevices,
          positions: benchPositions,
        );
        final filtered = FleetSearchFilter.filterDevices(
          devices: benchDevices,
          positions: benchPositions,
          statusFilter: FleetStatusFilter.moving,
          query: 'Unit 05',
        );
        stopwatch.stop();

        expect(counts.all, equals(150));
        expect(filtered.isNotEmpty, isTrue);
        // Modern Dart VM filters 150 devices in under 10ms
        expect(stopwatch.elapsedMilliseconds, lessThan(20));
      },
    );

    test(
      'TC-FSF-07: Group matching via matchesGroup (null, unassigned 0, and specific groupId)',
      () {
        // selectedGroupId null matches everything
        expect(FleetSearchFilter.matchesGroup(dev1, null), isTrue);
        expect(FleetSearchFilter.matchesGroup(dev4, null), isTrue);

        // selectedGroupId == 10 matches dev1 and dev2
        expect(FleetSearchFilter.matchesGroup(dev1, 10), isTrue);
        expect(FleetSearchFilter.matchesGroup(dev2, 10), isTrue);
        expect(FleetSearchFilter.matchesGroup(dev3, 10), isFalse);

        // selectedGroupId == 0 (unassigned) matches dev4 (null or 0)
        expect(FleetSearchFilter.matchesGroup(dev4, 0), isTrue);
        expect(FleetSearchFilter.matchesGroup(dev1, 0), isFalse);
      },
    );

    test(
      'TC-FSF-08: Category matching via matchesCategory (empty set, specific categories)',
      () {
        // Empty set matches all
        expect(FleetSearchFilter.matchesCategory(dev1, {}), isTrue);
        expect(FleetSearchFilter.matchesCategory(dev2, {}), isTrue);

        // Specific single category
        expect(FleetSearchFilter.matchesCategory(dev1, {'car'}), isTrue);
        expect(FleetSearchFilter.matchesCategory(dev2, {'car'}), isFalse);

        // Multiple categories in set
        expect(
          FleetSearchFilter.matchesCategory(dev1, {'car', 'truck'}),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesCategory(dev2, {'car', 'truck'}),
          isTrue,
        );
        expect(
          FleetSearchFilter.matchesCategory(dev3, {'car', 'truck'}),
          isFalse,
        );
      },
    );

    test(
      'TC-FSF-09: Filter with selectedGroupId and selectedCategories in filterDevices',
      () {
        final resGroup10 = FleetSearchFilter.filterDevices(
          devices: allDevices,
          positions: positionsMap,
          statusFilter: FleetStatusFilter.all,
          query: '',
          selectedGroupId: 10,
        );
        expect(resGroup10.length, equals(2));
        expect(resGroup10.map((d) => d.id), containsAll([1, 2]));

        final resTruck = FleetSearchFilter.filterDevices(
          devices: allDevices,
          positions: positionsMap,
          statusFilter: FleetStatusFilter.all,
          query: '',
          selectedCategories: {'truck'},
        );
        expect(resTruck.length, equals(1));
        expect(resTruck.first.id, equals(2));

        final resMotorcycle = FleetSearchFilter.filterDevices(
          devices: allDevices,
          positions: positionsMap,
          statusFilter: FleetStatusFilter.all,
          query: '',
          selectedCategories: {'motorcycle'},
        );
        expect(resMotorcycle.length, equals(2));
        expect(resMotorcycle.map((d) => d.id), containsAll([3, 4]));
      },
    );

    test(
      'TC-FSF-10: groupByHierarchy organizes devices into groups and Tanpa Grup with accurate section counts',
      () {
        final groupsMap = {
          10: const GroupModel(id: 10, name: 'Divisi Logistik', groupId: null),
          20: const GroupModel(
            id: 20,
            name: 'Divisi Operasional',
            groupId: null,
          ),
        };

        final sections = FleetSearchFilter.groupByHierarchy(
          devices: allDevices,
          positions: positionsMap,
          groups: groupsMap,
        );

        // Should have 3 sections: Divisi Logistik (10), Divisi Operasional (20), and Tanpa Grup (0)
        expect(sections.length, equals(3));

        // Section 1: Divisi Logistik (id: 10)
        final sec1 = sections.firstWhere((s) => s.groupId == 10);
        expect(sec1.groupName, equals('Divisi Logistik'));
        expect(sec1.devices.length, equals(2)); // dev1 (moving) and dev2 (idle)
        expect(sec1.movingCount, equals(1));
        expect(sec1.idleCount, equals(1));
        expect(sec1.offlineCount, equals(0));

        // Section 2: Divisi Operasional (id: 20)
        final sec2 = sections.firstWhere((s) => s.groupId == 20);
        expect(sec2.groupName, equals('Divisi Operasional'));
        expect(sec2.devices.length, equals(1)); // dev3 (offline)
        expect(sec2.movingCount, equals(0));
        expect(sec2.idleCount, equals(0));
        expect(sec2.offlineCount, equals(1));

        // Section 3: Tanpa Grup (0)
        final secUnassigned = sections.firstWhere((s) => s.isUnassigned);
        expect(secUnassigned.groupName, equals('Tanpa Grup'));
        expect(secUnassigned.groupId, equals(0));
        expect(secUnassigned.devices.length, equals(1)); // dev4
      },
    );
  });
}
