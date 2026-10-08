import 'package:timezone/timezone.dart' as tz;

import 'local_date.dart';

/// Loads the bundled IANA database once. The app never uses `DateTime.local` or the device
/// zone for habit dates.
bool _timeZonesLoaded = false;

void ensureTimeZonesLoaded(void Function() loader) {
  if (_timeZonesLoaded) return;
  loader();
  _timeZonesLoaded = true;
}

/// Why a date could not be resolved: no_calendar, future_event, event_too_old,
/// timezone_context_mismatch, backdate_future, backdate_too_old (same codes as the server).
class DayResolutionException implements Exception {
  final String reason;

  /// For timezone_context_mismatch: the calendar entry in force at the event (A29).
  final CalendarEntry? entry;

  const DayResolutionException(this.reason, {this.entry});

  @override
  String toString() => 'DayResolutionException($reason)';
}

/// One row of the user's calendar history: from [effectiveAt] on, habit days use [timezone]
/// and start [dayStartOffsetMinutes] after local midnight (A22).
class CalendarEntry {
  static const int maxDayStartOffsetMinutes = 360;

  final DateTime effectiveAt;
  final String timezone;
  final int dayStartOffsetMinutes;
  final tz.Location location;

  CalendarEntry(DateTime effectiveAt, this.timezone, [this.dayStartOffsetMinutes = 0])
    : effectiveAt = effectiveAt.toUtc(),
      location = _location(timezone) {
    if (dayStartOffsetMinutes < 0 || dayStartOffsetMinutes > maxDayStartOffsetMinutes) {
      throw ArgumentError.value(dayStartOffsetMinutes, 'dayStartOffsetMinutes', 'must be 0..360');
    }
  }

  static tz.Location _location(String timezone) {
    try {
      return tz.getLocation(timezone);
    } on tz.LocationNotFoundException {
      throw ArgumentError.value(timezone, 'timezone', 'not an IANA time zone');
    }
  }
}

/// A user's ordered calendar history. A Dart port of the server's `TimezoneTimeline`, pinned by
/// the same contract-fixtures/domain/day_resolution.json:
/// - day start: the first instant whose wall clock shows 00:00 + offset; inside a DST gap, the
///   transition instant;
/// - event date: the latest local date whose start is at or before the instant, under the entry
///   in force at that instant (the first entry governs earlier instants). Dates never go backwards;
/// - a date's start uses the latest entry effective at or before that start (A26);
/// - monotonic (A26, D1): construction fails if a change would move a date backwards. A change
///   may skip dates forwards (a zero-length date, A30).
class TimezoneTimeline {
  final List<CalendarEntry> entries;

  TimezoneTimeline(List<CalendarEntry> entries) : entries = List.unmodifiable(entries) {
    for (var i = 1; i < entries.length; i++) {
      if (!entries[i].effectiveAt.isAfter(entries[i - 1].effectiveAt)) {
        throw ArgumentError('Calendar entries must have strictly increasing effective_at.');
      }
      final at = entries[i].effectiveAt;
      final before = _dateUnder(entries[i - 1], at.subtract(const Duration(seconds: 1)));
      final after = _dateUnder(entries[i], at);
      if (after.isBefore(before)) {
        throw ArgumentError(
          'Calendar change at $at would move dates backwards ($before to $after).',
        );
      }
    }
  }

  CalendarEntry entryAt(DateTime instant) {
    if (entries.isEmpty) throw const DayResolutionException('no_calendar');
    var found = entries.first;
    for (final entry in entries) {
      if (!entry.effectiveAt.isAfter(instant)) found = entry;
    }
    return found;
  }

  LocalDate localDateAt(DateTime instant) => _dateUnder(entryAt(instant), instant);

  /// A date with no instants (skipped by a calendar change or the zone itself); not part of the
  /// period grid (A30).
  bool isZeroLength(LocalDate date) => localDateAt(startOfLocalDay(date)).isAfter(date);

  static LocalDate _dateUnder(CalendarEntry entry, DateTime instant) {
    final ms = instant.millisecondsSinceEpoch;
    final offsetMs = entry.location.timeZone(ms).offset.inMilliseconds;
    final date = LocalDate.ofWallClockMillis(
      ms + offsetMs - entry.dayStartOffsetMinutes * Duration.millisecondsPerMinute,
    );

    // The wall-clock guess can be off by one inside DST gaps and repeats; boundaries decide.
    if (_startFor(date.addDays(1), entry) <= ms) return date.addDays(1);
    if (_startFor(date, entry) > ms) return date.addDays(-1);
    return date;
  }

  /// H1: the first instant whose date is this date or later. Inside entry i's interval
  /// [effective_i, effective_i+1) that is the later of the interval start and the entry's own day
  /// start; the first interval containing it wins. Holds for changes of 24 hours or more.
  DateTime startOfLocalDay(LocalDate date) {
    if (entries.isEmpty) throw const DayResolutionException('no_calendar');
    for (var i = 0; i < entries.length; i++) {
      var start = _startFor(date, entries[i]);
      final from = entries[i].effectiveAt.millisecondsSinceEpoch;
      if (i > 0 && start < from) start = from;
      if (i == entries.length - 1 || start < entries[i + 1].effectiveAt.millisecondsSinceEpoch) {
        return _utc(start);
      }
    }
    throw const DayResolutionException('no_calendar');
  }

  DateTime endOfLocalDay(LocalDate date) => startOfLocalDay(date.addDays(1));

  static DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static int _startFor(LocalDate date, CalendarEntry entry) => _firstInstantOfWallTime(
    date.midnightMillis + entry.dayStartOffsetMinutes * Duration.millisecondsPerMinute,
    entry.location,
  );

  /// Earliest instant whose wall clock in [location] reads [wallMillis]; inside a DST gap, the
  /// transition instant. Resolved from the transition table, never from a parser's guess.
  static int _firstInstantOfWallTime(int wallMillis, tz.Location location) {
    const window = 2 * Duration.millisecondsPerDay;
    final intervals = <tz.TzInstant>[];
    var t = wallMillis - window;
    while (t <= wallMillis + window) {
      final interval = location.lookupTimeZone(t);
      intervals.add(interval);
      if (interval.end <= t) break;
      t = interval.end;
    }

    final candidates = <int>[];
    for (final interval in intervals) {
      final instant = wallMillis - interval.timeZone.offset.inMilliseconds;
      if (instant >= interval.start && instant < interval.end) candidates.add(instant);
    }

    if (candidates.isEmpty) {
      // Gap: the wall time is skipped. Use the transition whose skipped range contains it.
      for (var i = 0; i + 1 < intervals.length; i++) {
        final boundary = intervals[i].end;
        final before = boundary + intervals[i].timeZone.offset.inMilliseconds;
        final after = boundary + intervals[i + 1].timeZone.offset.inMilliseconds;
        if (before <= wallMillis && wallMillis < after) candidates.add(boundary);
      }
    }

    if (candidates.isEmpty) {
      throw StateError('Cannot resolve wall time $wallMillis in ${location.name}');
    }
    return candidates.reduce((a, b) => a < b ? a : b);
  }
}
