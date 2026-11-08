import 'package:flutter/material.dart';
import '../../data/models/maintenance_model.dart';
import '../../domain/helpers/maintenance_progress_helper.dart';

/// Single visual item card in [MaintenanceListDrawer] displaying service progress,
/// semantic alert bar, remaining metrics, and context actions.
class MaintenanceListItem extends StatelessWidget {
  final MaintenanceModel maintenance;
  final MaintenanceProgressResult? progress;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssignDevices;
  final VoidCallback? onReset;
  final bool isSelected;

  const MaintenanceListItem({
    super.key,
    required this.maintenance,
    this.progress,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAssignDevices,
    this.onReset,
    this.isSelected = false,
  });

  IconData _getTypeIcon() {
    if (maintenance.isDistanceBased) return Icons.speed;
    if (maintenance.isHoursBased) return Icons.timer;
    return Icons.calendar_today;
  }

  String _getTypeLabel() {
    if (maintenance.isDistanceBased) return 'Jarak Tempuh';
    if (maintenance.isHoursBased) return 'Jam Mesin';
    return 'Kalender';
  }

  Color _getSemanticColor(MaintenanceAlertLevel level) {
    switch (level) {
      case MaintenanceAlertLevel.overdue:
        return const Color(0xFFC62828); // Red
      case MaintenanceAlertLevel.warning:
        return const Color(0xFFE65100); // Amber
      case MaintenanceAlertLevel.normal:
        return const Color(0xFF2E7D32); // Green
    }
  }

  String _getAlertLabel(MaintenanceAlertLevel level) {
    switch (level) {
      case MaintenanceAlertLevel.overdue:
        return 'Jatuh Tempo';
      case MaintenanceAlertLevel.warning:
        return 'Mendekati';
      case MaintenanceAlertLevel.normal:
        return 'Normal';
    }
  }

  String _formatRemainingInfo(
    MaintenanceProgressResult prog,
    MaintenanceModel model,
  ) {
    if (model.isDistanceBased) {
      final km = prog.remainingDistanceKm;
      if (km < 0) {
        return 'Lewat ${(-km).toStringAsFixed(0)} km';
      }
      return 'Sisa ${km.toStringAsFixed(0)} km';
    }

    if (model.isHoursBased) {
      final hours = prog.remainingEngineHours;
      if (hours < 0) {
        return 'Lewat ${(-hours).toStringAsFixed(0)} jam';
      }
      return 'Sisa ${hours.toStringAsFixed(0)} jam';
    }

    // Calendar
    final days = prog.remainingDays;
    if (days < 0) {
      return 'Lewat ${(-days).toStringAsFixed(0)} hari';
    }
    return 'Sisa ${days.toStringAsFixed(0)} hari';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final evalResult =
        progress ??
        MaintenanceProgressHelper.calculate(
          maintenance: maintenance,
          currentValue: maintenance.start,
        );

    final alertLevel = evalResult.alertLevel;
    final semanticColor = _getSemanticColor(alertLevel);
    final alertLabel = _getAlertLabel(alertLevel);
    final remainingText = _formatRemainingInfo(evalResult, maintenance);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: isSelected
            ? BorderSide(color: theme.primaryColor, width: 2.0)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon, Title & Type, Alert Badge, Options Menu
              Row(
                children: [
                  // Type Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: semanticColor.withAlpha(35),
                      shape: BoxShape.circle,
                      border: Border.all(color: semanticColor, width: 1.5),
                    ),
                    child: Icon(_getTypeIcon(), color: semanticColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Title & Metric Type Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTypeLabel(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Semantic Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: semanticColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: semanticColor.withAlpha(120),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      alertLabel,
                      style: TextStyle(
                        color: semanticColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  // Context Action Popup Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Opsi Jadwal',
                    onSelected: (val) {
                      switch (val) {
                        case 'reset':
                          onReset?.call();
                          break;
                        case 'assign':
                          onAssignDevices?.call();
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reset Servis',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'assign',
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tautkan Kendaraan',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ubah Jadwal',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: evalResult.progressRatio.clamp(0.0, 1.0),
                  backgroundColor: semanticColor.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation<Color>(semanticColor),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 6),

              // Bottom Info: Remaining Margin & Percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    remainingText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: evalResult.isOverdue
                          ? const Color(0xFFC62828)
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    evalResult.percentageLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: semanticColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
