import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/habit_tokens.dart';
import '../domain/calendar/local_date.dart';
import '../domain/frequency_choice.dart';
import '../domain/habit_draft.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/habit_form_text.dart';
import '../widgets/habit_ui.dart';
import '../widgets/schedule_text.dart';

/// What 08 and 09 hand to screen 10: the habit's name, its current schedule and today in the
/// account calendar (the interval start date's range).
class FrequencyRequest {
  final String habitName;
  final FrequencyChoice current;
  final LocalDate today;

  const FrequencyRequest({required this.habitName, required this.current, required this.today});
}

/// Screen 10: frequency selection. Pops a [FrequencyChoice]; writes nothing (works offline).
class FrequencyScreen extends StatefulWidget {
  final FrequencyRequest request;

  const FrequencyScreen({super.key, required this.request});

  @override
  State<FrequencyScreen> createState() => _FrequencyScreenState();
}

class _FrequencyScreenState extends State<FrequencyScreen> {
  late String? _type;
  late Set<int> _days;
  late int _count;
  late int _every;
  late LocalDate _anchor;
  bool _daysMissing = false;

  @override
  void initState() {
    super.initState();
    final c = widget.request.current;
    _type = c.known ? c.type : null;
    // ASSUMPTION(4.2b-frequency-defaults): switching to an option starts from the habit's own
    // values when it has them, else no weekdays, 3 times a week, every 2 days from today.
    _days = {...c.days};
    _count = (c.count ?? 3).clamp(1, 7);
    _every = (c.everyNDays ?? 2).clamp(1, 365);
    _anchor = c.anchor ?? widget.request.today;
  }

  LocalDate get _today => widget.request.today;
  LocalDate get _firstAnchor => _anchor.isBefore(_today) ? _anchor : _today;
  LocalDate get _lastAnchor => _today.addDays(365);

  FrequencyChoice? get _choice => switch (_type) {
    FrequencyChoice.dailyType => FrequencyChoice.daily,
    FrequencyChoice.weekdaysType => FrequencyChoice.weekdays(_days),
    FrequencyChoice.weeklyCountType => FrequencyChoice.weeklyCount(_count),
    FrequencyChoice.intervalType => FrequencyChoice.interval(_every, _anchor),
    _ => null,
  };

  void _submit() {
    final choice = _choice;
    if (choice == null) {
      // An unknown schedule the person did not change goes back as it was (A21).
      context.pop(widget.request.current);
      return;
    }
    if (choice.type == FrequencyChoice.weekdaysType && choice.days.isEmpty) {
      setState(() => _daysMissing = true);
      return;
    }
    context.pop(choice);
  }

  Future<void> _pickAnchor() async {
    DateTime asDate(LocalDate d) =>
        DateTime.fromMillisecondsSinceEpoch(d.midnightMillis, isUtc: true);
    final picked = await showDatePicker(
      context: context,
      initialDate: asDate(_anchor),
      firstDate: asDate(_firstAnchor),
      lastDate: asDate(_lastAnchor),
      helpText: AppLocalizations.of(context).freqChooseStart,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _anchor = LocalDate.ofWallClockMillis(
        DateTime.utc(picked.year, picked.month, picked.day).millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = widget.request.habitName.trim();
    final options = [
      (FrequencyChoice.dailyType, l10n.freqDailyTitle, l10n.freqDailyBody),
      (FrequencyChoice.weekdaysType, l10n.freqWeekdaysTitle, l10n.freqWeekdaysBody),
      (FrequencyChoice.weeklyCountType, l10n.freqWeeklyTitle, l10n.freqWeeklyBody(_count)),
      (FrequencyChoice.intervalType, l10n.freqIntervalTitle, l10n.freqIntervalBody),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.freqTitle,
              subtitle: name.isEmpty ? l10n.freqSubtitleNoName : l10n.freqSubtitle(name),
              onBack: () => context.pop(),
            ),
            for (final (type, title, body) in options) ...[
              _OptionCard(
                title: title,
                body: body,
                selected: _type == type,
                onTap: () => setState(() {
                  _type = type;
                  _daysMissing = false;
                }),
              ),
              const SizedBox(height: HabitSpace.s16),
            ],
            if (_type != null) ...[const SizedBox(height: HabitSpace.s8), _summary(context)],
            if (_type == FrequencyChoice.weeklyCountType) ...[
              const SizedBox(height: HabitSpace.s16),
              InfoCard(title: l10n.freqWeekInfoTitle, body: l10n.freqWeekInfoBody, tone: Tone.info),
            ],
            const SizedBox(height: HabitSpace.s24),
            PrimaryButton(label: l10n.freqUse, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  /// The selected option's summary card, holding its controls (a design gap: 10 shows only the
  /// summary; weekday toggles, steppers and the start date sit inside it).
  Widget _summary(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final schedule = ScheduleText(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final (String title, String detail) = switch (_type) {
      FrequencyChoice.weekdaysType => (
        _days.isEmpty ? l10n.freqWeekdaysTitle : schedule.days(_days.toList()),
        l10n.freqWeekdaysDetail(_days.length),
      ),
      FrequencyChoice.weeklyCountType => (l10n.freqWeeklySummary(_count), l10n.freqWeeklyDetail),
      FrequencyChoice.intervalType => (
        l10n.freqIntervalSummary(_every),
        l10n.freqIntervalDetail(schedule.date(_anchor)),
      ),
      _ => (l10n.freqDailyTitle, l10n.freqDailyDetail),
    };
    return Container(
      padding: const EdgeInsets.all(HabitSpace.s24),
      decoration: BoxDecoration(
        color: tokens.positiveBg,
        borderRadius: BorderRadius.circular(HabitRadius.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(liveRegion: true, child: Text(title, style: text.titleLarge)),
          const SizedBox(height: HabitSpace.s8),
          Text(detail, style: text.bodyMedium?.copyWith(color: tokens.positiveInk)),
          if (_type == FrequencyChoice.weekdaysType) ...[
            const SizedBox(height: HabitSpace.s16),
            FieldLabel(l10n.freqDaysLabel),
            Wrap(
              spacing: HabitSpace.s4,
              runSpacing: HabitSpace.s8,
              children: [
                for (var d = 1; d <= 7; d++)
                  _DayToggle(
                    letter: schedule.dayLetter(d),
                    name: schedule.dayName(d),
                    selected: _days.contains(d),
                    onTap: () => setState(() {
                      final day = d;
                      _days.contains(day) ? _days.remove(day) : _days.add(day);
                      if (_days.isNotEmpty) _daysMissing = false;
                    }),
                  ),
              ],
            ),
            if (_daysMissing) ...[
              const SizedBox(height: HabitSpace.s8),
              FieldErrorText(HabitFormText(l10n).problem(HabitDraftProblem.weekdays)),
            ],
          ],
          if (_type == FrequencyChoice.weeklyCountType) ...[
            const SizedBox(height: HabitSpace.s16),
            CountStepper(
              label: l10n.freqTimesLabel,
              value: _count,
              valueText: '$_count',
              min: 1,
              max: 7,
              onChanged: (v) => setState(() => _count = v),
            ),
          ],
          if (_type == FrequencyChoice.intervalType) ...[
            const SizedBox(height: HabitSpace.s16),
            CountStepper(
              label: l10n.freqEveryLabel,
              value: _every,
              valueText: l10n.freqEveryValue(_every),
              min: 1,
              max: 365,
              onChanged: (v) => setState(() => _every = v),
            ),
            const SizedBox(height: HabitSpace.s16),
            FieldLabel(l10n.freqStartDate),
            OutlinedButton.icon(
              onPressed: _pickAnchor,
              icon: const Icon(Icons.event_outlined),
              label: Text(schedule.date(_anchor)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One of 10's four options. Selection reads as a symbol (check or open circle) and in words to
/// screen readers, never by colour alone.
class _OptionCard extends StatelessWidget {
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SurfaceCard(
        onTap: onTap,
        semanticsLabel: '$title. $body. ${selected ? l10n.freqSelected : l10n.freqNotSelected}',
        child: ExcludeSemantics(
          child: Row(
            children: [
              IconTile(
                icon: Icons.calendar_month_outlined,
                iconColor: selected ? tokens.primary : tokens.muted,
              ),
              const SizedBox(width: HabitSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium ?? text.bodyLarge),
                    const SizedBox(height: HabitSpace.s4),
                    Text(body, style: text.bodySmall?.copyWith(color: tokens.muted)),
                  ],
                ),
              ),
              const SizedBox(width: HabitSpace.s8),
              Icon(
                selected ? Icons.check : Icons.circle_outlined,
                size: selected ? 22 : 14,
                color: selected ? tokens.primary : tokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 44 px weekday toggle: the day's letter, and a check when chosen. Announced by its full
/// name with its toggled state.
class _DayToggle extends StatelessWidget {
  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle({
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Semantics(
      button: true,
      toggled: selected,
      label: name,
      child: Material(
        color: selected ? tokens.surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          side: BorderSide(color: selected ? tokens.primary : tokens.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: HabitSize.minTarget,
              minHeight: HabitSize.control,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s4, vertical: 2),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      letter,
                      style: text.bodyLarge?.copyWith(
                        color: selected ? tokens.primary : tokens.ink,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                    Icon(
                      selected ? Icons.check : Icons.circle_outlined,
                      size: selected ? 14 : 8,
                      color: selected ? tokens.primary : tokens.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
