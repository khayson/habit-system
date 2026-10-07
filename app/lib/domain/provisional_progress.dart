import 'provisional_type_rules.dart';

/// Locally computed progress. Always provisional: shown as "saved on this device" until the
/// server confirms it, and stored apart from server-confirmed values (invariant 9).

/// One habit-day against its target.
class ProvisionalDayProgress {
  final int value;
  final int target;
  final bool complete;

  const ProvisionalDayProgress({required this.value, required this.target, required this.complete});
}

/// A habit as Today sees it. `type`, `target` and `value` are kept in wire form so unknown
/// types pass through untouched.
class TodayHabit {
  final String id;
  final String type;
  final Object? target;
  final Object? value;

  const TodayHabit({required this.id, required this.type, required this.target, this.value});
}

class TodaySummary {
  final int complete;

  /// Habits this app version can evaluate. Unknown types are excluded from the denominator.
  final int total;

  /// Habits of types this app version does not know (preserved, shown as update cards).
  final int unknown;

  const TodaySummary({required this.complete, required this.total, required this.unknown});
}

/// Distinct completed local days in a Monday-Sunday week against the weekly count.
class ProvisionalWeekProgress {
  final int distinctCompletedDays;
  final int targetDays;

  const ProvisionalWeekProgress({required this.distinctCompletedDays, required this.targetDays});

  bool get complete => distinctCompletedDays >= targetDays;

  /// Below target. The app never calls a week missed: closure is the server's decision.
  bool get pending => !complete;
}

class ProvisionalProgress {
  final ProvisionalTypeRegistry types;

  ProvisionalProgress([ProvisionalTypeRegistry? types])
    : types = types ?? ProvisionalTypeRegistry.builtins();

  /// Null when the type is unknown or the values are malformed: callers show the raw data.
  ProvisionalDayProgress? day({required String type, required Object? target, Object? value}) {
    final rules = types.lookup(type);
    if (rules == null) return null;
    final t = rules.parseTarget(target);
    final v = value == null ? 0 : rules.parseValue(value);
    if (t == null || v == null) return null;
    return ProvisionalDayProgress(value: v, target: t, complete: rules.isComplete(v, t));
  }

  TodaySummary today(Iterable<TodayHabit> habits) {
    var complete = 0;
    var total = 0;
    var unknown = 0;
    for (final habit in habits) {
      final progress = day(type: habit.type, target: habit.target, value: habit.value);
      if (progress == null) {
        unknown++;
        continue;
      }
      total++;
      if (progress.complete) complete++;
    }
    return TodaySummary(complete: complete, total: total, unknown: unknown);
  }

  /// [logs] maps local dates (YYYY-MM-DD) inside one week to wire values. One row per day, so
  /// several sessions on one day count once.
  ProvisionalWeekProgress? week({
    required String type,
    required Object? perDayTarget,
    required int countTarget,
    required Map<String, Object?> logs,
  }) {
    final rules = types.lookup(type);
    final target = rules?.parseTarget(perDayTarget);
    if (rules == null || target == null || countTarget < 1 || countTarget > 7) return null;
    var days = 0;
    for (final wire in logs.values) {
      final value = rules.parseValue(wire);
      if (value != null && rules.isComplete(value, target)) days++;
    }
    return ProvisionalWeekProgress(distinctCompletedDays: days, targetDays: countTarget);
  }
}
