/// GET /insights (A47): what the server worked out for the user's current week or month.
/// Shown as sent; the app computes no rule from it (invariant 9). Unknown words are kept and
/// extra fields ignored (invariant 13).
library;

class InsightsWindow {
  final String start;
  final String end;
  final String today;

  /// The last closed local date in the window; null when none has closed yet.
  final String? through;

  const InsightsWindow({required this.start, required this.end, required this.today, this.through});

  factory InsightsWindow.fromJson(Map<String, dynamic> j) => InsightsWindow(
    start: j['start'] as String,
    end: j['end'] as String,
    today: j['today'] as String,
    through: j['through'] as String?,
  );
}

class InsightsTotals {
  final int completed;
  final int eligible;

  /// Null when nothing is eligible; never shown as 0%.
  final int? percent;

  const InsightsTotals({required this.completed, required this.eligible, this.percent});

  factory InsightsTotals.fromJson(Map<String, dynamic> j) => InsightsTotals(
    completed: j['completed'] as int,
    eligible: j['eligible'] as int,
    percent: j['percent'] as int?,
  );
}

class CategoryInsight extends InsightsTotals {
  final String category;

  const CategoryInsight({
    required this.category,
    required super.completed,
    required super.eligible,
    super.percent,
  });

  factory CategoryInsight.fromJson(Map<String, dynamic> j) => CategoryInsight(
    category: j['category'] as String,
    completed: j['completed'] as int,
    eligible: j['eligible'] as int,
    percent: j['percent'] as int?,
  );
}

class InsightsDay {
  final String date;

  /// Habit-day counts for the day; null for a future day.
  final int? completed;
  final int? due;
  final bool open;

  const InsightsDay({required this.date, this.completed, this.due, required this.open});

  factory InsightsDay.fromJson(Map<String, dynamic> j) => InsightsDay(
    date: j['date'] as String,
    completed: j['completed'] as int?,
    due: j['due'] as int?,
    open: j['open'] as bool,
  );

  /// Display only (design 14's bars): the largest due of the week, at least 1.
  static int scale(List<InsightsDay> days) {
    var max = 1;
    for (final d in days) {
      if ((d.due ?? 0) > max) max = d.due!;
    }
    return max;
  }

  /// This day's bar height against [scale] (0..1); an empty day is 0.
  double barFraction(int scale) => ((completed ?? 0) / scale).clamp(0.0, 1.0).toDouble();
}

class OpenPeriod {
  final String habitId;
  final int completed;
  final int target;

  const OpenPeriod({required this.habitId, required this.completed, required this.target});

  factory OpenPeriod.fromJson(Map<String, dynamic> j) => OpenPeriod(
    habitId: j['habit_id'] as String,
    completed: j['completed'] as int,
    target: j['target'] as int,
  );
}

class Insights {
  final String period;
  final String? category;
  final InsightsWindow window;
  final InsightsTotals totals;
  final int xpEarned;
  final List<CategoryInsight> byCategory;

  /// Week only.
  final List<InsightsDay>? days;
  final List<OpenPeriod>? openPeriods;

  const Insights({
    required this.period,
    required this.category,
    required this.window,
    required this.totals,
    required this.xpEarned,
    required this.byCategory,
    this.days,
    this.openPeriods,
  });

  factory Insights.fromJson(Map<String, dynamic> j) {
    final days = j['days'] as List?;
    final open = j['open_periods'] as List?;
    return Insights(
      period: j['period'] as String,
      category: j['category'] as String?,
      window: InsightsWindow.fromJson((j['window'] as Map).cast()),
      totals: InsightsTotals.fromJson((j['totals'] as Map).cast()),
      xpEarned: j['xp_earned'] as int,
      byCategory: List.unmodifiable([
        for (final c in j['by_category'] as List) CategoryInsight.fromJson((c as Map).cast()),
      ]),
      days: days == null
          ? null
          : List.unmodifiable([for (final d in days) InsightsDay.fromJson((d as Map).cast())]),
      openPeriods: open == null
          ? null
          : List.unmodifiable([for (final o in open) OpenPeriod.fromJson((o as Map).cast())]),
    );
  }
}
