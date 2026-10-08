import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/habit_schedule.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/contract_fixtures.dart';

/// The Dart half of contract-fixtures/domain/schedule.json: the same due-ness as the PHP
/// HabitSchedule + PeriodEngine, date by date.
void main() {
  setUpAll(() => ensureTimeZonesLoaded(tzdata.initializeTimeZones));

  final fixture = contractFixture('domain/schedule.json');

  test('declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

  for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final timeline = TimezoneTimeline([
        for (final e in (c['calendar'] as List).cast<Map<String, dynamic>>())
          CalendarEntry(
            DateTime.parse(e['effective_at'] as String),
            e['timezone'] as String,
            e['day_start_offset_minutes'] as int,
          ),
      ]);
      final schedule = HabitSchedule.fromWire(c['habit'] as Map<String, dynamic>);
      for (final row in (c['rows'] as List).cast<List<dynamic>>()) {
        final date = LocalDate.parse(row[0] as String);
        final key = schedule.periodKeyOn(date, timeline);
        expect(
          [
            row[0],
            schedule.versionOn(date)?.version,
            schedule.isActive(date),
            schedule.isEligible(date),
            key != null,
            key,
          ],
          row,
          reason: '${c['name']} ${row[0]}',
        );
      }
    });
  }

  group('tolerant reader', () {
    test('an unknown frequency type is kept and never due', () {
      final schedule = HabitSchedule.fromWire({
        'definitions': [
          {'version': 1, 'effective_date': '2026-05-01', 'frequency_type': 'lunar'},
        ],
        'active_ranges': [
          {'starts_on': '2026-05-01', 'ends_before': null},
        ],
      });
      expect(schedule.versionOn(LocalDate.parse('2026-05-02'))!.frequency.known, isFalse);
      expect(schedule.isDue(LocalDate.parse('2026-05-02')), isFalse);
    });

    test('a habit saved on this device uses its flat fields until confirmed', () {
      final schedule = HabitSchedule.fromWire({
        'start_local_date': '2026-05-04',
        'frequency_type': 'weekdays',
        'frequency_config': {
          'days': [1],
        },
        'archived_at': null,
      });
      expect(schedule.isDue(LocalDate.parse('2026-05-04')), isTrue);
      expect(schedule.isDue(LocalDate.parse('2026-05-05')), isFalse);
      expect(schedule.isDue(LocalDate.parse('2026-05-03')), isFalse);
    });
  });
}
