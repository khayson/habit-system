import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/habit_schedule.dart';
import 'package:habit/notifications/notification_caps.dart';
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

  group('B4: a cap on scheduled notifications', () {
    // Built lazily: the time zones load in setUpAll, after the group is declared.
    TimezoneTimeline timeline() =>
        TimezoneTimeline([CalendarEntry(DateTime.utc(2026), 'America/Los_Angeles')]);
    final habit = HabitSchedule.fromWire({
      'id': 'h1',
      'start_local_date': '2026-05-01',
      'frequency_type': 'daily',
      'frequency_config': <String, dynamic>{},
      'archived_at': null,
    });
    List<PlannedNotification> plan(int reminders, {int? max}) => ReminderPlanner('user-1').plan(
      reminders: [
        for (var i = 0; i < reminders; i++)
          PlannerReminder(
            id: 'r$i',
            habitId: 'h1',
            minuteOfDay: 8 * 60 + i,
            daysOfWeek: const {1, 2, 3, 4, 5, 6, 7},
            timezoneMode: 'device_zone',
            timezone: null,
            enabled: true,
          ),
      ],
      schedules: {'h1': habit},
      timeline: timeline(),
      deviceZone: 'America/Los_Angeles',
      now: DateTime.utc(2026, 5, 28, 12),
      maxScheduled: max,
    );

    test('the platform limits are named in one place', () {
      expect((NotificationCaps.ios, NotificationCaps.android), (60, 450));
    });

    test('keeps the nearest first, drops the rest silently', () {
      final all = plan(10); // 10 reminders x 14 days
      expect(all, hasLength(140));
      final capped = plan(10, max: NotificationCaps.ios);
      expect(capped, hasLength(60));
      expect(
        capped.map((p) => p.id),
        all.take(60).map((p) => p.id),
        reason: 'the 60 nearest, in order',
      );
      expect(capped.last.fireAt.isAfter(capped.first.fireAt), isTrue);
    });

    test('ties at the same instant are broken by id', () {
      final twins = ReminderPlanner('user-1').plan(
        reminders: [
          for (final id in ['b', 'a', 'c'])
            PlannerReminder(
              id: id,
              habitId: 'h1',
              minuteOfDay: 9 * 60,
              daysOfWeek: const {1, 2, 3, 4, 5, 6, 7},
              timezoneMode: 'device_zone',
              timezone: null,
              enabled: true,
            ),
        ],
        schedules: {'h1': habit},
        timeline: timeline(),
        deviceZone: 'America/Los_Angeles',
        now: DateTime.utc(2026, 5, 28, 12),
        maxScheduled: 2,
      );
      expect(twins, hasLength(2));
      expect(twins[0].fireAt, twins[1].fireAt);
      expect(twins[0].id, lessThan(twins[1].id));
    });
  });
}
