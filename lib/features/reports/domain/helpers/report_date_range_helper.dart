import 'package:flutter/foundation.dart';

/// Supported time range presets for Traccar telemetry reports.
enum ReportTimePreset {
  today('Hari Ini'),
  yesterday('Kemarin'),
  last24Hours('24 Jam Terakhir'),
  custom('Kustom');

  final String label;
  const ReportTimePreset(this.label);
}

/// Helper model encapsulating historical report time boundaries
/// with standardized ISO-8601 UTC parameter formatting for the Traccar REST backend.
@immutable
class ReportDateRange {
  final DateTime from;
  final DateTime to;
  final ReportTimePreset preset;

  const ReportDateRange({
    required this.from,
    required this.to,
    this.preset = ReportTimePreset.custom,
  });

  /// Factory for 'Hari Ini' (Today): From 00:00:00.000 to 23:59:59.999 local time.
  factory ReportDateRange.today({DateTime? now}) {
    final current = now ?? DateTime.now();
    return ReportDateRange(
      from: DateTime(current.year, current.month, current.day, 0, 0, 0, 0),
      to: DateTime(current.year, current.month, current.day, 23, 59, 59, 999),
      preset: ReportTimePreset.today,
    );
  }

  /// Factory for 'Kemarin' (Yesterday): From yesterday 00:00:00.000 to yesterday 23:59:59.999 local time.
  factory ReportDateRange.yesterday({DateTime? now}) {
    final current = now ?? DateTime.now();
    final y = current.subtract(const Duration(days: 1));
    return ReportDateRange(
      from: DateTime(y.year, y.month, y.day, 0, 0, 0, 0),
      to: DateTime(y.year, y.month, y.day, 23, 59, 59, 999),
      preset: ReportTimePreset.yesterday,
    );
  }

  /// Factory for '24 Jam Terakhir': From now - 24 hours to now.
  factory ReportDateRange.last24Hours({DateTime? now}) {
    final current = now ?? DateTime.now();
    return ReportDateRange(
      from: current.subtract(const Duration(hours: 24)),
      to: current,
      preset: ReportTimePreset.last24Hours,
    );
  }

  /// Factory for user-defined custom date range.
  factory ReportDateRange.custom({
    required DateTime from,
    required DateTime to,
  }) {
    return ReportDateRange(from: from, to: to, preset: ReportTimePreset.custom);
  }

  /// Formats [from] into RFC 3339 / ISO-8601 UTC representation (e.g. `2026-11-08T00:00:00.000Z`).
  String get fromUtcIso => from.toUtc().toIso8601String();

  /// Formats [to] into RFC 3339 / ISO-8601 UTC representation (e.g. `2026-11-08T23:59:59.999Z`).
  String get toUtcIso => to.toUtc().toIso8601String();

  /// Map of query parameters ready for consumption by Traccar Reports API.
  Map<String, String> toQueryParams() => {'from': fromUtcIso, 'to': toUtcIso};

  /// Validates that [to] does not occur strictly prior to [from].
  bool get isValid => !to.isBefore(from);

  /// Absolute time span of the requested window.
  Duration get duration => to.difference(from);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDateRange &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          preset == other.preset;

  @override
  int get hashCode => Object.hash(from, to, preset);

  @override
  String toString() =>
      'ReportDateRange(preset: ${preset.name}, from: $fromUtcIso, to: $toUtcIso)';
}
