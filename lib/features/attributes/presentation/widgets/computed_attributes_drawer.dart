import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/computed_attribute_model.dart';
import '../providers/computed_attributes_provider.dart';
import 'computed_attribute_assignment_dialog.dart';
import 'computed_attribute_form_modal.dart';
import 'computed_attribute_list_item.dart';

/// Drawer and sliding panel displaying the complete computed attributes catalog,
/// debounced search, type filtering, creation modal launcher, and delete actions.
class ComputedAttributesDrawer extends StatefulWidget {
  final void Function(ComputedAttributeModel attribute)? onAttributeSelected;
  final VoidCallback? onClosePressed;

  const ComputedAttributesDrawer({
    super.key,
    this.onAttributeSelected,
    this.onClosePressed,
  });

  /// Displays the computed attributes drawer as a responsive bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            child: const ComputedAttributesDrawer(),
          ),
        ),
      ),
    );
  }

  @override
  State<ComputedAttributesDrawer> createState() =>
      _ComputedAttributesDrawerState();
}

class _ComputedAttributesDrawerState extends State<ComputedAttributesDrawer> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComputedAttributesProvider>().fetchAttributes();
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<ComputedAttributesProvider>().setSearchQuery(
          _searchController.text,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(ComputedAttributeModel attribute) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Atribut Terhitung'),
        content: Text(
          'Apakah Anda yakin ingin menghapus atribut "${attribute.description}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            key: const Key('attribute_delete_cancel_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('attribute_delete_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<ComputedAttributesProvider>();
    final success = await provider.deleteAttribute(attribute.id);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Atribut "${attribute.description}" berhasil dihapus'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Gagal menghapus atribut'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<ComputedAttributesProvider>();

    final attributes = provider.filteredAttributes;
    final totalCount = provider.attributes.length;
    final activeType = provider.typeFilter;

    return Scaffold(
      key: const Key('computed_attributes_drawer'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atribut Sensor Terhitung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '$totalCount formula JEXL terdaftar',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClosePressed ?? () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const Key('computed_attributes_add_button'),
            icon: const Icon(
              Icons.add_circle,
              color: Color(0xFF1E88E5),
              size: 28,
            ),
            tooltip: 'Tambah Atribut Terhitung',
            onPressed: () {
              ComputedAttributeFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('computed_attributes_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari deskripsi, variabel target, atau formula...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Return type filter chips
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeFilterChip('all', 'Semua', activeType, provider),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                    'number',
                    'Angka (number)',
                    activeType,
                    provider,
                  ),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                    'string',
                    'Teks (string)',
                    activeType,
                    provider,
                  ),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                    'boolean',
                    'Boolean (boolean)',
                    activeType,
                    provider,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 12),

          // Main list or loading / empty state
          Expanded(
            child: provider.isLoading && provider.attributes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : attributes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.functions_outlined,
                          size: 48,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          provider.searchQuery.isNotEmpty || activeType != 'all'
                              ? 'Tidak ada atribut yang cocok dengan filter.'
                              : 'Belum ada atribut sensor terhitung.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => provider.fetchAttributes(force: true),
                    child: ListView.builder(
                      itemCount: attributes.length,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (context, index) {
                        final attr = attributes[index];
                        final isSelected =
                            provider.selectedAttribute?.id == attr.id;

                        return ComputedAttributeListItem(
                          attribute: attr,
                          isSelected: isSelected,
                          onTap: () {
                            provider.selectAttribute(attr);
                            widget.onAttributeSelected?.call(attr);
                          },
                          onEdit: () {
                            ComputedAttributeFormModal.show(
                              context,
                              initialAttribute: attr,
                            );
                          },
                          onAssignDevices: () {
                            ComputedAttributeAssignmentDialog.show(
                              context,
                              attribute: attr,
                            );
                          },
                          onTestExpression: () {
                            ComputedAttributeFormModal.show(
                              context,
                              initialAttribute: attr,
                            );
                          },
                          onDelete: () => _confirmDelete(attr),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(
    String type,
    String label,
    String activeType,
    ComputedAttributesProvider provider,
  ) {
    final isSelected = activeType == type;

    return FilterChip(
      key: Key('type_filter_chip_$type'),
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onSelected: (_) {
        provider.setTypeFilter(type);
      },
    );
  }
}
