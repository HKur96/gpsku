import 'package:flutter/foundation.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';

/// Filter categories for fleet device status.
enum FleetStatusFilter { all, moving, idle, offline }

/// Aggregated counts of fleet devices partitioned by status filter.
@immutable
class FleetFilterCounts {
  final int all;
  final int moving;
  final int idle;
  final int offline;

  const FleetFilterCounts({
    this.all = 0,
    this.moving = 0,
    this.idle = 0,
    this.offline = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FleetFilterCounts &&
          runtimeType == other.runtimeType &&
          all == other.all &&
          moving == other.moving &&
          idle == other.idle &&
          offline == other.offline;

  @override
  int get hashCode => Object.hash(all, moving, idle, offline);

  @override
  String toString() =>
      'FleetFilterCounts(all: $all, moving: $moving, idle: $idle, offline: $offline)';
}

/// Representation of a grouped section of vehicles in the fleet drawer.
@immutable
class FleetGroupSection {
  final int groupId; // 0 for Unassigned / Tanpa Grup
  final String groupName;
  final List<DeviceModel> devices;
  final int totalCount;
  final int movingCount;
  final int idleCount;
  final int offlineCount;

  const FleetGroupSection({
    required this.groupId,
    required this.groupName,
    required this.devices,
    this.totalCount = 0,
    this.movingCount = 0,
    this.idleCount = 0,
    this.offlineCount = 0,
  });

  bool get isUnassigned => groupId == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FleetGroupSection &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          totalCount == other.totalCount &&
          movingCount == other.movingCount &&
          idleCount == other.idleCount &&
          offlineCount == other.offlineCount &&
          listEquals(devices, other.devices);

  @override
  int get hashCode => Object.hash(
    groupId,
    groupName,
    totalCount,
    movingCount,
    idleCount,
    offlineCount,
    Object.hashAll(devices),
  );

  @override
  String toString() =>
      'FleetGroupSection(id: $groupId, name: $groupName, count: $totalCount)';
}

/// Pure presentation helper for high-performance searching, status filtering,
/// grouping hierarchies, and multi-category vehicle filtering.
class FleetSearchFilter {
  const FleetSearchFilter._();

  /// Determines if a device matches the status filter given its current position.
  static bool matchesStatus(
    DeviceModel device,
    PositionModel? position,
    FleetStatusFilter filter,
  ) {
    final status = device.status.toLowerCase();
    switch (filter) {
      case FleetStatusFilter.all:
        return true;
      case FleetStatusFilter.moving:
        // Moving: device is online and speed > 0
        return status == 'online' && position != null && position.speed > 0;
      case FleetStatusFilter.idle:
        // Idle/Parkir: device is online and either has no position or speed <= 0
        return status == 'online' && (position == null || position.speed <= 0);
      case FleetStatusFilter.offline:
        return status == 'offline';
    }
  }

  /// Determines if a device matches the selected group criterion.
  /// Null matches all groups; 0 matches unassigned devices (groupId == null or 0).
  static bool matchesGroup(DeviceModel device, int? selectedGroupId) {
    if (selectedGroupId == null) return true;
    if (selectedGroupId == 0) {
      return device.groupId == null || device.groupId == 0;
    }
    return device.groupId == selectedGroupId;
  }

  /// Determines if a device matches the selected categories set.
  /// Empty set matches all categories.
  static bool matchesCategory(
    DeviceModel device,
    Set<String> selectedCategories,
  ) {
    if (selectedCategories.isEmpty) return true;
    final cat = device.category?.toLowerCase() ?? 'default';
    return selectedCategories.contains(cat);
  }

  /// Determines if a device matches a case-insensitive multi-field search query.
  /// Searches across name, uniqueId, model, contact, and plateNumber attribute.
  static bool matchesSearch(DeviceModel device, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return true;

    if (device.name.toLowerCase().contains(trimmed)) return true;
    if (device.uniqueId.toLowerCase().contains(trimmed)) return true;
    if (device.model?.toLowerCase().contains(trimmed) == true) return true;
    if (device.contact?.toLowerCase().contains(trimmed) == true) return true;

    final plate = device.attributes['plateNumber']?.toString().toLowerCase();
    if (plate != null && plate.contains(trimmed)) return true;

    return false;
  }

  /// Single-pass O(N) calculation of status counts for high efficiency (100+ vehicles in <0.1ms).
  static FleetFilterCounts calculateCounts({
    required Iterable<DeviceModel> devices,
    required Map<int, PositionModel> positions,
  }) {
    int all = 0;
    int moving = 0;
    int idle = 0;
    int offline = 0;

    for (final device in devices) {
      all++;
      final pos = positions[device.id];
      final status = device.status.toLowerCase();
      if (status == 'online') {
        if (pos != null && pos.speed > 0) {
          moving++;
        } else {
          idle++;
        }
      } else if (status == 'offline') {
        offline++;
      }
    }

    return FleetFilterCounts(
      all: all,
      moving: moving,
      idle: idle,
      offline: offline,
    );
  }

  /// Filters and sorts the list of devices based on status, group, category, and search query.
  /// Sorts active/moving devices first, followed by idle, then offline, then alphabetically by name.
  static List<DeviceModel> filterDevices({
    required Iterable<DeviceModel> devices,
    required Map<int, PositionModel> positions,
    required FleetStatusFilter statusFilter,
    required String query,
    int? selectedGroupId,
    Set<String> selectedCategories = const {},
  }) {
    final filtered = <DeviceModel>[];
    for (final device in devices) {
      final pos = positions[device.id];
      if (matchesStatus(device, pos, statusFilter) &&
          matchesGroup(device, selectedGroupId) &&
          matchesCategory(device, selectedCategories) &&
          matchesSearch(device, query)) {
        filtered.add(device);
      }
    }

    // Deterministic sorting:
    // Priority:
    // 0: Online & Moving
    // 1: Online & Idle
    // 2: Offline
    // 3: Unknown / Other
    // Tie-breaker: Name (alphabetical)
    filtered.sort((a, b) {
      final aPos = positions[a.id];
      final bPos = positions[b.id];
      final aRank = _devicePriorityRank(a, aPos);
      final bRank = _devicePriorityRank(b, bPos);

      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  /// Groups the filtered devices into [FleetGroupSection]s mapping [DeviceModel.groupId]
  /// to group names from [groups], grouping unassigned devices under groupId 0 ("Tanpa Grup").
  static List<FleetGroupSection> groupByHierarchy({
    required List<DeviceModel> devices,
    required Map<int, PositionModel> positions,
    required Map<int, GroupModel> groups,
  }) {
    final Map<int, List<DeviceModel>> groupedMap = {};

    for (final device in devices) {
      final rawGid = device.groupId;
      final gid = (rawGid != null && rawGid > 0) ? rawGid : 0;
      groupedMap.putIfAbsent(gid, () => []).add(device);
    }

    final sections = <FleetGroupSection>[];

    for (final entry in groupedMap.entries) {
      final gid = entry.key;
      final devList = entry.value;

      final String groupName;
      if (gid == 0) {
        groupName = 'Tanpa Grup';
      } else {
        groupName = groups[gid]?.name ?? 'Grup #$gid';
      }

      int moving = 0;
      int idle = 0;
      int offline = 0;

      for (final dev in devList) {
        final pos = positions[dev.id];
        final status = dev.status.toLowerCase();
        if (status == 'online') {
          if (pos != null && pos.speed > 0) {
            moving++;
          } else {
            idle++;
          }
        } else if (status == 'offline') {
          offline++;
        }
      }

      sections.add(
        FleetGroupSection(
          groupId: gid,
          groupName: groupName,
          devices: devList,
          totalCount: devList.length,
          movingCount: moving,
          idleCount: idle,
          offlineCount: offline,
        ),
      );
    }

    // Sort sections: Named groups first (alphabetical), Tanpa Grup (0) always at the bottom
    sections.sort((a, b) {
      if (a.groupId == 0 && b.groupId != 0) return 1;
      if (a.groupId != 0 && b.groupId == 0) return -1;
      return a.groupName.toLowerCase().compareTo(b.groupName.toLowerCase());
    });

    return sections;
  }

  static int _devicePriorityRank(DeviceModel device, PositionModel? position) {
    final status = device.status.toLowerCase();
    if (status == 'online') {
      if (position != null && position.speed > 0) {
        return 0; // Moving
      }
      return 1; // Idle
    } else if (status == 'offline') {
      return 2; // Offline
    }
    return 3; // Unknown
  }
}
