import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/contract_fixtures.dart';

/// The Dart half of contract-fixtures/domain/calendar_changes.json (the monotonic cases; the
/// append_change cases are server-only). PHP runs the same file.
void main() {
  setUpAll(() => ensureTimeZonesLoaded(tzdata.initializeTimeZones));

  final fixture = contractFixture('domain/calendar_changes.json');

  TimezoneTimeline timeline(List<dynamic> rows) => TimezoneTimeline([
    for (final row in rows.cast<Map<String, dynamic>>())
      CalendarEntry(
        DateTime.parse(row['effective_at'] as String),
        row['timezone'] as String,
        row['day_start_offset_minutes'] as int,
      ),
  ]);

  for (final c in (fixture['monotonic'] as List).cast<Map<String, dynamic>>()) {
    if (!(c['suites'] as List).contains('dart')) continue;
    test(c['name'] as String, () {
      final calendar = c['calendar'] as List;
      if (c['valid'] == false) {
        expect(
          () => timeline(calendar),
          throwsA(
            isA<ArgumentError>().having((e) => '${e.message}', 'message', contains('backwards')),
          ),
        );
        return;
      }
      final t = timeline(calendar);
      for (final pair in (c['dates'] as List).cast<List<dynamic>>()) {
        expect(
          t.localDateAt(DateTime.parse(pair[0] as String)).toString(),
          pair[1],
          reason: '${pair[0]}',
        );
      }
      final zeroLength = <String>[];
      for (
        var d = LocalDate.parse('2026-03-01');
        !d.isAfter(LocalDate.parse('2026-06-30'));
        d = d.addDays(1)
      ) {
        if (t.isZeroLength(d)) zeroLength.add(d.toString());
      }
      expect(zeroLength, c['zero_length']);
    });
  }
}
