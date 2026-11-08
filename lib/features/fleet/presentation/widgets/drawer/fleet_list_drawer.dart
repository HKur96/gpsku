import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'fleet_list_item.dart';
import 'fleet_search_filter.dart';

/// Responsive fleet list drawer and sliding panel (SCR-MAP-01 / SCR-FLT-01).
///
/// Features:
/// - Instant multi-field searching with 200ms input debouncing.
/// - Status filtering (Semua, Bergerak, Diam, Offline).
/// - Category filtering (Semua, Mobil, Truk, Motor, Bus, dll.).
/// - Operational group hierarchies with collapsible section headers.
/// - Two-way map synchronization with southward camera offset.
class FleetListDrawer extends StatefulWidget {
  final void Function(DeviceModel device, PositionModel? position)?
  onDeviceSelected;
  final VoidCallback? onClosePressed;

  const FleetListDrawer({
    super.key,
    this.onDeviceSelected,
    this.onClosePressed,
  });

  @override
  State<FleetListDrawer> createState() => _FleetListDrawerState();
}

class _FleetListDrawerState extends State<FleetListDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  FleetStatusFilter _selectedFilter = FleetStatusFilter.all;
  String? _selectedCategory; // null = all
  int? _selectedGroupId; // null = all
  String _searchQuery = '';
  bool _hasInitialScrolled = false;

  final Set<int> _collapsedGroupIds = {};

  static const List<({String? key, String label, IconData icon})> _categories =
      [
        (key: null, label: 'Semua Kategori', icon: Icons.all_inclusive),
        (key: 'car', label: 'Mobil', icon: Icons.directions_car),
        (key: 'truck', label: 'Truk', icon: Icons.local_shipping),
        (key: 'motorcycle', label: 'Motor', icon: Icons.two_wheeler),
        (key: 'bus', label: 'Bus', icon: Icons.directions_bus),
        (key: 'pickup', label: 'Pickup', icon: Icons.agriculture),
        (key: 'van', label: 'Van', icon: Icons.airport_shuttle),
      ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        final text = _searchController.text;
        if (text != _searchQuery) {
          setState(() {
            _searchQuery = text;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDevice(
    List<DeviceModel> filteredList,
    int? selectedId,
  ) {
    if (_hasInitialScrolled || selectedId == null || filteredList.isEmpty) {
      return;
    }

    final index = filteredList.indexWhere((d) => d.id == selectedId);
    if (index >= 0) {
      _hasInitialScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetOffset = (index * 76.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fleet = context.watch<LiveFleetProvider>();

    final devices = fleet.devices.values;
    final positions = fleet.positions;
    final groups = fleet.groups;
    final selectedDeviceId = fleet.selectedDeviceId;

    // Calculate real-time counts across the full fleet
    final counts = FleetSearchFilter.calculateCounts(
      devices: devices,
      positions: positions,
    );

    // Filter and sort according to current active filters & debounced query
    final filteredDevices = FleetSearchFilter.filterDevices(
      devices: devices,
      positions: positions,
      statusFilter: _selectedFilter,
      query: _searchQuery,
      selectedGroupId: _selectedGroupId,
      selectedCategories: _selectedCategory != null
          ? {_selectedCategory!}
          : const {},
    );

    // Grouping by hierarchy
    final groupSections = groups.isNotEmpty
        ? FleetSearchFilter.groupByHierarchy(
            devices: filteredDevices,
            positions: positions,
            groups: groups,
          )
        : const <FleetGroupSection>[];

    // Attempt auto-scroll to selected device on initial mount
    if (!_hasInitialScrolled && selectedDeviceId != null) {
      _scrollToSelectedDevice(filteredDevices, selectedDeviceId);
    }

    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Title, Count Badge, and Close Button
            _buildHeader(context, counts.all),

            // 2. Search Toolbar Input (with 200ms debounce)
            _buildSearchInput(context),

            // 3. Status Filter Chips Row
            _buildFilterChips(context, counts),

            // 4. Category Filter Chips Row
            _buildCategoryFilterRow(context),

            const SizedBox(height: 4),

            // 5. List Content with Hierarchical Grouping or Empty State
            Expanded(
              child: _buildListContent(
                context,
                filteredDevices: filteredDevices,
                groupSections: groupSections,
                positions: positions,
                selectedDeviceId: selectedDeviceId,
                totalCount: counts.all,
                hasGroups: groups.isNotEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 8.0),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: Color(0xFF2563EB), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Daftar Armada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount Unit',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Tutup',
            onPressed: () {
              if (widget.onClosePressed != null) {
                widget.onClosePressed!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Cari plat nomor, nama armada, IMEI...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Hapus Pencarian',
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          isDense: true,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, FleetFilterCounts counts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
      child: Row(
        children: [
          _buildChip(
            label: 'Semua (${counts.all})',
            filter: FleetStatusFilter.all,
            dotColor: null,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Bergerak (${counts.moving})',
            filter: FleetStatusFilter.moving,
            dotColor: const Color(0xFF10B981), // Emerald
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Diam (${counts.idle})',
            filter: FleetStatusFilter.idle,
            dotColor: const Color(0xFFF59E0B), // Amber
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Offline (${counts.offline})',
            filter: FleetStatusFilter.offline,
            dotColor: const Color(0xFFEF4444), // Red
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: FilterChip(
              avatar: Icon(
                cat.icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              label: Text(
                cat.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E88E5),
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E88E5)
                      : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? cat.key : null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required FleetStatusFilter filter,
    required Color? dotColor,
  }) {
    final isSelected = _selectedFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
    );
  }

  Widget _buildListContent(
    BuildContext context, {
    required List<DeviceModel> filteredDevices,
    required List<FleetGroupSection> groupSections,
    required Map<int, PositionModel> positions,
    required int? selectedDeviceId,
    required int totalCount,
    required bool hasGroups,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Empty fleet state (no devices accessible at all)
    if (totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 56,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Armada Terdaftar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Menunggu sinkronisasi data armada dari server...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No search / filter results state
    if (filteredDevices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak Ada Armada yang Sesuai',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              if (_searchQuery.isNotEmpty)
                Text(
                  'Tidak ditemukan hasil untuk "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset Filter'),
                onPressed: () {
                  setState(() {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedFilter = FleetStatusFilter.all;
                    _selectedCategory = null;
                    _selectedGroupId = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    // Render Hierarchical Group Sections when groups are present
    if (hasGroups && groupSections.isNotEmpty) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16.0),
        itemCount: groupSections.length,
        itemBuilder: (context, sectionIdx) {
          final section = groupSections[sectionIdx];
          final isCollapsed = _collapsedGroupIds.contains(section.groupId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Collapsible Group Header
              InkWell(
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedGroupIds.remove(section.groupId);
                    } else {
                      _collapsedGroupIds.add(section.groupId);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                      : const Color(0xFFF1F5F9),
                  child: Row(
                    children: [
                      Icon(
                        section.isUnassigned ? Icons.folder_open : Icons.folder,
                        size: 18,
                        color: section.isUnassigned
                            ? Colors.grey[500]
                            : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          section.groupName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${section.totalCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),

              // Group Items (rendered when expanded)
              if (!isCollapsed)
                ...section.devices.map((device) {
                  final position = positions[device.id];
                  final isSelected = device.id == selectedDeviceId;

                  return FleetListItem(
                    device: device,
                    position: position,
                    isSelected: isSelected,
                    onTap: () => _handleItemTap(device, position),
                  );
                }),
            ],
          );
        },
      );
    }

    // Default Plain List (when no operational groups exist)
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16.0),
      itemCount: filteredDevices.length,
      itemBuilder: (context, index) {
        final device = filteredDevices[index];
        final position = positions[device.id];
        final isSelected = device.id == selectedDeviceId;

        return FleetListItem(
          device: device,
          position: position,
          isSelected: isSelected,
          onTap: () => _handleItemTap(device, position),
        );
      },
    );
  }

  void _handleItemTap(DeviceModel device, PositionModel? position) {
    // 1. Select device in provider
    context.read<LiveFleetProvider>().selectDevice(device.id);

    // 2. Trigger onDeviceSelected callback
    widget.onDeviceSelected?.call(device, position);

    // 3. Close the drawer
    if (widget.onClosePressed != null) {
      widget.onClosePressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}
