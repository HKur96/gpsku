import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/reports/domain/helpers/report_date_range_helper.dart';

void main() {
  group('ReportDateRange & Timezone Helper Unit Tests', () {
    // Fixed deterministic reference time: 2026-11-08 14:30:00 Local
    final fixedNow = DateTime(2026, 11, 8, 14, 30, 0);

    test(
      'TC-DATE-01: ReportDateRange.today calculates start to end of day',
      () {
        final range = ReportDateRange.today(now: fixedNow);

        expect(range.preset, ReportTimePreset.today);
        expect(range.from, DateTime(2026, 11, 8, 0, 0, 0, 0));
        expect(range.to, DateTime(2026, 11, 8, 23, 59, 59, 999));
        expect(range.isValid, isTrue);
      },
    );

    test(
      'TC-DATE-02: ReportDateRange.yesterday calculates start to end of yesterday',
      () {
        final range = ReportDateRange.yesterday(now: fixedNow);

        expect(range.preset, ReportTimePreset.yesterday);
        expect(range.from, DateTime(2026, 11, 7, 0, 0, 0, 0));
        expect(range.to, DateTime(2026, 11, 7, 23, 59, 59, 999));
        expect(range.isValid, isTrue);
      },
    );

    test(
      'TC-DATE-03: ReportDateRange.last24Hours calculates exact 24-hour backward span',
      () {
        final range = ReportDateRange.last24Hours(now: fixedNow);

        expect(range.preset, ReportTimePreset.last24Hours);
        expect(range.from, DateTime(2026, 11, 7, 14, 30, 0));
        expect(range.to, fixedNow);
        expect(range.duration, const Duration(hours: 24));
        expect(range.isValid, isTrue);
      },
    );

    test('TC-DATE-04: ReportDateRange.custom sets custom from and to', () {
      final customFrom = DateTime(2026, 11, 1, 8, 0, 0);
      final customTo = DateTime(2026, 11, 5, 18, 0, 0);

      final range = ReportDateRange.custom(from: customFrom, to: customTo);

      expect(range.preset, ReportTimePreset.custom);
      expect(range.from, customFrom);
      expect(range.to, customTo);
      expect(range.duration, const Duration(days: 4, hours: 10));
      expect(range.isValid, isTrue);
    });

    test(
      'TC-DATE-05: fromUtcIso and toUtcIso format as ISO-8601 UTC strings ending with Z',
      () {
        final utcFrom = DateTime.utc(2026, 11, 8, 0, 0, 0);
        final utcTo = DateTime.utc(2026, 11, 8, 23, 59, 59, 999);

        final range = ReportDateRange.custom(from: utcFrom, to: utcTo);

        expect(range.fromUtcIso, '2026-11-08T00:00:00.000Z');
        expect(range.toUtcIso, '2026-11-08T23:59:59.999Z');
      },
    );

    test(
      'TC-DATE-06: toQueryParams outputs standard Traccar from and to UTC parameters',
      () {
        final utcFrom = DateTime.utc(2026, 11, 8, 0, 0, 0);
        final utcTo = DateTime.utc(2026, 11, 8, 23, 59, 59, 999);

        final range = ReportDateRange.custom(from: utcFrom, to: utcTo);
        final queryParams = range.toQueryParams();

        expect(queryParams, {
          'from': '2026-11-08T00:00:00.000Z',
          'to': '2026-11-08T23:59:59.999Z',
        });
      },
    );

    test('TC-DATE-07: isValid evaluates false when to is before from', () {
      final invalidRange = ReportDateRange.custom(
        from: DateTime(2026, 11, 8, 12, 0, 0),
        to: DateTime(2026, 11, 8, 10, 0, 0),
      );

      expect(invalidRange.isValid, isFalse);
    });

    test(
      'TC-DATE-08: Value equality, hashcode, and toString work correctly',
      () {
        final range1 = ReportDateRange.today(now: fixedNow);
        final range2 = ReportDateRange.today(now: fixedNow);
        final range3 = ReportDateRange.yesterday(now: fixedNow);

        expect(range1, equals(range2));
        expect(range1.hashCode, equals(range2.hashCode));
        expect(range1, isNot(equals(range3)));
        expect(range1.toString(), contains('today'));
      },
    );

    test(
      'TC-DATE-09: ReportTimePreset contains localized Indonesian labels',
      () {
        expect(ReportTimePreset.today.label, 'Hari Ini');
        expect(ReportTimePreset.yesterday.label, 'Kemarin');
        expect(ReportTimePreset.last24Hours.label, '24 Jam Terakhir');
        expect(ReportTimePreset.custom.label, 'Kustom');
      },
    );
  });
}
