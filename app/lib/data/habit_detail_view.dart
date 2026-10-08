import 'dart:async';

import 'package:drift/drift.dart';

import '../domain/calendar/day_resolver.dart';
import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart';
import '../domain/habit_schedule.dart';
import '../domain/provisional_type_rules.dart';
import 'account_calendar.dart';
import 'app_database.dart';
import 'local_view.dart';

/// One heatmap cell's status (screen 12). Every status has text and a symbol in the UI.
enum DayStatus { complete, protected, missed, notDue, pending, upcoming }

/// How far back local data is trusted for the heatmap; older months come from
/// GET /habits/{id}/heatmap when online (Phase 3.2a), shown from memory only.
const localHeatmapDays = 400;

/// Screens 12 and 13 read this: local confirmed rows plus the pending overlay, never a streak
/// computed on the device (invariant 9). Streak numbers come from habit_progress as confirmed.
extension HabitDetailQueries on LocalView {
  Stream<HabitDetail?> watchDetail(
    String habitId,
    DateTime Function() deviceNow, {
    Duration tick = const Duration(minutes: 1),
  }) {
    late StreamController<void> triggers;
    StreamSubscription<void>? tables;
    Timer? timer;
    triggers = StreamController<void>(
      onListen: () {
        tables = db
            .customSelect(
              'SELECT 1',
              readsFrom: {
                db.habits,
                db.habitLogs,
                db.outbox,
                db.syncState,
                db.habitProgress,
                db.periodEvaluations,
                db.calendarEntries,
              },
            )
            .watch()
            .listen((_) => triggers.add(null), onError: triggers.addError);
        timer = Timer.periodic(tick, (_) => triggers.add(null));
      },
      onCancel: () async {
        timer?.cancel();
        await tables?.cancel();
        await triggers.close();
      },
    );
    return triggers.stream.asyncMap((_) => detail(habitId, deviceNow()));
  }

  /// Null while the calendar is unknown or the habit is not on this device.
  Future<HabitDetail?> detail(String habitId, DateTime deviceNow) async {
    final calendar = await AccountCalendar.load(db, deviceNow: deviceNow);
    if (calendar == null) return null;
    final habit = (await habits()).where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return null;
    final today = calendar.today(deviceNow);
    final progress = await (db.select(
      db.habitProgress,
    )..where((p) => p.habitId.equals(habitId))).getSingleOrNull();
    final evaluations =
        await (db.select(db.periodEvaluations)
              ..where((e) => e.habitId.equals(habitId))
              ..orderBy([(e) => OrderingTerm.desc(e.startDate)]))
            .get();

    // The window the UI can reach without a connection: local logs from 400 days back.
    final from = today.addDays(-localHeatmapDays);
    final confirmedLogs =
        await (db.select(db.habitLogs)..where(
              (l) => l.habitId.equals(habitId) & l.logDate.isBiggerOrEqualValue(from.toString()),
            ))
            .get();
    final pendingDates =
        await (db.selectOnly(db.outbox, distinct: true)
              ..addColumns([db.outbox.localDateHint])
              ..where(
                db.outbox.habitId.equals(habitId) &
                    db.outbox.entity.equals('habit_log') &
                    db.outbox.localDateHint.isNotNull(),
              ))
            .map((r) => r.read(db.outbox.localDateHint)!)
            .get();
    final logs = <String, LogView>{};
    for (final date in {...confirmedLogs.map((l) => l.logDate).nonNulls, ...pendingDates}) {
      logs[date] = await log(habitId, date);
    }

    return HabitDetail(
      habit: habit,
      rules: types.lookup(habit.payload['type'] as String? ?? ''),
      schedule: HabitSchedule.fromWire(habit.payload),
      timeline: calendar.timeline,
      calendar: calendar,
      today: today,
      progress: progress,
      evaluations: evaluations,
      logs: logs,
    );
  }
}

class HabitDetail {
  final HabitView habit;
  final ProvisionalTypeRules? rules;
  final HabitSchedule schedule;
  final TimezoneTimeline timeline;
  final AccountCalendar calendar;
  final LocalDate today;
  final ConfirmedProgress? progress;

  /// Newest first.
  final List<ConfirmedEvaluation> evaluations;

  /// Local habit-days with a value (confirmed or pending), keyed by date.
  final Map<String, LogView> logs;

  HabitDetail({
    required this.habit,
    required this.rules,
    required this.schedule,
    required this.timeline,
    required this.calendar,
    required this.today,
    required this.progress,
    required this.evaluations,
    required this.logs,
  });

  late final Map<String, ConfirmedEvaluation> _byKey = {
    for (final e in evaluations.reversed)
      if (e.periodKey != null) e.periodKey!: e,
  };

  String get name => habit.payload['name'] as String? ?? '';
  String? get category => habit.payload['category'] as String?;

  /// The definition in force today (or the latest one), as wire fields for display.
  ScheduleDefinition? get definitionToday =>
      schedule.versionOn(today) ?? (schedule.versions.isEmpty ? null : schedule.versions.last);

  LogView? logOn(LocalDate date) => logs[date.toString()];

  bool isComplete(LocalDate date) {
    final rules = this.rules;
    final log = logOn(date);
    if (rules == null || log == null || log.value == null) return false;
    final v = rules.parseValue(log.value);
    final t = rules.parseTarget(targetOn(date));
    return v != null && t != null && rules.isComplete(v, t);
  }

  /// The target governing [date] (a new definition never reinterprets older days).
  Object? targetOn(LocalDate date) {
    final wire = schedule.versionOn(date)?.wire;
    return wire == null ? habit.payload['target_value'] : (wire['target'] ?? wire['target_value']);
  }

  /// Closed periods from the server's evaluations; today and open periods from local logs
  /// (provisional); not-due from the schedule, inactive ranges and zero-length dates.
  DayStatus statusOn(LocalDate date) {
    final key = schedule.periodKeyOn(date, timeline);
    if (date.isAfter(today)) return key == null ? DayStatus.notDue : DayStatus.upcoming;
    if (key == null) return DayStatus.notDue;
    final evaluation = _byKey[key];
    if (evaluation != null) {
      if (evaluation.completed == true) return DayStatus.complete;
      if (evaluation.protected == true) return DayStatus.protected;
      return DayStatus.missed;
    }
    // Open (or not yet closed on this device): a logged day counts; the result is the server's.
    return isComplete(date) ? DayStatus.complete : DayStatus.pending;
  }

  /// A status the device worked out from its own logs, not yet confirmed by the server.
  bool isProvisional(LocalDate date) {
    final key = schedule.periodKeyOn(date, timeline);
    if (key == null || date.isAfter(today)) return false;
    return _byKey[key] == null || (logOn(date)?.provisional ?? false);
  }

  /// Protected periods inside the current streak: the newest `current` evaluations through
  /// computed_through, read as the server confirmed them (never evaluated here).
  int get protectedInStreak {
    final current = progress?.current ?? 0;
    final through = progress?.computedThrough;
    if (current <= 0 || through == null) return 0;
    return evaluations
        .where((e) => e.endDate != null && e.endDate!.compareTo(through) <= 0)
        .where((e) => e.completed == true || e.protected == true)
        .take(current)
        .where((e) => e.completed != true && e.protected == true)
        .length;
  }

  /// The streak is older than the local yesterday: show "as of" that date.
  LocalDate? get streakAsOf {
    final through = progress?.computedThrough;
    if (through == null) return null;
    final date = LocalDate.parse(through);
    return date.isBefore(today.addDays(-1)) ? date : null;
  }

  /// Why the server would refuse a past check-in on [date], or null when it would take it.
  String? backdateRefusal(LocalDate date) {
    if (date.isAfter(today)) return 'backdate_future';
    if (date.daysUntil(today) > DayResolver.maxBackdateDays) return 'backdate_too_old';
    if (!schedule.isEligible(date)) return 'habit_not_active';
    return null;
  }

  /// Screen 13's list: logged habit-days from the last 30 local days through today, newest first.
  List<LogView> get recentCheckIns {
    final oldest = today.addDays(-DayResolver.maxBackdateDays);
    return [
      for (final entry in logs.entries)
        if (entry.value.value != null &&
            !entry.value.deleted &&
            !LocalDate.parse(entry.key).isBefore(oldest) &&
            !LocalDate.parse(entry.key).isAfter(today))
          entry.value,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }
}

/// Older heatmap months (beyond [localHeatmapDays]) from GET /habits/{id}/heatmap. Shown from
/// memory only; never written to the confirmed tables.
abstract interface class RemoteHeatmap {
  /// Date (YYYY-MM-DD) to the server's status word. Throws when unreachable.
  Future<Map<String, String>> fetch(String habitId, LocalDate from, LocalDate to);
}

DayStatus? dayStatusFromWire(String? status) => switch (status) {
  'complete' => DayStatus.complete,
  'protected' => DayStatus.protected,
  'missed' => DayStatus.missed,
  'not_due' => DayStatus.notDue,
  'pending' => DayStatus.pending,
  _ => null,
};
