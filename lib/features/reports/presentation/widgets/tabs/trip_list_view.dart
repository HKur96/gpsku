import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';

/// Scrollable list displaying historical trips ([TripReportModel]).
class TripListView extends StatelessWidget {
  final List<TripReportModel> trips;
  final bool isLoading;
  final ValueChanged<TripReportModel>? onTripSelected;

  const TripListView({
    super.key,
    required this.trips,
    this.isLoading = false,
    this.onTripSelected,
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

    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alt_route_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tidak ada perjalanan tercatat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Coba pilih rentang tanggal atau preset lain.',
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
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
      itemBuilder: (context, index) {
        final trip = trips[index];
        final startLocal = trip.startTime.toLocal();
        final endLocal = trip.endTime.toLocal();
        final timeSpan =
            '${_timeFormat.format(startLocal)} - ${_timeFormat.format(endLocal)}';
        final dateStr = _dateFormat.format(startLocal);
        final distanceStr = '${trip.distanceKm.toStringAsFixed(1)} km';
        final durationStr = _formatDuration(trip.durationTime);
        final avgSpeedStr = '${trip.speedKmh.toStringAsFixed(0)} km/h';

        return Card(
          margin: EdgeInsets.zero,
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            onTap: onTripSelected != null ? () => onTripSelected!(trip) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Time range & Distance badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            size: 16,
                            color: Color(0xFF1E88E5),
                          ),
                          const SizedBox(width: 6),
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
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          distanceStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Duration, Average Speed
                  Row(
                    children: [
                      _buildMetric(
                        icon: Icons.timer_outlined,
                        label: 'Durasi',
                        value: durationStr,
                      ),
                      const SizedBox(width: 16),
                      _buildMetric(
                        icon: Icons.speed,
                        label: 'Rata-rata',
                        value: avgSpeedStr,
                      ),
                    ],
                  ),

                  // Row 3: Start and End addresses (if available)
                  if (trip.startAddress != null &&
                      trip.startAddress!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.trip_origin,
                          size: 12,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip.startAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (trip.endAddress != null &&
                      trip.endAddress!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: Color(0xFFC62828),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip.endAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
