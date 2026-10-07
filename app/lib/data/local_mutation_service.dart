import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/day_resolver.dart';
import '../domain/calendar/local_date.dart';
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
  Future<LocalWrite> setLogValue({required String habitId, required Object value, DateTime? at}) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final occurredAt = (at ?? calendar.now(clock())).toUtc();
      final date = calendar.timeline.localDateAt(occurredAt);
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
        payload: {'habit_id': habitId, 'value': value},
      );
      return LocalWrite(mutationId, date, coalesced: false);
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
    required String habitId,
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
            // A5: the habit-calendar zone the server holds, never the device zone.
            capturedTimezone: Value(calendar.timezone),
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
    final calendar = await AccountCalendar.load(db);
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
