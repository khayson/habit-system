import 'local_date.dart';
import 'timezone_timeline.dart';

/// The app's clock: always UTC.
typedef Clock = DateTime Function();

class DayResolution {
  final LocalDate localDate;
  final CalendarEntry entry;

  /// null when no hint was given; false when the timeline overrode it.
  final bool? hintMatches;

  const DayResolution(this.localDate, this.entry, this.hintMatches);
}

/// Dart port of the server's `DayResolver`. The client uses it for "today" and for
/// `local_date_hint` only; the server still decides every date (invariant 3).
class DayResolver {
  static const int futureToleranceSeconds = 300;
  static const int maxOfflineAgeSeconds = 90 * 86400;
  static const int maxBackdateDays = 30;

  final TimezoneTimeline timeline;
  final Clock clock;

  const DayResolver(this.timeline, this.clock);

  DayResolution resolve(DateTime occurredAt, {String? capturedTimezone, LocalDate? localDateHint}) {
    final entry = timeline.entryAt(occurredAt);
    final now = clock().toUtc();

    if (occurredAt.isAfter(now.add(const Duration(seconds: futureToleranceSeconds)))) {
      throw const DayResolutionException('future_event');
    }
    if (occurredAt.isBefore(now.subtract(const Duration(seconds: maxOfflineAgeSeconds)))) {
      throw const DayResolutionException('event_too_old');
    }

    final date = timeline.localDateAt(occurredAt);

    // A29: a different captured zone is fine when the date already agrees with the timeline.
    if (capturedTimezone != null &&
        capturedTimezone != entry.timezone &&
        (localDateHint == null || localDateHint != date)) {
      throw DayResolutionException('timezone_context_mismatch', entry: entry);
    }

    return DayResolution(date, entry, localDateHint == null ? null : localDateHint == date);
  }

  LocalDate today() => timeline.localDateAt(clock().toUtc());

  /// [at] is a log's occurred_at: "today" is the user's local date then (default: now).
  void validateBackdate(LocalDate date, {DateTime? at}) {
    final today = at == null ? this.today() : timeline.localDateAt(at);
    if (date.isAfter(today)) throw const DayResolutionException('backdate_future');
    if (date.daysUntil(today) > maxBackdateDays) {
      throw const DayResolutionException('backdate_too_old');
    }
  }
}
