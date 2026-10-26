import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/habit_tokens.dart';
import '../domain/frequency_choice.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_icons.dart';
import 'habit_ui.dart';

/// A56: the large icon at the top of New and Edit habit, on its pastel tile; a tap opens the
/// icon picker. The icon's name is written under it, so the choice never rests on the picture.
class HabitIconHero extends StatelessWidget {
  final AppIconData icon;
  final HabitTile tile;
  final String name;
  final VoidCallback onEdit;

  const HabitIconHero({
    super.key,
    required this.icon,
    required this.tile,
    required this.name,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Center(
      child: Semantics(
        button: true,
        label: '${l10n.habitIconRow}, $name',
        hint: l10n.setupEdit,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('icon-row-edit'),
          onTap: onEdit,
          borderRadius: BorderRadius.circular(HabitRadius.r24),
          child: Padding(
            padding: const EdgeInsets.all(HabitSpace.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconTile(icon: icon, tile: tile, size: 104),
                    PositionedDirectional(
                      end: -6,
                      bottom: -6,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
                        child: AppIcon(AppIcons.edit, size: 16, color: tokens.onAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HabitSpace.s12),
                Text(l10n.habitIconRow, style: text.bodySmall?.copyWith(color: tokens.muted)),
                Text(name, style: text.titleSmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A56: the mockups' repeat days, seven round chips. Every day chosen is a daily habit; some
/// days are a weekdays habit. Other schedules (times a week, every few days) stay on the
/// schedule screen, and while one is chosen no chip is on. The last chosen day cannot be
/// turned off here.
class RepeatDays extends StatelessWidget {
  final FrequencyChoice frequency;
  final ValueChanged<FrequencyChoice> onChanged;

  const RepeatDays({super.key, required this.frequency, required this.onChanged});

  static const _all = [1, 2, 3, 4, 5, 6, 7];

  Set<int> get _days => switch (frequency.type) {
    FrequencyChoice.dailyType => _all.toSet(),
    FrequencyChoice.weekdaysType => frequency.days.toSet(),
    _ => const <int>{},
  };

  void _toggle(int day) {
    final days = {..._days};
    if (!days.remove(day)) days.add(day);
    if (days.isEmpty) return;
    onChanged(days.length == 7 ? FrequencyChoice.daily : FrequencyChoice.weekdays(days));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = _days;
    // 1 January 2024 was a Monday: ISO weekday d is that date plus d - 1 days.
    DateTime at(int d) => DateTime.utc(2024, 1, d);
    return Row(
      children: [
        for (final d in _all) ...[
          Expanded(
            child: DayChip(
              letter: DateFormat.EEEEE(locale).format(at(d)),
              label: l10n.reminderDayLabel(
                DateFormat.EEEE(locale).format(at(d)),
                days.contains(d) ? l10n.reminderDayOn : l10n.reminderDayOff,
              ),
              selected: days.contains(d),
              onTap: () => _toggle(d),
            ),
          ),
        ],
      ],
    );
  }
}

/// A56: "Get reminders" with a switch, as drawn. Turning it on (or tapping the row) opens the
/// reminder editor, since a reminder needs a time; turning it off clears it.
class ReminderSwitchRow extends StatelessWidget {
  final String title;
  final String summary;
  final bool on;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  const ReminderSwitchRow({
    super.key,
    required this.title,
    required this.summary,
    required this.on,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(HabitRadius.r20),
      child: InkWell(
        key: const ValueKey('reminder-row-edit'),
        onTap: onEdit,
        borderRadius: BorderRadius.circular(HabitRadius.r20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s16, vertical: HabitSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(summary, style: text.bodySmall?.copyWith(color: tokens.muted)),
                  ],
                ),
              ),
              Semantics(
                label: title,
                child: Switch(value: on, onChanged: (value) => value ? onEdit() : onClear()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
