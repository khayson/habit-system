import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/day_resolver.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/contract_fixtures.dart';

/// The Dart half of contract-fixtures/domain/day_resolution.json; PHP runs the same file.
void main() {
  setUpAll(() => ensureTimeZonesLoaded(tzdata.initializeTimeZones));

  final fixture = contractFixture('domain/day_resolution.json');
  final calendars = (fixture['calendars'] as Map<String, dynamic>).map(
    (name, rows) => MapEntry(name, rows as List<dynamic>),
  );

  TimezoneTimeline timeline(String name) => TimezoneTimeline([
    for (final row in calendars[name]!.cast<Map<String, dynamic>>())
      CalendarEntry(
        DateTime.parse(row['effective_at'] as String),
        row['timezone'] as String,
        row['day_start_offset_minutes'] as int,
      ),
  ]);

  String iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

  test('declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

  test('pins the windows to the fixture rules', () {
    final rules = fixture['rules'] as Map<String, dynamic>;
    expect(DayResolver.futureToleranceSeconds, rules['future_tolerance_seconds']);
    expect(DayResolver.maxOfflineAgeSeconds, rules['max_offline_age_seconds']);
    expect(DayResolver.maxBackdateDays, rules['max_backdate_days']);
  });

  group('resolve', () {
    for (final c in (fixture['resolve'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final resolver = DayResolver(
          timeline(c['calendar'] as String),
          () => DateTime.parse(c['now'] as String),
        );
        final expected = c['expect'] as Map<String, dynamic>;
        final hint = c['local_date_hint'] == null
            ? null
            : LocalDate.parse(c['local_date_hint'] as String);

        try {
          final r = resolver.resolve(
            DateTime.parse(c['occurred_at'] as String),
            capturedTimezone: c['captured_timezone'] as String?,
            localDateHint: hint,
          );
          expect(
            expected.containsKey('error'),
            isFalse,
            reason: 'expected an error, got ${r.localDate}',
          );
          expect(r.localDate.toString(), expected['local_date']);
          if (expected.containsKey('hint_matches')) expect(r.hintMatches, expected['hint_matches']);
        } on DayResolutionException catch (e) {
          expect(e.reason, expected['error']);
          final calendar = expected['calendar'] as Map<String, dynamic>?;
          if (calendar != null) {
            expect(e.entry!.timezone, calendar['timezone']);
            expect(e.entry!.dayStartOffsetMinutes, calendar['day_start_offset_minutes']);
            expect(iso(e.entry!.effectiveAt), calendar['effective_at']);
          }
        }
      });
    }
  });

  group('start of day', () {
    for (final c in (fixture['start_of_day'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test('${c['calendar']} ${c['date']}', () {
        final t = timeline(c['calendar'] as String);
        final date = LocalDate.parse(c['date'] as String);
        expect(iso(t.startOfLocalDay(date)), c['starts_at']);
        expect(iso(t.endOfLocalDay(date)), c['ends_at']);
      });
    }
  });

  group('backdate', () {
    for (final c in (fixture['backdate'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final resolver = DayResolver(
          timeline(c['calendar'] as String),
          () => DateTime.parse(c['now'] as String),
        );
        String outcome;
        try {
          final at = c['occurred_at'] as String?;
          resolver.validateBackdate(
            LocalDate.parse(c['date'] as String),
            at: at == null ? null : DateTime.parse(at),
          );
          outcome = 'ok';
        } on DayResolutionException catch (e) {
          outcome = e.reason;
        }
        expect(outcome, c['expect']);
      });
    }
  });

  test('event dates never go backwards across a DST year, incl. zone changes (property)', () {
    for (final name in [
      'la',
      'paris',
      'la_offset_120',
      'paris_offset_150',
      'la_then_paris',
      'paris_then_la',
    ]) {
      final t = timeline(name);
      var instant = DateTime.utc(2026, 1, 1, 12);
      var previous = t.localDateAt(instant);
      for (var i = 0; i < 365 * 24; i++) {
        instant = instant.add(const Duration(hours: 1));
        final date = t.localDateAt(instant);
        expect(date.isBefore(previous), isFalse, reason: '$name went backwards at $instant');
        previous = date;
      }
    }
  });
}
