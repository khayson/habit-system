import 'dart:async';

import 'package:drift/drift.dart';

import '../data/account_calendar.dart';
import '../data/app_database.dart';
import '../data/local_view.dart';
import '../data/reminder_view.dart';
import '../domain/calendar/local_date.dart';
import '../domain/habit_schedule.dart';
import 'notification_scheduler.dart';
import 'reminder_planner.dart';

/// Keeps the OS schedule equal to the plan for one account (Phase 3.2b). Every handed-over
/// notification is recorded in that account's database, so a replan replaces rather than
/// duplicates and a logout cancels exactly this account's notifications.
///
/// Replans on reminder edits, habit schedule edits, approved zone changes (calendar entries)
/// and any local habit-day write (a completed day drops its notification); the app also
/// replans on start and resume.
class ReminderScheduling {
  ReminderScheduling({
    required this.db,
    required this.view,
    required this.scheduler,
    required this.accountKey,
    required this.deviceZone,
    required this.title,
    this.body,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 1),
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final LocalView view;
  final NotificationScheduler scheduler;
  final String accountKey;
  final Future<String> Function() deviceZone;

  /// Notification text from the habit name (neutral copy, no loss or guilt wording).
  final String Function(String habitName) title;
  final String? body;
  final Duration debounce;
  final DateTime Function() _clock;

  StreamSubscription<void>? _watch;
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;
  bool _stopped = false;

  /// Starts watching the tables that change the plan.
  void start() {
    _watch ??= db
        .customSelect(
          'SELECT (SELECT count(*) FROM outbox) + (SELECT count(*) FROM reminders) '
          '+ (SELECT count(*) FROM habit_logs) + (SELECT count(*) FROM calendar_entries) '
          '+ (SELECT count(*) FROM habits) AS n, '
          '(SELECT max(seq) FROM outbox) AS s',
          readsFrom: {db.outbox, db.reminders, db.habitLogs, db.calendarEntries, db.habits},
        )
        .watch()
        .listen((_) => schedule());
  }

  /// Debounced replan.
  void schedule() {
    if (_stopped) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => replan());
  }

  /// One replan at a time; a request during a run runs once more afterwards.
  Future<void> replan() async {
    if (_stopped) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    _running = _replanOnce();
    try {
      await _running;
    } finally {
      _running = null;
    }
    if (_again && !_stopped) {
      _again = false;
      await replan();
    }
  }

  Future<void> _replanOnce() async {
    final now = _clock().toUtc();
    final calendar = await AccountCalendar.load(db, deviceNow: now);
    if (calendar == null) return;
    final habits = {for (final h in await view.habits()) h.id: h};
    final reminders = [
      for (final r in await view.reminders()) ?PlannerReminder.fromWire(r.payload),
    ];
    final schedules = {
      for (final r in reminders)
        if (habits[r.habitId] case final habit?) r.habitId: HabitSchedule.fromWire(habit.payload),
    };
    final serverNow = calendar.now(now);
    final today = calendar.today(now);
    final completed = <(String, LocalDate)>{};
    for (final habitId in schedules.keys) {
      final payload = habits[habitId]!.payload;
      final rules = view.types.lookup(payload['type'] as String? ?? '');
      if (rules == null) continue;
      for (var i = -1; i <= ReminderPlanner.horizonDays; i++) {
        final date = today.addDays(i);
        final log = await view.log(habitId, date.toString());
        final value = rules.parseValue(log.value);
        final target = rules.parseTarget(payload['target_value']);
        if (value != null && target != null && rules.isComplete(value, target)) {
          completed.add((habitId, date));
        }
      }
    }
    final plan = ReminderPlanner(accountKey).plan(
      reminders: reminders,
      schedules: schedules,
      timeline: calendar.timeline,
      deviceZone: await deviceZone(),
      now: serverNow,
      completed: completed,
    );
    await _apply(plan, {for (final h in habits.values) h.id: h.payload['name'] as String? ?? ''});
  }

  Future<void> _apply(List<PlannedNotification> plan, Map<String, String> names) async {
    final wanted = {for (final p in plan) p.id: p};
    final existing = {
      for (final row in await db.select(db.scheduledNotifications).get()) row.platformId: row,
    };
    for (final row in existing.values) {
      final keep = wanted[row.platformId];
      if (keep == null || keep.fireAt.millisecondsSinceEpoch != row.fireAt) {
        await scheduler.cancel(row.platformId);
        await (db.delete(
          db.scheduledNotifications,
        )..where((s) => s.platformId.equals(row.platformId))).go();
      }
    }
    for (final p in plan) {
      final row = existing[p.id];
      if (row != null && row.fireAt == p.fireAt.millisecondsSinceEpoch) continue;
      await scheduler.schedule(p, title: title(names[p.habitId] ?? ''), body: body);
      await db
          .into(db.scheduledNotifications)
          .insertOnConflictUpdate(
            ScheduledNotificationsCompanion.insert(
              platformId: Value(p.id),
              reminderId: p.reminderId,
              habitId: p.habitId,
              slotDate: p.slotDate.toString(),
              fireAt: p.fireAt.millisecondsSinceEpoch,
            ),
          );
    }
  }

  /// Logout: cancels every notification this account handed to the OS, and stops replanning.
  /// Another account's notifications are never touched (they are not in this database).
  Future<void> cancelAll() async {
    _stopped = true;
    _timer?.cancel();
    await _watch?.cancel();
    await _running;
    for (final row in await db.select(db.scheduledNotifications).get()) {
      await scheduler.cancel(row.platformId);
    }
    await db.delete(db.scheduledNotifications).go();
  }

  Future<void> dispose() async {
    _stopped = true;
    _timer?.cancel();
    await _watch?.cancel();
  }
}
