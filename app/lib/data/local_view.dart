import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/provisional_type_rules.dart';
import '../sync/outbox_states.dart';
import 'app_database.dart';
import 'entity_codec.dart';

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
    }

    return LogView(
      habitId: habitId,
      date: date,
      value: deleted ? null : value,
      deleted: deleted,
      confirmedVersion: confirmed?.version,
      syncState: state,
    );
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

  const LogView({
    required this.habitId,
    required this.date,
    required this.value,
    required this.deleted,
    required this.confirmedVersion,
    required this.syncState,
  });

  bool get provisional => syncState != null;
}
