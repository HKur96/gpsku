import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';

/// Scrollable list displaying historical stops ([StopReportModel]).
class StopListView extends StatelessWidget {
  final List<StopReportModel> stops;
  final bool isLoading;
  final ValueChanged<StopReportModel>? onStopSelected;

  const StopListView({
    super.key,
    required this.stops,
    this.isLoading = false,
    this.onStopSelected,
  });

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}j ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_parking_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tidak ada pemberhentian tercatat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kendaraan tidak tercatat berhenti pada periode ini.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
      itemBuilder: (context, index) {
        final stop = stops[index];
        final startLocal = stop.startTime.toLocal();
        final endLocal = stop.endTime.toLocal();
        final timeSpan =
            '${_timeFormat.format(startLocal)} - ${_timeFormat.format(endLocal)}';
        final dateStr = _dateFormat.format(startLocal);
        final durationStr = _formatDuration(stop.durationTime);
        final addressStr = (stop.address != null && stop.address!.isNotEmpty)
            ? stop.address!
            : '${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}';

        return Card(
          margin: EdgeInsets.zero,
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            onTap: onStopSelected != null ? () => onStopSelected!(stop) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Stop Badge, Time Range & Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: const Icon(
                              Icons.pause_circle_filled,
                              size: 16,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeSpan,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '($dateStr)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: Text(
                          durationStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Location Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          addressStr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
