import 'package:flutter/material.dart';
import 'package:gpsku/features/reports/domain/helpers/report_date_range_helper.dart';

/// Horizontal selection bar for report date range presets.
///
/// Supports instant switching between 'Hari Ini', 'Kemarin', '24 Jam Terakhir',
/// and launching the native Flutter DateRangePickerDialog for 'Kustom'.
class RouteDatePresetBar extends StatelessWidget {
  final ReportDateRange selectedRange;
  final ValueChanged<ReportDateRange> onRangeChanged;

  const RouteDatePresetBar({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            context,
            label: ReportTimePreset.today.label,
            preset: ReportTimePreset.today,
            onTap: () => onRangeChanged(ReportDateRange.today()),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            label: ReportTimePreset.yesterday.label,
            preset: ReportTimePreset.yesterday,
            onTap: () => onRangeChanged(ReportDateRange.yesterday()),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            label: ReportTimePreset.last24Hours.label,
            preset: ReportTimePreset.last24Hours,
            onTap: () => onRangeChanged(ReportDateRange.last24Hours()),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            label: ReportTimePreset.custom.label,
            preset: ReportTimePreset.custom,
            icon: Icons.date_range,
            onTap: () => _showCustomDatePicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required ReportTimePreset preset,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isSelected = selectedRange.preset == preset;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('date_preset_${preset.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: selectedRange.from,
        end: selectedRange.to,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
        0,
        0,
        0,
        0,
      );
      final end = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
      onRangeChanged(ReportDateRange.custom(from: start, to: end));
    }
  }
}
