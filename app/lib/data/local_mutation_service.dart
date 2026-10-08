import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/day_resolver.dart';
import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart' show DayResolutionException;
import '../sync/outbox_states.dart';
import 'account_calendar.dart';
import 'app_database.dart';

/// The only way the app writes domain data locally (A23, invariant 16). Pure Dart: no Flutter
/// imports, so the UI, notification actions, widgets and background isolates share it.
///
/// Every write is one drift transaction that appends (or coalesces) an outbox row. The
/// provisional state the UI shows is derived from those rows over the confirmed rows
/// (LocalView), so the projection and the outbox can never disagree (invariant 8), and nothing
/// provisional is ever written into a confirmed row (invariant 9).
class LocalMutationService {
  final AppDatabase db;
  final Clock clock;
  final Uuid _uuid;

  LocalMutationService(this.db, {Clock? clock, Uuid? uuid})
    : clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  /// habit.create with a client-generated UUIDv7 id (spec 05). Returns the habit id.
  Future<String> createHabit({
    required String name,
    required String type,
    required Object target,
    String? unit,
    required String category,
    String frequencyType = 'daily',
    Map<String, Object?> frequencyConfig = const {},
    required LocalDate startLocalDate,
    bool backdate = false,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final id = _uuid.v7();
      await _append(
        entity: 'habit',
        entityId: id,
        operation: 'habit.create',
        baseVersion: null,
        calendar: calendar,
        localDate: null,
        habitId: id,
        payload: {
          'name': name,
          'type': type,
          'target_value': target,
          'unit': unit,
          'category': category,
          'frequency_type': frequencyType,
          'frequency_config': frequencyConfig,
          'start_local_date': startLocalDate.toString(),
          if (backdate) 'date_mode': 'backdate',
        },
      );
      return id;
    });
  }

  /// log.set_value for the habit-day of [at] (default: now on the server's clock, F10) in the
  /// server's calendar.
  ///
  /// With [logDate] it is a past check-in (screen 13): date_mode "backdate" + log_date, filed
  /// under that date, with occurred_at still the real moment of the write (never invented).
  /// Dates the server would refuse (after the local today, more than 30 days back) throw
  /// [DayResolutionException] and write nothing.
  Future<LocalWrite> setLogValue({
    required String habitId,
    required Object value,
    DateTime? at,
    LocalDate? logDate,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final occurredAt = (at ?? calendar.now(clock())).toUtc();
      if (logDate != null) {
        DayResolver(calendar.timeline, () => occurredAt).validateBackdate(logDate);
      }
      final date = logDate ?? calendar.timeline.localDateAt(occurredAt);
      final rows = await _rowsFor(habitId, date);

      // Coalesce only into the newest row for this habit-day, only while it is unsent.
      final last = rows.isEmpty ? null : rows.last;
      if (last != null && last.state == OutboxState.pending && last.operation == 'log.set_value') {
        final payload = (jsonDecode(last.payload) as Map).cast<String, Object?>()
          ..['value'] = value;
        await (db.update(db.outbox)..where((o) => o.seq.equals(last.seq))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload)), occurredAt: Value(_iso(occurredAt))),
        );
        return LocalWrite(last.mutationId, date, coalesced: true);
      }

      final confirmed = await _confirmedLog(habitId, date);
      final mutationId = await _append(
        entity: 'habit_log',
        entityId: confirmed?.id ?? last?.entityId ?? _uuid.v7(),
        operation: 'log.set_value',
        // A tombstone's version here is an explicit restore (A29).
        baseVersion: _baseVersion(confirmed, rows),
        calendar: calendar,
        localDate: date,
        habitId: habitId,
        occurredAt: occurredAt,
        payload: {
          'habit_id': habitId,
          'value': value,
          if (logDate != null) ...{'date_mode': 'backdate', 'log_date': logDate.toString()},
        },
      );
      return LocalWrite(mutationId, date, coalesced: false);
    });
  }

  /// profile.set_timezone (screen 04): entity user, id = the user id, base_version = the
  /// confirmed user version. The server applies it from the start of the next day (A26), or
  /// cancels a pending change when [timezone] is the zone in force. Unsent rows coalesce: the
  /// latest choice wins.
  Future<String> setTimezone(String timezone) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();
      final pending =
          await (db.select(db.outbox)
                ..where(
                  (o) =>
                      o.operation.equals('profile.set_timezone') &
                      o.state.equals(OutboxState.pending),
                )
                ..orderBy([(o) => OrderingTerm.desc(o.seq)])
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) {
        final now = calendar.now(clock()).toUtc();
        await (db.update(db.outbox)..where((o) => o.seq.equals(pending.seq))).write(
          OutboxCompanion(
            payload: Value(jsonEncode({'timezone': timezone})),
            occurredAt: Value(_iso(now)),
            capturedTimezone: Value(calendar.zoneAt(now)),
          ),
        );
        return pending.mutationId;
      }
      final user = jsonDecode(state.userPayload ?? '{}');
      final version = user is Map && user['version'] is int ? user['version'] as int : null;
      return _append(
        entity: 'user',
        entityId: state.userId,
        operation: 'profile.set_timezone',
        baseVersion: version,
        calendar: calendar,
        localDate: null,
        habitId: null,
        payload: {'timezone': timezone},
      );
    });
  }

  /// log.delete for one habit-day. Carries habit_id + log_date so the server can resolve it
  /// even if the id never reached it (A29).
  Future<LocalWrite> deleteLog({required String habitId, required LocalDate date}) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final rows = await _rowsFor(habitId, date);
      final confirmed = await _confirmedLog(habitId, date);
      if (confirmed == null && rows.isEmpty) {
        throw StateError('Nothing to delete for $habitId on $date.');
      }
      final mutationId = await _append(
        entity: 'habit_log',
        entityId: confirmed?.id ?? rows.last.entityId,
        operation: 'log.delete',
        baseVersion: _baseVersion(confirmed, rows),
        calendar: calendar,
        localDate: date,
        habitId: habitId,
        payload: {'habit_id': habitId, 'log_date': date.toString()},
      );
      return LocalWrite(mutationId, date, coalesced: false);
    });
  }

  /// reminder.create (Phase 3.2b): a clock time and ISO days for one habit. Returns the id.
  Future<String> createReminder({
    required String habitId,
    required String localTime,
    required List<int> daysOfWeek,
    String timezoneMode = 'habit_zone',
    String? timezone,
    bool enabled = true,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final id = _uuid.v7();
      await _append(
        entity: 'reminder',
        entityId: id,
        operation: 'reminder.create',
        baseVersion: null,
        calendar: calendar,
        localDate: null,
        habitId: habitId,
        payload: {
          'habit_id': habitId,
          ..._reminderFields(localTime, daysOfWeek, timezoneMode, timezone, enabled),
        },
      );
      return id;
    });
  }

  /// reminder.update: the whole desired state (absolute). Coalesces into an unsent create or
  /// update for the same reminder, so a burst of edits sends one change.
  Future<void> updateReminder({
    required String reminderId,
    required String localTime,
    required List<int> daysOfWeek,
    String timezoneMode = 'habit_zone',
    String? timezone,
    bool enabled = true,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final fields = _reminderFields(localTime, daysOfWeek, timezoneMode, timezone, enabled);
      final rows = await _reminderRows(reminderId);
      final last = rows.isEmpty ? null : rows.last;
      if (last != null &&
          last.state == OutboxState.pending &&
          (last.operation == 'reminder.create' || last.operation == 'reminder.update')) {
        final payload = (jsonDecode(last.payload) as Map).cast<String, Object?>()..addAll(fields);
        await (db.update(db.outbox)..where((o) => o.seq.equals(last.seq))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload))),
        );
        return;
      }
      final habitId = await _reminderHabit(reminderId, rows);
      await _append(
        entity: 'reminder',
        entityId: reminderId,
        operation: 'reminder.update',
        baseVersion: await _reminderBase(reminderId, rows),
        calendar: calendar,
        localDate: null,
        habitId: habitId,
        payload: fields,
      );
    });
  }

  /// reminder.delete: a tombstone on the server. Appended even behind an unsent create (an
  /// unacknowledged row is never deleted, invariant 8).
  Future<void> deleteReminder(String reminderId) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final rows = await _reminderRows(reminderId);
      await _append(
        entity: 'reminder',
        entityId: reminderId,
        operation: 'reminder.delete',
        baseVersion: await _reminderBase(reminderId, rows),
        calendar: calendar,
        localDate: null,
        habitId: await _reminderHabit(reminderId, rows),
        payload: const {},
      );
    });
  }

  static Map<String, Object?> _reminderFields(
    String localTime,
    List<int> days,
    String timezoneMode,
    String? timezone,
    bool enabled,
  ) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(localTime)) {
      throw ArgumentError.value(localTime, 'localTime', 'must be HH:MM');
    }
    final sorted = {...days}.toList()..sort();
    if (sorted.isEmpty || sorted.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(days, 'daysOfWeek', 'must be ISO days 1..7');
    }
    return {
      'local_time': localTime,
      'days_of_week': sorted,
      'timezone_mode': timezoneMode,
      'timezone': timezone,
      'enabled': enabled,
    };
  }

  Future<List<OutboxRow>> _reminderRows(String reminderId) =>
      (db.select(db.outbox)
            ..where(
              (o) =>
                  o.entity.equals('reminder') &
                  o.entityId.equals(reminderId) &
                  o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  /// The newest version this device has seen (confirmed or acked); a placeholder behind an
  /// unacknowledged row, rebased by the engine from that row's ack (F4).
  Future<int> _reminderBase(String reminderId, List<OutboxRow> rows) async {
    final confirmed = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(reminderId))).getSingleOrNull();
    var version = confirmed?.version ?? 0;
    for (final row in rows) {
      if (row.state == OutboxState.acked && (row.ackVersion ?? 0) > version) {
        version = row.ackVersion!;
      }
    }
    return version;
  }

  Future<String?> _reminderHabit(String reminderId, List<OutboxRow> rows) async {
    final confirmed = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(reminderId))).getSingleOrNull();
    return confirmed?.habitId ?? rows.firstOrNull?.habitId;
  }

  /// Screen 18 "Discard": the user gives up a change the server would not take. Only rows in
  /// needs_attention qualify (they are never resubmitted automatically); the row moves to
  /// discarded_mutations in the same transaction, so the decision is recorded, not lost.
  /// Returns false when the row is gone or not in needs_attention.
  Future<bool> discard(String mutationId) {
    return db.transaction(() async {
      final row = await (db.select(
        db.outbox,
      )..where((o) => o.mutationId.equals(mutationId))).getSingleOrNull();
      if (row == null || row.state != OutboxState.needsAttention) return false;
      await db
          .into(db.discardedMutations)
          .insert(
            DiscardedMutationsCompanion.insert(
              mutationId: row.mutationId,
              entity: row.entity,
              entityId: row.entityId,
              operation: row.operation,
              payload: row.payload,
              localDateHint: Value(row.localDateHint),
              lastError: Value(row.lastError),
              discardedAt: clock().toUtc().millisecondsSinceEpoch,
            ),
          );
      await (db.delete(db.outbox)..where((o) => o.seq.equals(row.seq))).go();
      return true;
    });
  }

  /// Screen 18 "Try again": a blocked row becomes due now instead of after its backoff.
  Future<bool> retryNow(String mutationId) async {
    final updated =
        await (db.update(db.outbox)
              ..where((o) => o.mutationId.equals(mutationId) & o.state.equals(OutboxState.blocked)))
            .write(const OutboxCompanion(nextAttemptAt: Value(0)));
    return updated == 1;
  }

  /// The newest version this device has seen for the habit-day (confirmed or acked). Rows queued
  /// behind an unacknowledged one carry it only as a placeholder: the engine sends one row per
  /// habit-day at a time and rebases the next from the server's ack (F4). The client never
  /// predicts versions.
  int _baseVersion(ConfirmedLog? confirmed, List<OutboxRow> rows) {
    var version = confirmed?.version ?? 0;
    for (final row in rows) {
      if (row.state == OutboxState.acked && (row.ackVersion ?? 0) > version) {
        version = row.ackVersion!;
      }
    }
    return version;
  }

  Future<List<OutboxRow>> _rowsFor(String habitId, LocalDate date) =>
      (db.select(db.outbox)
            ..where(
              (o) =>
                  o.entity.equals('habit_log') &
                  o.habitId.equals(habitId) &
                  o.localDateHint.equals(date.toString()) &
                  o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  Future<ConfirmedLog?> _confirmedLog(String habitId, LocalDate date) =>
      (db.select(db.habitLogs)
            ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(date.toString()))
            ..orderBy([(l) => OrderingTerm.desc(l.version)])
            ..limit(1))
          .getSingleOrNull();

  Future<String> _append({
    required String entity,
    required String entityId,
    required String operation,
    required int? baseVersion,
    required AccountCalendar calendar,
    required LocalDate? localDate,
    required String? habitId,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  }) async {
    final mutationId = _uuid.v7();
    final now = clock().toUtc();
    final serverNow = calendar.now(now);
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            mutationId: mutationId,
            entity: entity,
            entityId: entityId,
            operation: operation,
            baseVersion: Value(baseVersion),
            occurredAt: _iso(occurredAt ?? serverNow),
            // A5: the habit-calendar zone in force at the event, never the device zone.
            capturedTimezone: Value(calendar.zoneAt(occurredAt ?? serverNow)),
            localDateHint: Value(localDate?.toString()),
            payload: jsonEncode(payload),
            habitId: Value(habitId),
            state: OutboxState.pending,
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
    return mutationId;
  }

  Future<AccountCalendar> _calendar() async {
    final calendar = await AccountCalendar.load(db, deviceNow: clock());
    if (calendar == null) {
      throw StateError('The server calendar is not known yet: sign in or sync first.');
    }
    return calendar;
  }

  static String _iso(DateTime t) {
    final utc = t.toUtc();
    final ms = utc.millisecond;
    final base = utc.toIso8601String().split('.').first;
    return ms == 0 ? '${base}Z' : '$base.${ms.toString().padLeft(3, '0')}Z';
  }
}

class LocalWrite {
  final String mutationId;
  final LocalDate date;
  final bool coalesced;

  const LocalWrite(this.mutationId, this.date, {required this.coalesced});
}
