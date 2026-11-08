import 'package:flutter/material.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';
import '../tabs/stop_list_view.dart';
import '../tabs/trip_list_view.dart';

/// Bottom tabbed sheet displaying trip & stop lists and a Start Playback CTA.
class RouteSummaryPanel extends StatelessWidget {
  final List<TripReportModel> trips;
  final List<StopReportModel> stops;
  final int positionsCount;
  final bool isLoading;
  final VoidCallback? onStartPlayback;
  final ValueChanged<TripReportModel>? onTripSelected;
  final ValueChanged<StopReportModel>? onStopSelected;

  const RouteSummaryPanel({
    super.key,
    required this.trips,
    required this.stops,
    required this.positionsCount,
    this.isLoading = false,
    this.onStartPlayback,
    this.onTripSelected,
    this.onStopSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Drag Handle Pill
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            // TabBar
            Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1.0),
                ),
              ),
              child: TabBar(
                labelColor: const Color(0xFF1E88E5),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF1E88E5),
                indicatorWeight: 3.0,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: [
                  Tab(text: 'Perjalanan (${trips.length})'),
                  Tab(text: 'Pemberhentian (${stops.length})'),
                ],
              ),
            ),

            // TabBarView Content
            Expanded(
              child: TabBarView(
                children: [
                  TripListView(
                    trips: trips,
                    isLoading: isLoading,
                    onTripSelected: onTripSelected,
                  ),
                  StopListView(
                    stops: stops,
                    isLoading: isLoading,
                    onStopSelected: onStopSelected,
                  ),
                ],
              ),
            ),

            // Bottom Playback Action Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1.0),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('route_history_start_playback_button'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    positionsCount > 0
                        ? 'Mulai Pemutaran ($positionsCount Titik)'
                        : 'Tidak Ada Jejak Rute',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: (positionsCount > 0 && !isLoading)
                      ? onStartPlayback
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
