import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart';
import '../domain/habit_schedule.dart';

/// A reminder as the planner needs it (wire field names), whatever its sync state.
class PlannerReminder {
  final String id;
  final String habitId;
  final int minuteOfDay;
  final Set<int> daysOfWeek;
  final String timezoneMode;
  final String? timezone;
  final bool enabled;

  const PlannerReminder({
    required this.id,
    required this.habitId,
    required this.minuteOfDay,
    required this.daysOfWeek,
    required this.timezoneMode,
    required this.timezone,
    required this.enabled,
  });

  /// From a wire payload; null when it cannot be read (it is then simply not scheduled).
  static PlannerReminder? fromWire(Map<String, dynamic> p) {
    final time = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$')
        .firstMatch(p['local_time'] as String? ?? '');
    final days = p['days_of_week'];
    final id = p['id'];
    final habit = p['habit_id'];
    if (time == null || days is! List || id is! String || habit is! String) return null;
    return PlannerReminder(
      id: id,
      habitId: habit,
      minuteOfDay: int.parse(time.group(1)!) * 60 + int.parse(time.group(2)!),
      daysOfWeek: {
        for (final d in days)
          if (d is int) d,
      },
      timezoneMode: p['timezone_mode'] as String? ?? 'habit_zone',
      timezone: p['timezone'] as String?,
      enabled: p['enabled'] as bool? ?? true,
    );
  }
}

class PlannedNotification {
  /// Stable platform id: account + reminder id + local date slot (spec: notification identity).
  final int id;
  final String reminderId;
  final String habitId;
  final LocalDate slotDate;
  final DateTime fireAt;

  const PlannedNotification({
    required this.id,
    required this.reminderId,
    required this.habitId,
    required this.slotDate,
    required this.fireAt,
  });
}

/// Phase 3.2b: reminders + habit schedules + the account calendar + now -> what the device
/// schedules over a rolling horizon. Pure Dart; pinned by contract-fixtures/domain/
/// reminder_schedule.json.
///
/// ASSUMPTION(A3.2b-reminder-zone): an explicit timezone wins; otherwise device_zone uses the
/// device zone and habit_zone the habit calendar's zone in force on that date, so a pending
/// change applies from its effective date. Slot dates are dates in that zone; due-ness is the
/// habit's for the same date.
class ReminderPlanner {
  static const horizonDays = 14;

  final String accountKey;

  const ReminderPlanner(this.accountKey);

  List<PlannedNotification> plan({
    required List<PlannerReminder> reminders,
    required Map<String, HabitSchedule> schedules,
    required TimezoneTimeline timeline,
    required String deviceZone,
    required DateTime now,
    Set<(String, LocalDate)> completed = const {},
    int horizon = horizonDays,
  }) {
    final planned = <PlannedNotification>[];
    for (final reminder in reminders) {
      final schedule = schedules[reminder.habitId];
      if (!reminder.enabled || schedule == null) continue;
      final explicit = reminder.timezone;
      final habitZone = explicit == null && reminder.timezoneMode != 'device_zone';
      final fixedZone = explicit ?? (habitZone ? null : deviceZone);
      final today = fixedZone == null
          ? timeline.localDateAt(now)
          : TimezoneTimeline([CalendarEntry(DateTime.utc(1970), fixedZone)]).localDateAt(now);

      for (var i = 0; i < horizon; i++) {
        final date = today.addDays(i);
        if (!reminder.daysOfWeek.contains(date.isoWeekday)) continue;
        if (!schedule.isDue(date, timeline)) continue;
        if (completed.contains((reminder.habitId, date))) continue;

        final DateTime fireAt;
        if (habitZone) {
          final start = timeline.startOfLocalDay(date);
          final zone = timeline.entryAt(start).timezone;
          final at = TimezoneTimeline.wallTimeInstant(date, reminder.minuteOfDay, zone);
          // A clock time before the habit-day begins (a zone change) moves to its start.
          fireAt = at.isBefore(start) ? start : at;
        } else {
          fireAt = TimezoneTimeline.wallTimeInstant(date, reminder.minuteOfDay, fixedZone!);
        }
        if (!fireAt.isAfter(now)) continue;
        planned.add(
          PlannedNotification(
            id: notificationId(reminder.id, date),
            reminderId: reminder.id,
            habitId: reminder.habitId,
            slotDate: date,
            fireAt: fireAt,
          ),
        );
      }
    }
    planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return planned;
  }

  /// FNV-1a over "account|reminder|date", folded to a positive 31-bit int (Android ids are
  /// 32-bit signed). Stable across runs and isolates; replanning replaces, never duplicates.
  int notificationId(String reminderId, LocalDate date) {
    var hash = 0x811c9dc5;
    for (final unit in '$accountKey|$reminderId|$date'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
