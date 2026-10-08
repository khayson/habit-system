import 'package:drift/drift.dart';

import 'app_database.dart';

/// Keeps `calendar_entries` in step with the user entity's `calendar_history` (A26, D1). Pure
/// Dart. The server sends only its last ten entries, so this merges rather than replaces:
/// - every entry present is inserted or replaced (keyed by effective_at);
/// - a local PENDING entry (effective after [now]) the server no longer lists was replaced or
///   cancelled, so it goes;
/// - settled entries are never deleted, except that entries settled more than [keep] ago are
///   pruned down to the newest of them (it still governs the dates after it).
///
/// Without `calendar_history` (an older payload) nothing changes here; AccountCalendar then
/// falls back to the single entry in sync_state.
Future<void> mergeCalendarHistory(
  AppDatabase db,
  Map<String, dynamic> user, {
  required DateTime now,
  Duration keep = const Duration(days: 120),
}) async {
  final history = user['calendar_history'];
  if (history is! List) return;
  final nowMs = now.toUtc().millisecondsSinceEpoch;
  final listed = <int>{};
  for (final item in history) {
    if (item is! Map) continue;
    final at = DateTime.tryParse('${item['effective_at']}');
    final zone = item['timezone'];
    final offset = item['day_start_offset_minutes'];
    if (at == null || zone is! String) continue;
    final ms = at.toUtc().millisecondsSinceEpoch;
    listed.add(ms);
    await db
        .into(db.calendarEntries)
        .insertOnConflictUpdate(
          CalendarEntriesCompanion.insert(
            effectiveAt: Value(ms),
            timezone: zone,
            dayStartOffsetMinutes: Value(offset is int ? offset : 0),
          ),
        );
  }
  if (listed.isEmpty) return;

  await (db.delete(
    db.calendarEntries,
  )..where((e) => e.effectiveAt.isBiggerThanValue(nowMs) & e.effectiveAt.isNotIn(listed))).go();

  final cutoff = nowMs - keep.inMilliseconds;
  final old =
      await (db.select(db.calendarEntries)
            ..where((e) => e.effectiveAt.isSmallerOrEqualValue(cutoff))
            ..orderBy([(e) => OrderingTerm.desc(e.effectiveAt)]))
          .get();
  if (old.length > 1) {
    await (db.delete(
      db.calendarEntries,
    )..where((e) => e.effectiveAt.isIn(old.skip(1).map((e) => e.effectiveAt)))).go();
  }
}
