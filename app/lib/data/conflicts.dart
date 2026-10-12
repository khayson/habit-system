import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/calendar/local_date.dart';
import '../domain/habit_draft.dart';
import '../sync/outbox_states.dart';
import 'app_database.dart';
import 'entity_codec.dart';
import 'local_view.dart';
import 'log_overlay.dart';

/// A37: what kind of look a needs_attention row needs (screen 19, Phase 4.3b).
enum ConflictKind {
  /// version_conflict on a log row: the day changed on the server.
  staleValue,

  /// resource_deleted: the day was deleted on another device.
  deletedDay,

  /// habit_archived: the habit was archived when the change arrived.
  archivedHabit,

  /// version_conflict on a habit edit.
  staleHabitEdit,

  /// Anything else, an unknown type, or an unreadable answer: discard only.
  other,
}

/// The three codes A37 allows "use mine" for.
const resolvableCodes = {'version_conflict', 'resource_deleted', 'habit_archived'};

/// A37 USE MINE, decided once for the read model and the writer: the new row's base version,
/// entity id, operation and payload, or null when only discarding is allowed.
class UseMinePlan {
  final int? baseVersion;
  final String entityId;
  final String operation;
  final Map<String, Object?> payload;

  const UseMinePlan({
    required this.baseVersion,
    required this.entityId,
    required this.operation,
    required this.payload,
  });

  /// [habitActive]: the habit shows active on this device (only habit_archived asks).
  static UseMinePlan? of(OutboxRow row, {required bool habitActive}) {
    if (row.state != OutboxState.needsAttention) return null;
    final error = EntityCodec.decodeJson(row.lastError);
    if (error is! Map) return null;
    final code = error['code'];
    if (!resolvableCodes.contains(code)) return null;
    final payload = (jsonDecode(row.payload) as Map).cast<String, Object?>();
    if (code == 'habit_archived') {
      if (!habitActive) return null;
      return UseMinePlan(
        baseVersion: row.baseVersion,
        entityId: row.entityId,
        operation: row.operation,
        payload: payload,
      );
    }
    // 4.3c A2: removing a day that is already gone leaves nothing to decide.
    if (code == 'resource_deleted' && row.operation == 'log.delete') return null;
    final current = error['current'];
    final version = (current is Map ? current['version'] : null) ?? error['current_version'];
    if (version is! int) return null;
    if (code == 'resource_deleted' && row.operation == 'log.increment') {
      // A37 (1): adding to a deleted day restores it with the amount: a set_value on the
      // tombstone's version (A29).
      final resource = error['resource_id'];
      return UseMinePlan(
        baseVersion: version,
        entityId: resource is String ? resource : row.entityId,
        operation: 'log.set_value',
        payload: {
          'habit_id': payload['habit_id'],
          'value': payload['delta'],
          if (payload.containsKey('date_mode')) 'date_mode': payload['date_mode'],
          if (payload.containsKey('log_date')) 'log_date': payload['log_date'],
        },
      );
    }
    return UseMinePlan(
      baseVersion: version,
      entityId: row.entityId,
      operation: row.operation,
      payload: payload,
    );
  }
}

/// A37 read model of one needs_attention row (screen 19 reads it in 4.3b).
class ConflictView {
  final String mutationId;
  final ConflictKind kind;
  final String? habitId;
  final String? habitName;

  /// The habit-day, for log rows; null for habit rows.
  final LocalDate? localDate;
  final String operation;

  /// What the person wrote. A log row: the value (set_value) or the amount (increment) in the
  /// type's units, and in wire form. A habit row: the draft.
  final int? mineUnits;
  final Object? mineWire;
  final HabitDraft? mineHabit;
  final int? baseVersion;
  final DateTime? occurredAt;

  /// What the server has, only as far as its answer carries it; null otherwise.
  final Object? serverValue;
  final int? serverValueUnits;
  final int? serverVersion;
  final bool serverDeleted;
  final HabitDraft? serverHabit;
  final bool canUseMine;

  const ConflictView({
    required this.mutationId,
    required this.kind,
    required this.habitId,
    required this.habitName,
    required this.localDate,
    required this.operation,
    required this.mineUnits,
    required this.mineWire,
    required this.mineHabit,
    required this.baseVersion,
    required this.occurredAt,
    required this.serverValue,
    required this.serverValueUnits,
    required this.serverVersion,
    required this.serverDeleted,
    required this.serverHabit,
    required this.canUseMine,
  });
}

/// A37: needs_attention rows as conflicts, from local data only.
extension ConflictQueries on LocalView {
  Stream<List<ConflictView>> watchConflicts() => db
      .customSelect('SELECT 1', readsFrom: {db.outbox, db.habits})
      .watch()
      .asyncMap((_) => conflicts());

  Future<List<ConflictView>> conflicts() async {
    final rows =
        await (db.select(db.outbox)
              ..where((o) => o.state.equals(OutboxState.needsAttention))
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();
    final habits = {for (final h in await this.habits()) h.id: h};
    return [for (final row in rows) await _conflictOf(row, habits)];
  }

  Future<ConflictView?> conflict(String mutationId) async {
    final row = await (db.select(
      db.outbox,
    )..where((o) => o.mutationId.equals(mutationId))).getSingleOrNull();
    if (row == null || row.state != OutboxState.needsAttention) return null;
    final habits = {for (final h in await this.habits()) h.id: h};
    return _conflictOf(row, habits);
  }

  Future<ConflictView> _conflictOf(OutboxRow row, Map<String, HabitView> habits) async {
    final isLog = row.entity == 'habit_log';
    final isHabit = row.entity == 'habit';
    final habitId = isLog ? row.habitId : (isHabit ? row.entityId : null);
    final habit = habitId == null ? null : habits[habitId];
    final rules = habitId == null ? null : types.lookup(await habitTypeOf(db, habitId) ?? '');
    final error = EntityCodec.decodeJson(row.lastError);
    final code = error is Map ? error['code'] : null;
    final current = error is Map && error['current'] is Map
        ? (error['current'] as Map).cast<String, dynamic>()
        : null;
    final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
    final mineWire = isLog
        ? (row.operation == 'log.increment' ? payload['delta'] : payload['value'])
        : null;

    var kind = switch ((code, row.entity)) {
      ('version_conflict', 'habit_log') => ConflictKind.staleValue,
      ('version_conflict', 'habit') => ConflictKind.staleHabitEdit,
      ('resource_deleted', 'habit_log') => ConflictKind.deletedDay,
      ('habit_archived', _) => ConflictKind.archivedHabit,
      _ => ConflictKind.other,
    };
    // An unknown type, or an answer the app cannot read, can only be discarded.
    if (habitId != null && rules == null && habit?.knownType != true) kind = ConflictKind.other;
    if (kind == ConflictKind.staleValue && current == null) kind = ConflictKind.other;
    final plan = kind == ConflictKind.other
        ? null
        : UseMinePlan.of(row, habitActive: habit != null && !habit.archived);

    final serverVersion =
        (current?['version'] as int?) ?? (error is Map ? error['current_version'] as int? : null);
    final serverValue = isLog && current != null && current.containsKey('value')
        ? current['value']
        : null;
    return ConflictView(
      mutationId: row.mutationId,
      kind: kind,
      habitId: habitId,
      habitName: habit?.payload['name'] as String?,
      localDate: row.localDateHint == null ? null : LocalDate.parse(row.localDateHint!),
      operation: row.operation,
      mineUnits: rules?.parseValue(mineWire),
      mineWire: mineWire,
      mineHabit: isHabit && row.operation == 'habit.update' ? HabitDraft.fromWire(payload) : null,
      baseVersion: row.baseVersion,
      occurredAt: DateTime.tryParse(row.occurredAt),
      serverValue: serverValue,
      serverValueUnits: rules?.parseValue(serverValue),
      serverVersion: serverVersion,
      serverDeleted: current?['deleted_at'] != null || code == 'resource_deleted',
      serverHabit: isHabit && current != null && current.containsKey('name')
          ? HabitDraft.fromWire(current)
          : null,
      canUseMine: plan != null,
    );
  }
}
