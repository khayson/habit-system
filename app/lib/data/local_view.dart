import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/calendar/local_date.dart';
import '../domain/habit_schedule.dart';
import '../domain/provisional_progress.dart';
import '../domain/provisional_type_rules.dart';
import '../sync/outbox_states.dart';
import 'account_calendar.dart';
import 'app_database.dart';
import 'entity_codec.dart';
import 'timezone_view.dart';

/// What the UI reads: the pending overlay (derived from outbox rows) over the confirmed rows.
/// Nothing here writes; confirmed rows only ever hold what the server said (invariant 9).
class LocalView {
  final AppDatabase db;
  final ProvisionalTypeRegistry types;

  LocalView(this.db, {ProvisionalTypeRegistry? types})
    : types = types ?? ProvisionalTypeRegistry.builtins();

  Stream<List<HabitView>> watchHabits() => db
      .customSelect('SELECT 1', readsFrom: {db.habits, db.outbox})
      .watch()
      .asyncMap((_) => habits());

  Future<List<HabitView>> habits() async {
    final confirmed = await db.select(db.habits).get();
    final creates =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.operation.equals('habit.create') &
                    o.state.isIn(OutboxState.unacked + [OutboxState.acked]),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();

    final views = <String, HabitView>{
      for (final row in confirmed)
        row.id: HabitView(
          payload: EntityCodec.habitPayload(row),
          confirmedVersion: row.version,
          syncState: null,
          knownType: types.lookup(row.type ?? '') != null,
        ),
    };
    for (final row in creates) {
      if (views.containsKey(row.entityId)) continue;
      final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
      views[row.entityId] = HabitView(
        payload: {...payload, 'id': row.entityId},
        confirmedVersion: null,
        syncState: row.state,
        knownType: types.lookup(payload['type'] as String? ?? '') != null,
      );
    }
    return views.values.toList();
  }

  Stream<LogView> watchLog(String habitId, String date) => db
      .customSelect('SELECT 1', readsFrom: {db.habitLogs, db.outbox})
      .watch()
      .asyncMap((_) => log(habitId, date));

  /// The provisional habit-day: confirmed value, then every unacknowledged (or acked but not
  /// yet confirmed) intent for that day applied in order.
  Future<LogView> log(String habitId, String date) async {
    final confirmed =
        await (db.select(db.habitLogs)
              ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(date))
              ..orderBy([(l) => OrderingTerm.desc(l.version)])
              ..limit(1))
            .getSingleOrNull();
    final rows =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.habitId.equals(habitId) &
                    o.localDateHint.equals(date) &
                    o.entity.equals('habit_log'),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();

    Object? value = EntityCodec.decodeJson(confirmed?.value);
    var deleted = confirmed?.deletedAt != null;
    String? state;
    var changedAt = DateTime.tryParse(confirmed?.completedAt ?? confirmed?.occurredAt ?? '');
    for (final row in rows) {
      final reflected =
          row.state == OutboxState.acked && (row.ackVersion ?? 0) <= (confirmed?.version ?? 0);
      if (reflected) continue;
      final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
      if (row.operation == 'log.set_value') {
        value = payload['value'];
        deleted = false;
      } else if (row.operation == 'log.delete') {
        deleted = true;
      }
      state = row.state;
      changedAt = DateTime.tryParse(row.occurredAt);
    }

    return LogView(
      habitId: habitId,
      date: date,
      value: deleted ? null : value,
      deleted: deleted,
      confirmedVersion: confirmed?.version,
      syncState: state,
      changedAt: changedAt,
    );
  }

  // Today (screen 05) ---------------------------------------------------------------------------

  /// Re-evaluates on every relevant table change and once a minute, so the habit-day rolls over
  /// at the calendar's day start without a table change.
  Stream<TodayView?> watchToday(
    DateTime Function() deviceNow, {
    Duration tick = const Duration(minutes: 1),
  }) {
    late StreamController<void> triggers;
    StreamSubscription<void>? tables;
    StreamSubscription<void>? settings;
    Timer? timer;
    triggers = StreamController<void>(
      onListen: () {
        // The ask-on-change answer: selected as rows so every settings write re-runs Today.
        settings = db
            .select(db.localSettings)
            .watch()
            .listen((_) => triggers.add(null), onError: triggers.addError);
        tables = db
            .customSelect(
              'SELECT 1',
              readsFrom: {
                db.habits,
                db.habitLogs,
                db.outbox,
                db.syncState,
                db.calendarEntries,
                db.localSettings,
              },
            )
            .watch()
            .listen((_) => triggers.add(null), onError: triggers.addError);
        timer = Timer.periodic(tick, (_) => triggers.add(null));
      },
      onCancel: () async {
        timer?.cancel();
        await settings?.cancel();
        await tables?.cancel();
        await triggers.close();
      },
    );
    return triggers.stream.asyncMap((_) => today(deviceNow()));
  }

  /// The account's habit-day on the server's clock (F10) and each active habit's provisional
  /// state for it. Null until the account's calendar is known.
  Future<TodayView?> today(DateTime deviceNow) async {
    final calendar = await AccountCalendar.load(db, deviceNow: deviceNow);
    if (calendar == null) return null;
    final date = calendar.today(deviceNow);
    final day = date.toString();
    final attention = {
      for (final row
          in await (db.select(db.outbox)..where(
                (o) =>
                    o.state.equals(OutboxState.needsAttention) &
                    (o.localDateHint.equals(day) | o.entity.equals('habit')),
              ))
              .get())
        row.habitId ?? row.entityId: row,
    };

    final items = <TodayItem>[];
    for (final habit in await habits()) {
      final p = habit.payload;
      // Due today: schedule, active range, zero-length dates excluded (Phase 3.2a).
      final schedule = HabitSchedule.fromWire(p);
      final known = schedule.versionOn(date)?.frequency.known ?? true;
      if (known && !schedule.isDue(date, calendar.timeline)) continue;
      if (!known && !schedule.isActive(date)) continue;
      final log = await this.log(habit.id, day);
      final rules = types.lookup(p['type'] as String? ?? '');
      final complete = _complete(rules, log.value, p['target_value']);
      items.add(
        TodayItem(
          habit: habit,
          log: log,
          rules: rules,
          complete: complete,
          attention: attention[habit.id],
          week: await _week(habit, schedule, date),
          completedAt: complete && log.changedAt != null
              ? calendar.localTimeAt(log.changedAt!)
              : null,
        ),
      );
    }
    // G4: creation order. Ids are UUIDv7 (time-ordered), so a rename never moves a habit.
    items.sort((a, b) => a.habit.id.compareTo(b.habit.id));

    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();
    final user = EntityCodec.decodeJson(state.userPayload);
    return TodayView(
      date: date,
      localNow: calendar.localNow(deviceNow),
      userName: user is Map ? user['name'] as String? : null,
      items: items,
      timezone: await DeviceSettings(db).status(deviceNow),
    );
  }

  /// weekly_count: distinct completed local days of this Monday-Sunday week, from local logs.
  /// Provisional: the week's result is the server's (invariant 9).
  Future<ProvisionalWeekProgress?> _week(
    HabitView habit,
    HabitSchedule schedule,
    LocalDate date,
  ) async {
    final count = schedule.weeklyCountOn(date);
    if (count == null) return null;
    final monday = date.addDays(1 - date.isoWeekday);
    return ProvisionalProgress(types).week(
      type: habit.payload['type'] as String? ?? '',
      perDayTarget: habit.payload['target_value'],
      countTarget: count,
      logs: {
        for (var i = 0; i < 7; i++)
          monday.addDays(i).toString(): (await log(habit.id, monday.addDays(i).toString())).value,
      },
    );
  }

  static bool _complete(ProvisionalTypeRules? rules, Object? value, Object? target) {
    if (rules == null) return false;
    final v = rules.parseValue(value);
    final t = rules.parseTarget(target);
    return v != null && t != null && rules.isComplete(v, t);
  }

  // Queue (screen 18) ---------------------------------------------------------------------------

  Stream<QueueView> watchQueue() => db
      .customSelect('SELECT 1', readsFrom: {db.outbox, db.syncState, db.habits})
      .watch()
      .asyncMap((_) => queue());

  Future<QueueView> queue() async {
    final rows =
        await (db.select(db.outbox)
              ..where((o) => o.state.isIn(OutboxState.unacked))
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();
    final names = {for (final h in await habits()) h.id: h.payload['name'] as String?};
    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();
    return QueueView(
      items: [for (final row in rows) QueueItem(row, names[row.habitId ?? row.entityId])],
      state: state,
    );
  }
}

class TodayView {
  final LocalDate date;

  /// Wall-clock time in the account's calendar zone, on the server's clock.
  final DateTime localNow;
  final String? userName;
  final List<TodayItem> items;

  /// For the ask-on-change card (screen 04).
  final TimezoneStatus? timezone;

  const TodayView({
    required this.date,
    required this.localNow,
    required this.userName,
    required this.items,
    this.timezone,
  });

  int get completeCount => items.where((i) => i.complete).length;
  bool get hasPending => items.any((i) => i.pending);
}

class TodayItem {
  final HabitView habit;
  final LogView log;

  /// Null for a type this app version does not know (show the "update the app" card).
  final ProvisionalTypeRules? rules;

  /// Provisional when [pending]: computed locally from the overlay (invariant 9).
  final bool complete;

  /// The row that needs the user's decision before more changes queue behind it.
  final OutboxRow? attention;

  /// weekly_count habits: this week so far (provisional), else null.
  final ProvisionalWeekProgress? week;

  /// Wall-clock time of the check-in in the habit calendar, when complete.
  final DateTime? completedAt;

  const TodayItem({
    required this.habit,
    required this.log,
    required this.rules,
    required this.complete,
    required this.attention,
    this.week,
    this.completedAt,
  });

  String get name => habit.payload['name'] as String? ?? '';
  bool get pending => log.provisional || habit.provisional;
  bool get needsAttention => attention != null;
  bool get canToggle => rules?.oneTap == true && !needsAttention;
}

class QueueView {
  final List<QueueItem> items;
  final SyncStateRow state;

  const QueueView({required this.items, required this.state});

  /// Changes still on their way (everything not needing the user).
  int get waiting => items.where((i) => i.row.state != OutboxState.needsAttention).length;
  List<QueueItem> get needsAttention =>
      items.where((i) => i.row.state == OutboxState.needsAttention).toList();
  bool get paused => state.status == SyncStatus.paused;
}

class QueueItem {
  final OutboxRow row;
  final String? habitName;

  const QueueItem(this.row, this.habitName);

  Map<String, dynamic> get payload => (jsonDecode(row.payload) as Map).cast<String, dynamic>();
  Map<String, dynamic>? get error {
    final decoded = EntityCodec.decodeJson(row.lastError);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }
}

class HabitView {
  /// The entity as known: server fields (incl. unknown ones) or the pending create's payload.
  final Map<String, dynamic> payload;
  final int? confirmedVersion;

  /// null when nothing is pending; otherwise the newest outbox state.
  final String? syncState;

  /// False for a type this app version does not know: show an "update the app" card (A21).
  final bool knownType;

  const HabitView({
    required this.payload,
    required this.confirmedVersion,
    required this.syncState,
    required this.knownType,
  });

  String get id => payload['id'] as String;
  bool get provisional => syncState != null;
}

class LogView {
  final String habitId;
  final String date;
  final Object? value;
  final bool deleted;
  final int? confirmedVersion;
  final String? syncState;

  /// When the value was last set: the pending write's occurred_at, else the confirmed
  /// completed_at (or occurred_at).
  final DateTime? changedAt;

  const LogView({
    required this.habitId,
    required this.date,
    required this.value,
    required this.deleted,
    required this.confirmedVersion,
    required this.syncState,
    this.changedAt,
  });

  bool get provisional => syncState != null;
}
