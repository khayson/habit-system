import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/calendar/local_date.dart';
import '../domain/habit_schedule.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';

/// How habits read on screens 05, 07, 12 and 13 ("Duration · 10 min · daily"). Driven by the
/// type rules' [TypeDisplay], never by a type key (invariant 14).
class HabitFormat {
  final AppLocalizations l10n;
  final String locale;

  HabitFormat(BuildContext context)
    : l10n = AppLocalizations.of(context),
      locale = Localizations.localeOf(context).toLanguageTag();

  static IconData icon(ProvisionalTypeRules? rules) => switch (rules?.display) {
    TypeDisplay.yesNo => Icons.check,
    TypeDisplay.quantity => Icons.water_drop_outlined,
    TypeDisplay.duration => Icons.schedule,
    null => Icons.help_outline,
  };

  String typeLabel(ProvisionalTypeRules? rules) => switch (rules?.display) {
    TypeDisplay.yesNo => l10n.typeYesNo,
    TypeDisplay.quantity => l10n.typeQuantity,
    TypeDisplay.duration => l10n.typeDuration,
    null => l10n.typeUnknown,
  };

  /// "2 L", "10 min"; null for yes/no habits (the design shows no target for them).
  String? amount(ProvisionalTypeRules? rules, Object? wire, String? unit) {
    if (rules == null || rules.display == TypeDisplay.yesNo) return null;
    final units = rules.parseValue(wire) ?? rules.parseTarget(wire);
    if (units == null) return null;
    return switch (rules.display) {
      TypeDisplay.duration => l10n.minutesShort(minutes(units)),
      _ => [decimal(units), if (unit != null && unit.isNotEmpty) unit].join(' '),
    };
  }

  /// Whole seconds as minutes: 600 -> "10", 90 -> "1.5".
  String minutes(int seconds) => NumberFormat('0.#', locale).format(seconds / 60);

  /// Thousandths as a plain decimal: 1250 -> "1.25".
  String decimal(int thousandths) => NumberFormat('0.###', locale).format(thousandths / 1000);

  /// "daily", "weekdays", "Tue, Sat", "3× / week", "every 2 days".
  String frequency(ScheduleFrequency? f) {
    if (f == null || !f.known) return l10n.freqUnknown;
    switch (f.type) {
      case 'daily':
        return l10n.freqDaily;
      case 'weekdays':
        final days = [...f.days]..sort();
        if (days.length == 7) return l10n.freqDaily;
        if (days.join(',') == '1,2,3,4,5') return l10n.freqWeekdays;
        // 1 Jan 2024 was a Monday.
        return days.map((d) => DateFormat.E(locale).format(DateTime.utc(2024, 1, d))).join(', ');
      case 'weekly_count':
        return l10n.freqWeekly(f.count);
      case 'interval':
        return f.everyNDays == 1 ? l10n.freqDaily : l10n.freqInterval(f.everyNDays);
    }
    return l10n.freqUnknown;
  }

  /// The design's library row: "Quantity · 2 L · daily" / "Yes / no · weekdays".
  String rowDetail(
    ProvisionalTypeRules? rules,
    Object? target,
    String? unit,
    ScheduleFrequency? f,
  ) {
    final amount = this.amount(rules, target, unit);
    return amount == null
        ? l10n.rowDetailNoTarget(typeLabel(rules), frequency(f))
        : l10n.rowDetail(typeLabel(rules), amount, frequency(f));
  }

  String category(String? category, {bool long = false}) => switch (category) {
    'mindfulness' => long ? l10n.categoryMindfulness : l10n.categoryMindful,
    'learning' => l10n.categoryLearning,
    _ => l10n.categoryHealth,
  };

  /// "27 May".
  String dayMonth(LocalDate date) => DateFormat.MMMd(locale).format(_utc(date));

  /// "25 May 2026".
  String fullDate(LocalDate date) => DateFormat.yMMMd(locale).format(_utc(date));

  /// "May 2026".
  String month(LocalDate date) => DateFormat.yMMMM(locale).format(_utc(date));

  /// "8:20 AM" in the locale's clock.
  String time(DateTime wallClock) => DateFormat.jm(locale).format(wallClock);

  static DateTime _utc(LocalDate date) =>
      DateTime.fromMillisecondsSinceEpoch(date.midnightMillis, isUtc: true);
}
