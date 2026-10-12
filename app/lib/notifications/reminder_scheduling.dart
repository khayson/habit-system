import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/account_calendar.dart';
import '../data/app_database.dart';
import '../data/local_view.dart';
import '../data/reminder_view.dart';
import '../domain/calendar/local_date.dart';
import '../domain/habit_schedule.dart';
import '../domain/provisional_progress.dart';
import 'notification_scheduler.dart';
import 'reminder_planner.dart';

/// Phase 3b, Part D: "Hide habit names in notifications" is off unless the user turns it on.
/// ASSUMPTION(A3b-hide-names): a setting of this device and account (local_settings), not
/// synced.
const kHideHabitNamesDefault = false;

/// The local_settings key of [kHideHabitNamesDefault]'s setting.
const kHideHabitNamesKey = 'notifications.hide_habit_names';

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
    this.hiddenTitle = '',
    this.maxScheduled,
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

  /// The title while habit names are hidden (generic, neutral). The body never names a habit.
  final String hiddenTitle;

  /// B4: the platform's cap (NotificationCaps), decided where the scheduler is created.
  final int? maxScheduled;
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
    _timer = Timer(debounce, replanInBackground);
  }

  /// A replan nobody waits for (the debounce, app start and resume). A refusal from the OS is
  /// not an error anyone can act on here: the next change or resume plans again. Callers that
  /// show the person a result (the hide-names switch) await [replan] and see the failure.
  void replanInBackground() {
    unawaited(
      replan().catchError((Object error) {
        // 4.3b I2: visible to a developer, never shipped; the error type only, no names.
        if (kDebugMode) debugPrint('Reminder replan failed: ${error.runtimeType}');
      }),
    );
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
    // B2 (A34): an archived habit (confirmed, or archived on this device) has no reminders.
    final habits = {
      for (final h in await view.habits())
        if (!h.archived) h.id: h,
    };
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
    final progress = ProvisionalProgress(view.types);
    // From yesterday (a slot near a day boundary) or this week's Monday, whichever is earlier,
    // so a weekly goal counts the days already done (B5).
    final yesterday = today.addDays(-1);
    final from = yesterday.addDays(1 - yesterday.isoWeekday);
    final until = today.addDays(ReminderPlanner.horizonDays);
    for (final MapEntry(key: habitId, value: schedule) in schedules.entries) {
      final payload = habits[habitId]!.payload;
      final type = payload['type'] as String? ?? '';
      final rules = view.types.lookup(type);
      if (rules == null) continue;
      final values = <String, Object?>{};
      for (var date = from; !date.isAfter(until.addDays(6)); date = date.addDays(1)) {
        values['$date'] = (await view.log(habitId, '$date')).value;
      }
      // A completed day needs no reminder; the target is the one in force that day (P3).
      for (var date = from; !date.isAfter(until); date = date.addDays(1)) {
        final value = rules.parseValue(values['$date']);
        final target = rules.parseTarget(schedule.targetOn(date) ?? payload['target_value']);
        if (value != null && target != null && rules.isComplete(value, target)) {
          completed.add((habitId, date));
        }
      }
      // B5: once a Monday-Sunday week reaches its count (the rule Today's weekly progress
      // uses), the rest of that week needs no reminder; an undo brings them back.
      for (var monday = from; !monday.isAfter(until); monday = monday.addDays(7)) {
        final count = schedule.weeklyCountOn(monday.addDays(6)) ?? schedule.weeklyCountOn(monday);
        if (count == null) continue;
        final week = progress.week(
          type: type,
          perDayTarget: schedule.targetOn(monday) ?? payload['target_value'],
          countTarget: count,
          logs: {
            for (var i = 0; i < 7; i++) '${monday.addDays(i)}': values['${monday.addDays(i)}'],
          },
        );
        if (week != null && week.complete) {
          for (var i = 0; i < 7; i++) {
            completed.add((habitId, monday.addDays(i)));
          }
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
      maxScheduled: maxScheduled,
    );
    await _apply(plan, {
      for (final h in habits.values) h.id: h.payload['name'] as String? ?? '',
    }, hideNames: await hideHabitNames());
  }

  /// Whether this account hides habit names on this device.
  Future<bool> hideHabitNames() async {
    final row = await (db.select(
      db.localSettings,
    )..where((s) => s.key.equals(kHideHabitNamesKey))).getSingleOrNull();
    return row == null ? kHideHabitNamesDefault : row.value == '1';
  }

  /// Saves the setting and replaces every notification this account already handed to the OS:
  /// the plan's diff compares fire times only, so text changes need a full replace.
  Future<void> setHideHabitNames(bool on) async {
    await db.transaction(
      () => db
          .into(db.localSettings)
          .insertOnConflictUpdate(
            LocalSettingsCompanion.insert(key: kHideHabitNamesKey, value: on ? '1' : '0'),
          ),
    );
    await _running;
    for (final row in await db.select(db.scheduledNotifications).get()) {
      await scheduler.cancel(row.platformId);
    }
    await db.writeRetrying(() => db.delete(db.scheduledNotifications).go());
    await replan();
  }

  Future<void> _apply(
    List<PlannedNotification> plan,
    Map<String, String> names, {
    required bool hideNames,
  }) async {
    final wanted = {for (final p in plan) p.id: p};
    final existing = {
      for (final row in await db.select(db.scheduledNotifications).get()) row.platformId: row,
    };
    String titleOf(PlannedNotification p) =>
        hideNames ? hiddenTitle : title(names[p.habitId] ?? '');
    // B3: what the person sees is part of the plan; a rename replaces, the ids stay.
    // The presentation (the Android channel) is part of it too: a new channel reschedules all.
    String keyOf(PlannedNotification p) =>
        _contentKey('${titleOf(p)}${scheduler.presentation}', body);
    for (final row in existing.values) {
      final keep = wanted[row.platformId];
      if (keep == null ||
          keep.fireAt.millisecondsSinceEpoch != row.fireAt ||
          row.contentKey != keyOf(keep)) {
        // A slot whose time has passed has already fired: it may be showing in the tray, and
        // cancelling it would take it away. Only its record goes.
        final fired = row.fireAt <= _clock().millisecondsSinceEpoch;
        if (!fired) await scheduler.cancel(row.platformId);
        await db.writeRetrying(
          () => (db.delete(
            db.scheduledNotifications,
          )..where((s) => s.platformId.equals(row.platformId))).go(),
        );
      }
    }
    for (final p in plan) {
      final row = existing[p.id];
      if (row != null &&
          row.fireAt == p.fireAt.millisecondsSinceEpoch &&
          row.contentKey == keyOf(p)) {
        continue;
      }
      await scheduler.schedule(p, title: titleOf(p), body: body);
      await db.writeRetrying(
        () => db
            .into(db.scheduledNotifications)
            .insertOnConflictUpdate(
              ScheduledNotificationsCompanion.insert(
                platformId: Value(p.id),
                reminderId: p.reminderId,
                habitId: p.habitId,
                slotDate: p.slotDate.toString(),
                fireAt: p.fireAt.millisecondsSinceEpoch,
                contentKey: Value(keyOf(p)),
              ),
            ),
      );
    }
  }

  /// A short, stable key of a notification's text (FNV-1a); the text itself is not stored.
  static String _contentKey(String title, String? body) {
    var hash = 0x811c9dc5;
    for (final unit in '$title\u0000${body ?? ''}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
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
    await db.writeRetrying(() => db.delete(db.scheduledNotifications).go());
  }

  Future<void> dispose() async {
    _stopped = true;
    _timer?.cancel();
    await _watch?.cancel();
  }
}
