import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/provisional_type_rules.dart';
import '../sync/outbox_states.dart';
import 'app_database.dart';
import 'entity_codec.dart';

/// One habit-day as this device shows it: the confirmed log with every queued intent laid over
/// it, in outbox order (invariant 9: computed, never written into the confirmed row).
class LogOverlay {
  final Object? value;
  final bool deleted;

  /// The newest applied row's outbox state; null when nothing queued shows.
  final String? syncState;
  final DateTime? changedAt;

  const LogOverlay({
    required this.value,
    required this.deleted,
    required this.syncState,
    required this.changedAt,
  });
}

/// The ONE place queued log rows are applied (4.3a A4). Every reader (the day's log, Today, the
/// week, history and the heatmap, the reminder planner) and the writer's own checks go through
/// it, so they can never disagree.
///
/// Rows already reflected in the confirmed log (acked at or below its version) are skipped.
/// log.set_value sets, log.delete deletes, log.increment adds with the type's own rule (A35); a
/// delta the rules refuse, an unknown type, or an increment on a deleted day changes nothing.
/// Unknown operations are ignored (A21). A row in needs_attention still shows, as set_value rows
/// always have.
LogOverlay applyLogRows({
  required ConfirmedLog? confirmed,
  required List<OutboxRow> rows,
  required ProvisionalTypeRules? rules,
}) {
  Object? value = EntityCodec.decodeJson(confirmed?.value);
  var deleted = confirmed?.deletedAt != null;
  String? state;
  var changedAt = DateTime.tryParse(confirmed?.completedAt ?? confirmed?.occurredAt ?? '');
  for (final row in rows) {
    final reflected =
        row.state == OutboxState.acked && (row.ackVersion ?? 0) <= (confirmed?.version ?? 0);
    if (reflected) continue;
    final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
    switch (row.operation) {
      case 'log.set_value':
        value = payload['value'];
        deleted = false;
      case 'log.delete':
        deleted = true;
      case 'log.increment':
        if (deleted || rules == null) continue;
        final next = rules.increment(rules.parseValue(value) ?? 0, payload['delta']);
        if (next == null) continue;
        value = rules.formatValue(next);
      default:
        continue;
    }
    state = row.state;
    changedAt = DateTime.tryParse(row.occurredAt);
  }
  return LogOverlay(
    value: deleted ? null : value,
    deleted: deleted,
    syncState: state,
    changedAt: changedAt,
  );
}

/// A habit's type key as this device knows it: the confirmed row's, else its queued
/// habit.create's; null for a habit it has never seen.
Future<String?> habitTypeOf(AppDatabase db, String habitId) async {
  final confirmed = await (db.select(
    db.habits,
  )..where((h) => h.id.equals(habitId))).getSingleOrNull();
  if (confirmed != null) return confirmed.type;
  final create =
      await (db.select(db.outbox)
            ..where(
              (o) =>
                  o.entity.equals('habit') &
                  o.entityId.equals(habitId) &
                  o.operation.equals('habit.create'),
            )
            ..limit(1))
          .getSingleOrNull();
  if (create == null) return null;
  return (jsonDecode(create.payload) as Map)['type'] as String?;
}
