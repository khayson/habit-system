import 'package:timezone/timezone.dart' as tz;

import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart';
import 'app_database.dart';

/// The account's habit calendar as this device knows it: the server's calendar entry (A5) and
/// the server-time correction (F10). Pure Dart.
///
/// The server still decides every date. This only makes the client stamp `occurred_at` and show
/// "today" on the server's clock, so a phone running fast is not refused as `future_event`.
class AccountCalendar {
  /// The habit-calendar zone the server holds (sent as `captured_timezone`), never the device's.
  final String timezone;
  final TimezoneTimeline timeline;

  /// Server time minus device time.
  final Duration skew;

  const AccountCalendar({required this.timezone, required this.timeline, required this.skew});

  /// Null until the account's calendar is known (sign-in or a first sync).
  static Future<AccountCalendar?> load(AppDatabase db) async {
    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingleOrNull();
    final zone = state?.calendarTimezone;
    if (state == null || zone == null) return null;
    final entry = CalendarEntry(
      DateTime.tryParse(state.calendarEffectiveAt ?? '') ?? DateTime.utc(1970),
      zone,
      state.calendarDayStartOffset,
    );
    return AccountCalendar(
      timezone: zone,
      timeline: TimezoneTimeline([entry]),
      skew: Duration(milliseconds: state.clockSkewMs),
    );
  }

  /// [deviceNow] corrected to the server's clock.
  DateTime now(DateTime deviceNow) => deviceNow.toUtc().add(skew);

  /// The habit-day of the corrected [deviceNow].
  LocalDate today(DateTime deviceNow) => timeline.localDateAt(now(deviceNow));

  /// Wall-clock time in the calendar zone (for display, e.g. the greeting), corrected.
  DateTime localNow(DateTime deviceNow) =>
      tz.TZDateTime.from(now(deviceNow), tz.getLocation(timezone));
}
