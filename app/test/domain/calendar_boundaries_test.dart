import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/contract_fixtures.dart';

/// The Dart half of contract-fixtures/domain/calendar_boundaries.json (H1): the same day
/// boundaries as the server across zone changes of 24 hours or more, and the same properties.
void main() {
  setUpAll(() => ensureTimeZonesLoaded(tzdata.initializeTimeZones));

  final fixture = contractFixture('domain/calendar_boundaries.json');
  String iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

  void expectRows(TimezoneTimeline t, List<dynamic> rows, String label) {
    for (final row in rows.cast<List<dynamic>>()) {
      final date = LocalDate.parse(row[0] as String);
      expect(
        [iso(t.startOfLocalDay(date)), iso(t.endOfLocalDay(date)), t.isZeroLength(date)],
        [row[1], row[2], row[3]],
        reason: '$label ${row[0]}',
      );
    }
  }

  group('hand-derived cases', () {
    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      if (c['calendar'] == null) continue; // the refusal is the server's (appendChange)
      test(c['name'] as String, () {
        final t = TimezoneTimeline([
          for (final e in (c['calendar'] as List).cast<Map<String, dynamic>>())
            CalendarEntry(
              DateTime.parse(e['effective_at'] as String),
              e['timezone'] as String,
              e['day_start_offset_minutes'] as int,
            ),
        ]);
        expectRows(t, c['rows'] as List, c['name'] as String);
      });
    }
  });

  test('generated pairs: same boundaries as PHP, and dates never go backwards', () {
    var checked = 0;
    for (final c in (fixture['generated'] as List).cast<Map<String, dynamic>>()) {
      if (c['effective_at'] == null) continue;
      final label = '${c['from']} -> ${c['to']} at ${c['now']}';
      final effective = DateTime.parse(c['effective_at'] as String);
      final t = TimezoneTimeline([
        CalendarEntry(DateTime.parse('2025-12-01T00:00:00Z'), c['from'] as String),
        CalendarEntry(effective, c['to'] as String),
      ]);
      expectRows(t, c['rows'] as List, label);

      LocalDate? previous;
      for (
        var at = effective.subtract(const Duration(days: 3));
        at.isBefore(effective.add(const Duration(days: 3)));
        at = at.add(const Duration(minutes: 15))
      ) {
        final date = t.localDateAt(at);
        expect(previous == null || !date.isBefore(previous), isTrue, reason: '$label at $at');
        previous = date;
      }
      checked++;
    }
    expect(checked, greaterThan(500));
  });
}
