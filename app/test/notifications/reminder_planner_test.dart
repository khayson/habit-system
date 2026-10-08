import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/habit_schedule.dart';
import 'package:habit/notifications/reminder_planner.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/contract_fixtures.dart';

/// contract-fixtures/domain/reminder_schedule.json: DST gap and repeat, a pending zone change,
/// weekdays and weekly_count habits, completed days, device zone, disabled and archived.
void main() {
  setUpAll(() => ensureTimeZonesLoaded(tzdata.initializeTimeZones));

  final fixture = contractFixture('domain/reminder_schedule.json');
  String iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

  List<PlannedNotification> planFor(Map<String, dynamic> c, {String account = 'user-1'}) {
    final timeline = TimezoneTimeline([
      for (final e in (c['calendar'] as List).cast<Map<String, dynamic>>())
        CalendarEntry(
          DateTime.parse(e['effective_at'] as String),
          e['timezone'] as String,
          e['day_start_offset_minutes'] as int,
        ),
    ]);
    return ReminderPlanner(account).plan(
      reminders: [
        for (final r in (c['reminders'] as List).cast<Map<String, dynamic>>())
          PlannerReminder.fromWire(r)!,
      ],
      schedules: {
        for (final h in (c['habits'] as List).cast<Map<String, dynamic>>())
          h['id'] as String: HabitSchedule.fromWire(h),
      },
      timeline: timeline,
      deviceZone: c['device_zone'] as String,
      now: DateTime.parse(c['now'] as String),
      completed: {
        for (final pair in (c['completed'] as List).cast<List<dynamic>>())
          (pair[0] as String, LocalDate.parse(pair[1] as String)),
      },
      horizon: c['horizon_days'] as int,
    );
  }

  test('declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

  for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final planned = planFor(c);
      expect([
        for (final p in planned) [p.slotDate.toString(), iso(p.fireAt), p.reminderId],
      ], c['expect']);
    });
  }

  test('ids are stable, unique per slot, and differ between accounts', () {
    final c = (fixture['cases'] as List).cast<Map<String, dynamic>>()[3];
    final first = planFor(c);
    final again = planFor(c);
    expect([for (final p in first) p.id], [for (final p in again) p.id]);
    expect({for (final p in first) p.id}.length, first.length);
    expect(first.every((p) => p.id > 0 && p.id <= 0x7fffffff), isTrue);
    final other = planFor(c, account: 'user-2');
    expect({for (final p in first) p.id}.intersection({for (final p in other) p.id}), isEmpty);
  });
}
