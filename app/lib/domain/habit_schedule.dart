import 'calendar/local_date.dart';
import 'calendar/timezone_timeline.dart';

/// A frequency as stored (`frequency_type` + `frequency_config`). Mirrors the PHP `Frequency`.
/// An unknown type, or a config this version cannot read, is kept and schedules nothing
/// (invariant 13): the habit still shows, it is just never "due" locally.
class ScheduleFrequency {
  final String type;
  final List<int> days;
  final int count;
  final int everyNDays;
  final LocalDate? anchorDate;
  final bool known;

  const ScheduleFrequency._(
    this.type, {
    this.days = const [],
    this.count = 0,
    this.everyNDays = 0,
    this.anchorDate,
    this.known = true,
  });

  factory ScheduleFrequency.fromWire(Object? type, Object? config) {
    final c = config is Map ? config : const {};
    final t = type is String ? type : '';
    try {
      switch (t) {
        case 'daily':
          return ScheduleFrequency._(t);
        case 'weekdays':
          return ScheduleFrequency._(t, days: [for (final d in c['days'] as List) d as int]);
        case 'weekly_count':
          return ScheduleFrequency._(t, count: c['count'] as int);
        case 'interval':
          final every = c['every_n_days'] as int;
          if (every < 1) break;
          return ScheduleFrequency._(
            t,
            everyNDays: every,
            anchorDate: LocalDate.parse(c['anchor_date'] as String),
          );
      }
    } on Object {
      // Falls through: unreadable config.
    }
    return ScheduleFrequency._(t, known: false);
  }

  bool get isWeekly => known && type == 'weekly_count';

  /// For day-based schedules: is this local date a scheduled period?
  bool schedules(LocalDate date) {
    if (!known) return false;
    switch (type) {
      case 'daily':
        return true;
      case 'weekdays':
        return days.contains(date.isoWeekday);
      case 'interval':
        final anchor = anchorDate!;
        return !date.isBefore(anchor) && anchor.daysUntil(date) % everyNDays == 0;
    }
    return false;
  }
}

class ScheduleDefinition {
  final int version;
  final LocalDate effectiveDate;
  final ScheduleFrequency frequency;
  final Map<String, dynamic> wire;

  const ScheduleDefinition(this.version, this.effectiveDate, this.frequency, this.wire);
}

class ScheduleRange {
  final LocalDate startsOn;
  final LocalDate? endsBefore;

  const ScheduleRange(this.startsOn, this.endsBefore);

  bool contains(LocalDate date) =>
      !date.isBefore(startsOn) && (endsBefore == null || date.isBefore(endsBefore!));
}

/// A habit's due-ness per local date: the Dart port of the PHP `HabitSchedule` plus the period
/// grid of `PeriodEngine::periods` (pinned by contract-fixtures/domain/schedule.json).
///
/// - The definition governing a date is the latest whose effective date is on or before it.
/// - Daily, weekdays and interval: the date is its own period when its definition schedules it.
/// - weekly_count: Monday-Sunday weeks governed by the first active day's definition, due only
///   when at least `count` days are active (A28); every active day of a due week is due.
/// - Zero-length dates are never due (A30). Archived gaps are never due.
///
/// Due-ness decides what Today lists. It is never a streak, XP or freeze decision (invariant 9).
class HabitSchedule {
  final List<ScheduleDefinition> versions;
  final List<ScheduleRange> ranges;

  const HabitSchedule(this.versions, this.ranges);

  /// From a habit payload in wire form. A habit saved on this device but not yet confirmed has
  /// no `definitions` / `active_ranges`; they are derived from its flat fields.
  /// ASSUMPTION(A3.2-local-schedule): one definition effective on `start_local_date`, active
  /// from that date, and no active range while `archived_at` is set.
  factory HabitSchedule.fromWire(Map<String, dynamic> habit) {
    final versions = <ScheduleDefinition>[];
    final definitions = habit['definitions'];
    if (definitions is List && definitions.isNotEmpty) {
      for (final d in definitions) {
        if (d is! Map) continue;
        final date = _date(d['effective_date']);
        final version = d['version'];
        if (date == null || version is! int) continue;
        versions.add(
          ScheduleDefinition(
            version,
            date,
            ScheduleFrequency.fromWire(d['frequency_type'], d['frequency_config']),
            Map<String, dynamic>.from(d),
          ),
        );
      }
    } else {
      final start = _date(habit['start_local_date']);
      if (start != null) {
        versions.add(
          ScheduleDefinition(
            habit['definition_version'] is int ? habit['definition_version'] as int : 1,
            start,
            ScheduleFrequency.fromWire(habit['frequency_type'], habit['frequency_config']),
            {
              'type': habit['type'],
              'target_value': habit['target_value'],
              'unit': habit['unit'],
              'frequency_type': habit['frequency_type'],
              'frequency_config': habit['frequency_config'],
            },
          ),
        );
      }
    }
    versions.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    final ranges = <ScheduleRange>[];
    final activeRanges = habit['active_ranges'];
    if (activeRanges is List) {
      for (final r in activeRanges) {
        if (r is! Map) continue;
        final starts = _date(r['starts_on']);
        if (starts == null) continue;
        ranges.add(ScheduleRange(starts, _date(r['ends_before'])));
      }
    } else if (habit['archived_at'] == null) {
      final start = _date(habit['start_local_date']);
      if (start != null) ranges.add(ScheduleRange(start, null));
    }
    ranges.sort((a, b) => a.startsOn.compareTo(b.startsOn));
    return HabitSchedule(versions, ranges);
  }

  static LocalDate? _date(Object? value) {
    if (value is! String) return null;
    try {
      return LocalDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// The definition governing [date], or null before the habit's first version.
  ScheduleDefinition? versionOn(LocalDate date) {
    ScheduleDefinition? found;
    for (final v in versions) {
      if (!v.effectiveDate.isAfter(date)) found = v;
    }
    return found;
  }

  bool isActive(LocalDate date) => ranges.any((r) => r.contains(date));

  /// Active and governed by a definition: the date can take part in a period.
  bool isEligible(LocalDate date) => isActive(date) && versionOn(date) != null;

  /// The key of the period [date] is due in (`d:YYYY-MM-DD` or `w:<Monday>`), or null when the
  /// date is not due. Without a [timeline] no date is treated as zero-length.
  String? periodKeyOn(LocalDate date, [TimezoneTimeline? timeline]) {
    bool exists(LocalDate d) => timeline == null || !timeline.isZeroLength(d);
    final definition = versionOn(date);
    if (definition == null || !isActive(date) || !exists(date)) return null;

    final monday = date.addDays(1 - date.isoWeekday);
    final active = [
      for (var i = 0; i < 7; i++)
        if (isEligible(monday.addDays(i)) && exists(monday.addDays(i))) monday.addDays(i),
    ];
    final weekDefinition = active.isEmpty ? null : versionOn(active.first);
    if (weekDefinition != null &&
        weekDefinition.frequency.isWeekly &&
        active.length >= weekDefinition.frequency.count) {
      return 'w:$monday';
    }
    if (!definition.frequency.isWeekly && definition.frequency.schedules(date)) {
      return 'd:$date';
    }
    return null;
  }

  bool isDue(LocalDate date, [TimezoneTimeline? timeline]) => periodKeyOn(date, timeline) != null;

  /// The weekly count governing [date]'s week, or null when that week is not weekly.
  int? weeklyCountOn(LocalDate date) {
    final definition = versionOn(date);
    return definition != null && definition.frequency.isWeekly ? definition.frequency.count : null;
  }
}
