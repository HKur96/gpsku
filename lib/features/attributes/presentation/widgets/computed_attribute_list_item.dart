import 'package:flutter/material.dart';
import '../../data/models/computed_attribute_model.dart';

/// Single visual item card in [ComputedAttributesDrawer] displaying attribute description,
/// target key, return type chip, JEXL expression snippet, and context actions.
class ComputedAttributeListItem extends StatelessWidget {
  final ComputedAttributeModel attribute;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssignDevices;
  final VoidCallback? onTestExpression;
  final bool isSelected;

  const ComputedAttributeListItem({
    super.key,
    required this.attribute,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAssignDevices,
    this.onTestExpression,
    this.isSelected = false,
  });

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'number':
        return const Color(0xFF1E88E5); // Blue
      case 'string':
        return const Color(0xFF8E24AA); // Purple
      case 'boolean':
        return const Color(0xFF2E7D32); // Green
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'number':
        return Icons.tag;
      case 'string':
        return Icons.text_fields;
      case 'boolean':
        return Icons.toggle_on;
      default:
        return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _getTypeColor(attribute.type);
    final typeIcon = _getTypeIcon(attribute.type);

    return Container(
      key: Key('computed_attribute_item_${attribute.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1E88E5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: description, badges, and action menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type avatar icon
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: typeColor.withValues(alpha: 0.15),
                      child: Icon(typeIcon, color: typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Title & Target attribute name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attribute.description,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Target: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  attribute.attribute,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        attribute.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                    // Context action popup menu
                    PopupMenuButton<String>(
                      key: Key('attribute_action_menu_${attribute.id}'),
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        switch (val) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'assign':
                            onAssignDevices?.call();
                            break;
                          case 'test':
                            onTestExpression?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Ubah'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign',
                          child: Row(
                            children: [
                              Icon(Icons.directions_car_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Tautkan Armada'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Uji Formula'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFE53935),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Hapus',
                                style: TextStyle(color: Color(0xFFE53935)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // JEXL Expression Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.functions,
                        size: 16,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          attribute.expression,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
