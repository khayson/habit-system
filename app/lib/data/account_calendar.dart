import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart';
import 'app_database.dart';

/// The account's habit calendar as this device knows it: the calendar history the server
/// published (A26, D1; settled entries and at most one pending change) and the server-time
/// correction (F10). Pure Dart.
///
/// The server still decides every date. This only makes the client stamp `occurred_at`, show
/// "today" and draw day boundaries on the server's calendar and clock, so a pending zone change
/// takes effect at its boundary without waiting for a sync.
class AccountCalendar {
  final TimezoneTimeline timeline;

  /// Server time minus device time.
  final Duration skew;

  const AccountCalendar({required this.timeline, required this.skew});

  /// Null until the account's calendar is known (sign-in or a first sync).
  ///
  /// Uses `calendar_entries` when present; otherwise the single entry in sync_state (an older
  /// server payload without `calendar_history`). A history that does not form a valid timeline
  /// falls back to its settled entries and records `calendar_invalid`; it never crashes.
  static Future<AccountCalendar?> load(AppDatabase db, {DateTime? deviceNow}) async {
    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingleOrNull();
    if (state == null) return null;
    final skew = Duration(milliseconds: state.clockSkewMs);
    final serverNow = (deviceNow ?? DateTime.now()).toUtc().add(skew);

    final rows = await (db.select(
      db.calendarEntries,
    )..orderBy([(e) => OrderingTerm.asc(e.effectiveAt)])).get();
    final entries = [
      for (final r in rows)
        CalendarEntry(
          DateTime.fromMillisecondsSinceEpoch(r.effectiveAt, isUtc: true),
          r.timezone,
          r.dayStartOffsetMinutes,
        ),
    ];

    if (entries.isNotEmpty) {
      try {
        return AccountCalendar(timeline: TimezoneTimeline(entries), skew: skew);
      } on ArgumentError {
        await _recordInvalid(db, state);
        final settled = entries.where((e) => !e.effectiveAt.isAfter(serverNow)).toList();
        try {
          if (settled.isNotEmpty) {
            return AccountCalendar(timeline: TimezoneTimeline(settled), skew: skew);
          }
        } on ArgumentError {
          // fall through to the single entry below
        }
      }
    }

    final zone = state.calendarTimezone;
    if (zone == null) return null;
    final entry = CalendarEntry(
      DateTime.tryParse(state.calendarEffectiveAt ?? '') ?? DateTime.utc(1970),
      zone,
      state.calendarDayStartOffset,
    );
    return AccountCalendar(timeline: TimezoneTimeline([entry]), skew: skew);
  }

  static Future<void> _recordInvalid(AppDatabase db, SyncStateRow state) async {
    final current = state.lastError == null ? null : jsonDecode(state.lastError!);
    if (current is Map && current['code'] == 'calendar_invalid') return; // no write loop
    await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
      SyncStateCompanion(
        lastError: Value(
          jsonEncode({
            'code': 'calendar_invalid',
            'message': 'The calendar history was not valid.',
          }),
        ),
      ),
    );
  }

  /// [deviceNow] corrected to the server's clock.
  DateTime now(DateTime deviceNow) => deviceNow.toUtc().add(skew);

  /// The habit-calendar zone in force at an instant (sent as `captured_timezone`, A5).
  String zoneAt(DateTime instant) => timeline.entryAt(instant).timezone;

  /// The zone in force now on the server's clock.
  String zoneNow(DateTime deviceNow) => zoneAt(now(deviceNow));

  /// A calendar change that has not taken effect yet (at most one), or null.
  CalendarEntry? pendingAfter(DateTime deviceNow) {
    final at = now(deviceNow);
    for (final e in timeline.entries) {
      if (e.effectiveAt.isAfter(at)) return e;
    }
    return null;
  }

  /// The habit-day of the corrected [deviceNow].
  LocalDate today(DateTime deviceNow) => timeline.localDateAt(now(deviceNow));

  /// Wall-clock time in the zone in force (for display, e.g. the greeting), corrected.
  DateTime localNow(DateTime deviceNow) {
    final at = now(deviceNow);
    return tz.TZDateTime.from(at, tz.getLocation(zoneAt(at)));
  }
}
