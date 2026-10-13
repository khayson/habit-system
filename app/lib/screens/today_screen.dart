import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/local_view.dart';
import '../data/rewards_view.dart';
import '../data/timer_draft_view.dart';
import '../domain/calendar/local_date.dart';
import '../habit_types/habit_type_ui.dart';
import '../data/timezone_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import '../widgets/sync_status_chip.dart';
import 'timezone_screen.dart';
import 'widgets/needs_attention.dart';

/// Screen 05, with screen 23 as its first-run empty state. Lists the habits due today (schedule,
/// active range, zero-length dates excluded) in creation order. Reads local data only and works
/// fully offline; values waiting to sync are labelled as such. Tapping a habit opens 12; its
/// trailing check is the one-tap check-in.
class TodayScreen extends StatelessWidget {
  final DateTime Function() clock;

  const TodayScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return MultiProvider(
      key: ValueKey(account.session.userId),
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              StreamModel<TodayView?>(TimeZones.ready.then((_) => account.view.watchToday(clock))),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StreamModel<ConfirmedRewardNumbers?>(Future.value(account.rewards.watch())),
        ),
      ],
      child: _TodayBody(clock: clock),
    );
  }
}

class _TodayBody extends StatelessWidget {
  final DateTime Function() clock;

  const _TodayBody({required this.clock});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final model = context.watch<StreamModel<TodayView?>>();
    final today = model.value;

    final Widget body;
    if (model.error != null && !model.hasValue) {
      body = _Message(text: l10n.todayLoadError, icon: Icons.error_outline);
    } else if (today == null) {
      body = _Message(text: l10n.todayOpening, icon: null);
    } else if (today.items.isEmpty) {
      body = const _EmptyToday();
    } else {
      body = _TodayList(today: today, clock: clock);
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

class _TodayList extends StatelessWidget {
  final TodayView today;
  final DateTime Function() clock;

  const _TodayList({required this.today, required this.clock});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    // Design 05: "Thursday, 28 May 2026", day first (ARB weekdayDate).
    final date = l10n.weekdayDate(
      DateTime.fromMillisecondsSinceEpoch(today.date.midnightMillis, isUtc: true),
    );
    final total = today.items.length;
    final done = today.completeCount;
    // A44: the numbers exactly as reward_state confirmed them; no line without them.
    final rewards = context.watch<StreamModel<ConfirmedRewardNumbers?>>().value;

    return ListView(
      padding: const EdgeInsets.all(HabitSpace.margin),
      children: [
        const AskZoneCard(),
        Semantics(header: true, child: Text(_greeting(l10n, today), style: text.headlineMedium)),
        const SizedBox(height: HabitSpace.s4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: HabitSpace.s12,
          runSpacing: HabitSpace.s8,
          children: [
            Text(date, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            SyncStatusChip(onTap: () => context.push(Routes.queue)),
          ],
        ),
        const SizedBox(height: HabitSpace.s24),
        Container(
          padding: const EdgeInsets.all(HabitSpace.s24),
          decoration: BoxDecoration(
            color: tokens.positiveBg,
            borderRadius: BorderRadius.circular(HabitRadius.r16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.todaySummary(done, total), style: text.titleLarge),
              if (rewards != null) ...[
                const SizedBox(height: HabitSpace.s8),
                Semantics(
                  container: true,
                  label: l10n.todayRewardLineLabel(rewards.xp, rewards.level),
                  excludeSemantics: true,
                  child: Text(
                    l10n.todayRewardLine(rewards.xp, rewards.level),
                    style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                  ),
                ),
              ],
              const SizedBox(height: HabitSpace.s16),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HabitRadius.r4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 8,
                    color: tokens.progress,
                    backgroundColor: tokens.border,
                  ),
                ),
              ),
              if (today.hasPending) ...[
                const SizedBox(height: HabitSpace.s12),
                Text(
                  l10n.todaySummaryProvisional,
                  style: text.bodySmall?.copyWith(color: tokens.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: HabitSpace.s24),
        for (final item in today.items) ...[
          _HabitRow(item: item, clock: clock),
          const SizedBox(height: HabitSpace.s12),
        ],
      ],
    );
  }

  static String _greeting(AppLocalizations l10n, TodayView today) {
    final name = today.userName?.trim();
    if (name == null || name.isEmpty) return l10n.todayGreetingPlain;
    final first = name.split(RegExp(r'\s+')).first;
    final hour = today.localNow.hour;
    if (hour < 12) return l10n.todayGreetingMorning(first);
    if (hour < 18) return l10n.todayGreetingAfternoon(first);
    return l10n.todayGreetingEvening(first);
  }
}

class _HabitRow extends StatelessWidget {
  final TodayItem item;
  final DateTime Function() clock;

  static final _types = HabitTypeUiRegistry.builtins();

  const _HabitRow({required this.item, required this.clock});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final account = context.read<AccountContext?>()!;
    final week = item.week;
    final type = _types.lookup(item.habit.payload['type'] as String?);
    // 4.3b C2 / C3: quantity and duration cards (design 05). Attention and unknown types keep
    // their rows (4.3c handles attention).
    if (!item.needsAttention && item.rules != null && type != null && type.hasAmountEntry) {
      return _AmountRow(item: item, type: type, clock: clock);
    }

    final String subtitle;
    final IconData trailing;
    final Tone tone;
    if (item.needsAttention) {
      (subtitle, trailing, tone) = (l10n.todayNeedsLook, Icons.error_outline, Tone.warning);
    } else if (item.rules == null) {
      (subtitle, trailing, tone) = (l10n.todayUnknownType, Icons.system_update_alt, Tone.info);
    } else if (item.complete) {
      final at = item.completedAt;
      subtitle = at == null
          ? (item.pending ? l10n.todayDoneWaiting : l10n.todayDone)
          : (item.pending
                ? l10n.todayCompletedAtWaiting(format.time(at))
                : l10n.todayCompletedAt(format.time(at)));
      (trailing, tone) = (Icons.check, Tone.positive);
    } else if (!item.rules!.oneTap) {
      (subtitle, trailing, tone) = (l10n.todayOtherType, Icons.hourglass_empty, Tone.info);
    } else if (item.habit.provisional && item.log.syncState == null) {
      (subtitle, trailing, tone) = (
        l10n.todayNewHabitWaiting,
        Icons.radio_button_unchecked,
        Tone.neutral,
      );
    } else {
      (subtitle, trailing, tone) = (
        item.pending ? l10n.todayNotDoneWaiting : l10n.todayNotDone,
        Icons.radio_button_unchecked,
        Tone.neutral,
      );
    }
    final lines = [
      subtitle,
      if (week != null) l10n.todayWeek(week.distinctCompletedDays, week.targetDays),
    ];

    VoidCallback? onAction;
    String? action;
    if (item.needsAttention) {
      onAction = () => showNeedsAttention(context, account, item.attention!);
      action = l10n.todayNeedsLook;
    } else if (item.canToggle) {
      onAction = () => account.actions.toggle(item);
      action = item.complete ? l10n.todayUndo(item.name) : l10n.todayCheckIn(item.name);
    }
    final ink = tone == Tone.neutral ? tokens.muted : tone.ink(tokens);

    return SurfaceCard(
      onTap: () => context.go(Routes.habit(item.habit.id)),
      semanticsLabel: '${l10n.todayOpenDetail(item.name)}. ${lines.join('. ')}',
      child: Row(
        children: [
          ExcludeSemantics(child: IconTile(icon: HabitFormat.icon(item.rules))),
          const SizedBox(width: HabitSpace.s16),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleMedium ?? text.bodyLarge),
                  for (final line in lines) ...[
                    const SizedBox(height: HabitSpace.s4),
                    Text(line, style: text.bodySmall?.copyWith(color: tokens.muted)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: HabitSpace.s8),
          if (onAction != null)
            IconButton(
              onPressed: onAction,
              tooltip: action,
              icon: Icon(trailing, color: ink),
              constraints: const BoxConstraints(
                minWidth: HabitSize.minTarget,
                minHeight: HabitSize.minTarget,
              ),
            )
          else
            ExcludeSemantics(child: Icon(trailing, color: ink)),
        ],
      ),
    );
  }
}

/// Design 05's quantity and duration card: "1.25 / 2 L" with a "+250 mL" quick-add that opens
/// 34 with that step (one stray tap writes nothing), "· done" with a check once complete, and a
/// timer line while a draft exists. The row's own tap still opens 12.
class _AmountRow extends StatelessWidget {
  final TodayItem item;
  final HabitTypeUi type;
  final DateTime Function() clock;

  const _AmountRow({required this.item, required this.type, required this.clock});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final p = item.habit.payload;
    // The unit in force on the day this card shows (P3), else the habit's own.
    final unit = item.habit.schedule.unitOn(LocalDate.parse(item.log.date)) ?? p['unit'] as String?;
    final timer = item.timer;
    final step = type.suggestStep(item.target, unit);
    final progress = type.progress(format, item.log.value, item.target, unit);
    final spoken = type.progress(format, item.log.value, item.target, unit, spoken: true);

    final Widget line;
    final Widget trailing;
    final String said;
    if (timer != null && type.rules.supportsTimer) {
      line = _TimerLine(draft: timer, clock: clock);
      final minutes = timer.elapsed(clock()).inMinutes;
      said = timer.state == TimerDraftView.running
          ? l10n.todayTimerRunningSpoken(minutes)
          : l10n.todayTimerPausedSpoken(minutes);
      trailing = _action(
        context,
        l10n.todayOpenTimer,
        l10n.todayOpenTimer,
        () => context.push(Routes.timer(item.habit.id)),
      );
    } else if (item.complete) {
      line = Text(
        l10n.todayProgressDone(progress),
        style: text.bodySmall?.copyWith(color: tokens.muted),
      );
      said = l10n.todayProgressDone(spoken);
      trailing = ExcludeSemantics(child: Icon(Icons.check, color: tokens.positiveInk));
    } else {
      line = Text(progress, style: text.bodySmall?.copyWith(color: tokens.muted));
      said = spoken;
      final plus = type.plusAmount(format, step, unit);
      trailing = _action(
        context,
        plus,
        l10n.todayAddSpoken(type.amountText(format, step, unit)),
        () => context.push(Routes.amount(item.habit.id), extra: step),
      );
    }

    return SurfaceCard(
      onTap: () => context.go(Routes.habit(item.habit.id)),
      semanticsLabel:
          '${l10n.todayOpenDetail(item.name)}. ${l10n.todayAmountSpoken(item.name, said)}',
      child: Row(
        children: [
          ExcludeSemantics(child: IconTile(icon: HabitFormat.icon(item.rules))),
          const SizedBox(width: HabitSpace.s16),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleMedium ?? text.bodyLarge),
                  const SizedBox(height: HabitSpace.s4),
                  line,
                  if (item.pending) ...[
                    const SizedBox(height: HabitSpace.s4),
                    Text(l10n.editWaiting, style: text.bodySmall?.copyWith(color: tokens.muted)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: HabitSpace.s8),
          trailing,
        ],
      ),
    );
  }

  /// A 44 px text action with its own words for screen readers.
  static Widget _action(BuildContext context, String label, String said, VoidCallback onPressed) =>
      Semantics(
        container: true,
        button: true,
        label: said,
        excludeSemantics: true,
        onTap: onPressed,
        // At large text the label wraps instead of pushing the card wider.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      );
}

/// "Timer running · 06:00": ticks once a second while running, in this row only (the Today list
/// is not rebuilt each second). Screen readers get the row's label, refreshed with the list.
class _TimerLine extends StatefulWidget {
  final TimerDraftView draft;
  final DateTime Function() clock;

  const _TimerLine({required this.draft, required this.clock});

  @override
  State<_TimerLine> createState() => _TimerLineState();
}

class _TimerLineState extends State<_TimerLine> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_TimerLine old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final running = widget.draft.state == TimerDraftView.running;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final time = timerClock(widget.draft.elapsed(widget.clock()));
    return Text(
      widget.draft.state == TimerDraftView.running
          ? l10n.todayTimerRunning(time)
          : l10n.todayTimerPaused(time),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.positiveInk),
    );
  }
}

/// Ask-on-change (screen 04, Phase 3.2a): one non-modal card when the device has moved to
/// another zone while "Follow device timezone" is on. "Not now" is remembered per zone.
class AskZoneCard extends StatefulWidget {
  const AskZoneCard({super.key});

  @override
  State<AskZoneCard> createState() => _AskZoneCardState();
}

class _AskZoneCardState extends State<AskZoneCard> with WidgetsBindingObserver {
  String? _deviceZone;

  /// Answered on this screen: hidden at once, before the stored answer is read back.
  final _answered = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read(); // checked at foreground
  }

  Future<void> _read() async {
    try {
      final zone = await DeviceZone.read();
      if (mounted) setState(() => _deviceZone = zone);
    } on Object {
      // No zone from the platform: nothing to ask.
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<StreamModel<TodayView?>>().value?.timezone;
    final zone = _deviceZone;
    if (status == null || zone == null || _answered.contains(zone) || !status.shouldAsk(zone)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final account = context.read<AccountContext?>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: HabitSpace.s24),
      child: Container(
        padding: const EdgeInsets.all(HabitSpace.s24),
        decoration: BoxDecoration(
          color: tokens.infoBg,
          borderRadius: BorderRadius.circular(HabitRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.askZoneTitle(TimezoneScreen.cityName(zone)),
              style: text.titleMedium?.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: HabitSpace.s8),
            Text(l10n.askZoneBody, style: text.bodyMedium?.copyWith(color: tokens.muted)),
            const SizedBox(height: HabitSpace.s16),
            Wrap(
              spacing: HabitSpace.s12,
              runSpacing: HabitSpace.s8,
              children: [
                FilledButton(
                  onPressed: () {
                    setState(() => _answered.add(zone));
                    account.actions.setTimezone(zone);
                  },
                  child: Text(l10n.askZoneUse),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _answered.add(zone));
                    DeviceSettings(account.session.db).notNow(zone);
                  },
                  child: Text(l10n.askZoneNotNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 23: the first-run empty Today.
class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(HabitSpace.margin),
      children: [
        const AskZoneCard(),
        Align(
          alignment: Alignment.centerRight,
          child: SyncStatusChip(onTap: () => context.push(Routes.queue)),
        ),
        ScreenHeader(title: l10n.emptyTitle, subtitle: l10n.emptySubtitle),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: tokens.positiveBg, shape: BoxShape.circle),
            child: Icon(Icons.eco_outlined, size: 96, color: tokens.primary),
          ),
        ),
        const SizedBox(height: HabitSpace.s32),
        Text(l10n.emptyHeading, style: text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: HabitSpace.s12),
        Text(
          l10n.emptyBody,
          style: text.bodyLarge?.copyWith(color: tokens.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HabitSpace.s48),
        PrimaryButton(label: l10n.emptyButton, onPressed: () => context.push(Routes.newHabit)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Message({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HabitSpace.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null) const CircularProgressIndicator() else Icon(icon, size: 32),
            const SizedBox(height: HabitSpace.s16),
            Text(text, style: style, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
