import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/habit_tokens.dart';
import '../domain/calendar/local_date.dart';
import '../l10n/generated/app_localizations.dart';

/// A56: the mockups' week strip on Today, Monday to Sunday: the weekday above a round chip with
/// the day of the month; today's chip is the dark "selected" circle and its weekday is bold.
/// It shows the week; the day is the account's habit-day ([today]), never computed here.
class WeekStrip extends StatelessWidget {
  final LocalDate today;

  const WeekStrip({super.key, required this.today});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monday = today.addDays(1 - today.isoWeekday);
    DateTime at(LocalDate d) => DateTime.fromMillisecondsSinceEpoch(d.midnightMillis, isUtc: true);
    final long = DateFormat.MMMMd(locale);
    return Semantics(
      container: true,
      label: l10n.todayWeekSpoken(
        long.format(at(monday)),
        long.format(at(monday.addDays(6))),
        DateFormat.MMMMEEEEd(locale).format(at(today)),
      ),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: HabitSpace.s4),
            Expanded(
              child: _Day(
                weekday: DateFormat.E(locale).format(at(monday.addDays(i))),
                day: at(monday.addDays(i)).day,
                isToday: monday.addDays(i) == today,
                text: text,
                tokens: tokens,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final String weekday;
  final int day;
  final bool isToday;
  final TextTheme text;
  final HabitTokens tokens;

  const _Day({
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.text,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          weekday,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: text.bodySmall?.copyWith(
            color: isToday ? tokens.ink : tokens.muted,
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(height: HabitSpace.s8),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? tokens.selected : tokens.surface,
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(HabitSpace.s4),
                child: Text(
                  '$day',
                  style: text.bodyMedium?.copyWith(
                    color: isToday ? tokens.onSelected : tokens.ink,
                    fontWeight: isToday ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
