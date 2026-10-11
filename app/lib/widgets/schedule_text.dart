import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../domain/calendar/local_date.dart';
import '../domain/frequency_choice.dart';
import '../l10n/generated/app_localizations.dart';

/// How a schedule reads in full on 08, 09 and 10 ("Monday, Wednesday and Friday", "3 times each
/// week", "Every 2 days from 28 May"). 07 and 12 keep HabitFormat.frequency's short form.
class ScheduleText {
  final AppLocalizations l10n;
  final String locale;

  ScheduleText(BuildContext context)
    : l10n = AppLocalizations.of(context),
      locale = Localizations.localeOf(context).toLanguageTag();

  // 1 January 2024 was a Monday: ISO day d is 2024-01-d.
  static DateTime _day(int iso) => DateTime.utc(2024, 1, iso);

  /// "Monday".
  String dayName(int iso) => DateFormat.EEEE(locale).format(_day(iso));

  /// "M": the toggle's face; its semantics use [dayName].
  String dayLetter(int iso) => DateFormat.EEEEE(locale).format(_day(iso));

  /// "28 May".
  String date(LocalDate d) =>
      DateFormat.MMMd(locale)
          .format(DateTime.fromMillisecondsSinceEpoch(d.midnightMillis, isUtc: true));

  /// "Monday, Wednesday and Friday".
  String days(List<int> isoDays) {
    final names = [
      for (final d in [...isoDays]..sort()) dayName(d),
    ];
    if (names.isEmpty) return '';
    if (names.length == 1) return names.single;
    return l10n.listAnd(names.sublist(0, names.length - 1).join(', '), names.last);
  }

  /// The row summary on 08 and 09.
  String summary(FrequencyChoice c) {
    switch (c.type) {
      case FrequencyChoice.dailyType:
        return l10n.freqDailyTitle;
      case FrequencyChoice.weekdaysType:
        return c.days.length == 7 ? l10n.freqDailyTitle : days(c.days);
      case FrequencyChoice.weeklyCountType:
        return l10n.freqWeeklySummary(c.count ?? 1);
      case FrequencyChoice.intervalType:
        final every = l10n.freqIntervalSummary(c.everyNDays ?? 1);
        final anchor = c.anchor;
        return anchor == null ? every : l10n.freqIntervalFrom(every, date(anchor));
    }
    return l10n.freqUnknown;
  }
}
