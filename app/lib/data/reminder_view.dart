import 'dart:convert';

import 'package:drift/drift.dart';

import '../sync/outbox_states.dart';
import 'entity_codec.dart';
import 'local_view.dart';

/// Reminders as this device intends them (Phase 3.2b): confirmed rows with the pending
/// reminder.* rows applied in order. Reminders fire on this device, so a pending edit is
/// scheduled at once; the confirmed rows still hold only what the server said (invariant 9).
extension ReminderQueries on LocalView {
  Stream<List<ReminderView>> watchReminders() => db
      .customSelect(
        "SELECT r.id, r.version FROM reminders r UNION ALL "
        "SELECT o.entity_id, o.seq FROM outbox o WHERE o.entity = 'reminder'",
        readsFrom: {db.reminders, db.outbox},
      )
      .watch()
      .asyncMap((_) => reminders());

  Future<List<ReminderView>> reminders() async {
    final views = <String, ReminderView>{
      for (final row in await db.select(db.reminders).get())
        row.id: ReminderView.fromPayload(EntityCodec.reminderPayload(row), syncState: null),
    };
    final rows =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.entity.equals('reminder') &
                    o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();
    for (final row in rows) {
      final confirmed = views[row.entityId];
      if (row.state == OutboxState.acked &&
          confirmed != null &&
          confirmed.syncState == null &&
          (row.ackVersion ?? 0) <= confirmed.version) {
        continue; // already reflected in the confirmed row
      }
      final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
      final base = confirmed?.payload ?? {'id': row.entityId, 'habit_id': row.habitId};
      views[row.entityId] = ReminderView.fromPayload({
        ...base,
        if (row.operation == 'reminder.delete')
          'deleted_at': row.occurredAt
        else ...{
          ...payload,
          'deleted_at': null,
        },
      }, syncState: row.state);
    }
    return views.values.where((v) => !v.deleted).toList()..sort((a, b) => a.id.compareTo(b.id));
  }
}

class ReminderView {
  final Map<String, dynamic> payload;

  /// null when nothing is pending for it; otherwise the newest outbox state.
  final String? syncState;

  const ReminderView(this.payload, {required this.syncState});

  factory ReminderView.fromPayload(Map<String, dynamic> p, {required String? syncState}) =>
      ReminderView(p, syncState: syncState);

  String get id => payload['id'] as String;
  String? get habitId => payload['habit_id'] as String?;
  String get localTime => payload['local_time'] as String? ?? '';
  List<int> get daysOfWeek => [
    for (final d in (payload['days_of_week'] as List?) ?? const []) d as int,
  ];
  String get timezoneMode => payload['timezone_mode'] as String? ?? 'habit_zone';
  String? get timezone => payload['timezone'] as String?;
  bool get enabled => payload['enabled'] as bool? ?? true;
  int get version => payload['version'] as int? ?? 0;
  bool get deleted => payload['deleted_at'] != null;
  bool get provisional => syncState != null;
}
