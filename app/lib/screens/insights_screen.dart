import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../data/local_view.dart';
import '../domain/calendar/local_date.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/insights.dart';
import '../providers/account_context.dart';
import '../sync/outbox_states.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screens 14 (Week) and 15 (Month), one screen with the design's switch (A47). Shows what GET
/// /insights sent and computes no rule: the last answer this session at once, then a fresh one.
/// An explicit network action (CLAUDE.md, Flutter rules): loading, error and Try again apply.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

/// The Week / Month choice, in memory for the session (5.3b).
String _sessionPeriod = 'week';

/// Tests start each case on Week.
@visibleForTesting
void resetInsightsPeriodForTest() => _sessionPeriod = 'week';

class _InsightsScreenState extends State<InsightsScreen> {
  String _period = _sessionPeriod;
  Insights? _shown;
  bool _loading = false;
  bool _offline = false;
  bool _failed = false;
  Map<String, (String?, ProvisionalTypeRules?)> _habits = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown == null && !_loading) _load();
  }

  Future<void> _load() async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    final api = account.insightsApi;
    final period = _period;
    setState(() {
      _shown = api?.last(period);
      _loading = true;
      _failed = false;
      _offline = false;
    });
    final habits = {
      for (final h in await account.view.habits())
        h.id: (
          h.payload['name'] as String?,
          account.view.types.lookup(h.payload['type'] as String? ?? ''),
        ),
    };
    try {
      if (api == null) {
        throw const AppException(kind: AppErrorKind.network, code: 'network', message: '');
      }
      final answer = await api.fetch(period);
      if (!mounted || period != _period) return;
      setState(() => _shown = answer);
    } on AppException catch (e) {
      if (!mounted || period != _period) return;
      setState(() {
        _offline = e.kind == AppErrorKind.network || e.kind == AppErrorKind.timeout;
        _failed = !_offline;
      });
    } finally {
      if (mounted && period == _period) {
        setState(() {
          _loading = false;
          _habits = habits;
        });
      }
    }
  }

  void _switch(int index) {
    final period = index == 0 ? 'week' : 'month';
    if (period == _period) return;
    _sessionPeriod = period;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final muted = text.bodyMedium?.copyWith(color: tokens.muted);
    final shown = _shown;
    final week = _period == 'week';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: week ? l10n.insightsWeekTitle : l10n.insightsMonthTitle,
              subtitle: shown == null || shown.period != _period ? null : _subtitle(context, shown),
            ),
            SegmentedTabs(
              labels: [l10n.insightsWeek, l10n.insightsMonth],
              selected: week ? 0 : 1,
              onSelected: _switch,
            ),
            const SizedBox(height: HabitSpace.s16),
            ListenableBuilder(
              listenable: account.queue,
              builder: (context, _) {
                final waiting = (account.queue.value?.items ?? const <QueueItem>[]).any(
                  (i) => i.row.entity == 'habit_log' && OutboxState.unacked.contains(i.row.state),
                );
                return waiting
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: HabitSpace.s16),
                        child: Text(l10n.insightsUnsynced, style: muted),
                      )
                    : const SizedBox.shrink();
              },
            ),
            if (shown != null && _offline)
              Padding(
                padding: const EdgeInsets.only(bottom: HabitSpace.s16),
                child: Text(l10n.insightsOfflineLast, style: muted),
              ),
            if (shown == null) ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(HabitSpace.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_offline)
                Text(l10n.insightsOfflineNone, style: muted)
              else if (_failed) ...[
                Text(l10n.insightsLoadError, style: muted),
                const SizedBox(height: HabitSpace.s8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                    ),
                    onPressed: _load,
                    child: Text(l10n.ledgerTryAgain),
                  ),
                ),
              ],
            ] else if (week)
              _Week(insights: shown, habits: _habits)
            else
              _Month(insights: shown),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, Insights i) {
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = LocalDate.parse(i.window.start);
    final end = LocalDate.parse(i.window.end);
    if (i.period == 'week') {
      final sameMonth = i.window.start.substring(0, 7) == i.window.end.substring(0, 7);
      final first = sameMonth ? DateFormat.d(locale).format(_utc(start)) : format.dayMonth(start);
      return l10n.insightsWeekSubtitle(l10n.insightsRange(first, format.dayMonth(end)));
    }
    final month = DateFormat.MMMM(locale).format(_utc(start));
    final through = i.window.through;
    return through == null
        ? l10n.insightsMonthSubtitleNone(month)
        : l10n.insightsMonthSubtitle(month, format.dayMonth(LocalDate.parse(through)));
  }
}

DateTime _utc(LocalDate date) =>
    DateTime.fromMillisecondsSinceEpoch(date.midnightMillis, isUtc: true);

class _Tile extends StatelessWidget {
  final String big;
  final String? small;

  const _Tile({required this.big, this.small});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Semantics(
      container: true,
      label: [big, ?small].join(', '),
      excludeSemantics: true,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(big, style: small == null ? text.titleMedium : text.headlineMedium),
            if (small != null) ...[
              const SizedBox(height: HabitSpace.s4),
              Text(small!, style: text.bodySmall?.copyWith(color: tokens.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  final Insights insights;
  final Map<String, (String?, ProvisionalTypeRules?)> habits;

  const _Week({required this.insights, required this.habits});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final totals = insights.totals;
    final through = insights.window.through;
    final percent = totals.percent;
    final days = insights.days ?? const <InsightsDay>[];
    final scale = InsightsDay.scale(days);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final tiles = [
      _Tile(
        big: percent == null ? l10n.insightsNoClosedPeriods : l10n.insightsPercent(percent),
        small: percent == null
            ? null
            : l10n.insightsClosedPeriods(totals.completed, totals.eligible),
      ),
      _Tile(
        big: l10n.insightsXp(insights.xpEarned),
        small: through == null
            ? l10n.insightsNoClosedDays
            : l10n.insightsThrough(format.dayMonth(LocalDate.parse(through))),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Side by side as drawn; stacked when large text needs the width.
        LayoutBuilder(
          builder: (context, constraints) =>
              MediaQuery.textScalerOf(context).scale(1) > 1.5 || constraints.maxWidth < 320
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tiles[0],
                    const SizedBox(height: HabitSpace.s12),
                    tiles[1],
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: HabitSpace.s12),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: HabitSpace.s16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.insightsCheckIns, style: text.titleMedium),
              const SizedBox(height: HabitSpace.s8),
              Text(l10n.insightsTodayOpen, style: text.bodySmall?.copyWith(color: tokens.muted)),
              const SizedBox(height: HabitSpace.s16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _DayBar(day: day, scale: scale, locale: locale),
                    ),
                ],
              ),
            ],
          ),
        ),
        for (final open in insights.openPeriods ?? const <OpenPeriod>[]) ...[
          const SizedBox(height: HabitSpace.s16),
          Semantics(
            container: true,
            label: [
              habits[open.habitId]?.$1 ?? l10n.ledgerHabitUnknown,
              l10n.insightsOpenWeekly(open.completed, open.target),
              l10n.insightsPending,
            ].join(', '),
            excludeSemantics: true,
            child: SurfaceCard(
              child: Row(
                children: [
                  IconTile(icon: HabitFormat.icon(habits[open.habitId]?.$2)),
                  const SizedBox(width: HabitSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habits[open.habitId]?.$1 ?? l10n.ledgerHabitUnknown,
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: HabitSpace.s4),
                        Text(
                          l10n.insightsOpenWeekly(open.completed, open.target),
                          style: text.bodySmall?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: HabitSpace.s8),
                  Text(
                    l10n.insightsPending,
                    style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: HabitSpace.s16),
        InfoCard(title: l10n.insightsWeekNoteTitle, body: l10n.insightsWeekNoteBody),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  static const double height = 120;

  final InsightsDay day;
  final int scale;
  final String locale;

  const _DayBar({required this.day, required this.scale, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final date = _utc(LocalDate.parse(day.date));
    final name = DateFormat.EEEE(locale).format(date);
    final future = day.completed == null;
    final label = future
        ? l10n.insightsFutureLabel(name)
        : day.open
        ? l10n.insightsTodayLabel(day.completed!, day.due ?? 0)
        : l10n.insightsDayLabel(name, day.completed!, day.due ?? 0);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: future || day.completed == 0
                    ? Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.border,
                          borderRadius: BorderRadius.circular(HabitRadius.r4),
                        ),
                      )
                    : Container(
                        height: height * day.barFraction(scale),
                        decoration: BoxDecoration(
                          color: tokens.progress,
                          borderRadius: BorderRadius.circular(HabitRadius.r8),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: HabitSpace.s8),
          Text(
            DateFormat('EEEEE', locale).format(date),
            style: text.bodySmall?.copyWith(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _Month extends StatelessWidget {
  final Insights insights;

  const _Month({required this.insights});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final totals = insights.totals;
    final percent = totals.percent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: percent == null
              ? l10n.insightsNoClosedPeriods
              : '${l10n.insightsPercent(percent)}, ${l10n.insightsEligiblePeriods(totals.completed, totals.eligible)}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(HabitSpace.s32),
            decoration: BoxDecoration(
              color: tokens.positiveBg,
              borderRadius: BorderRadius.circular(HabitRadius.r24),
            ),
            child: Column(
              children: [
                Text(
                  percent == null ? l10n.insightsNoClosedPeriods : l10n.insightsPercent(percent),
                  style: percent == null
                      ? text.titleMedium?.copyWith(color: tokens.positiveInk)
                      : text.displaySmall?.copyWith(
                          color: tokens.positiveInk,
                          fontWeight: FontWeight.w700,
                        ),
                  textAlign: TextAlign.center,
                ),
                if (percent != null) ...[
                  const SizedBox(height: HabitSpace.s8),
                  Text(
                    l10n.insightsEligiblePeriods(totals.completed, totals.eligible),
                    style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (insights.byCategory.isNotEmpty) ...[
          const SizedBox(height: HabitSpace.s32),
          Semantics(header: true, child: Text(l10n.insightsByCategory, style: text.titleLarge)),
          const SizedBox(height: HabitSpace.s16),
          for (final row in insights.byCategory) ...[
            Semantics(
              container: true,
              label: l10n.insightsCategoryLabel(
                format.category(row.category, long: true),
                row.completed,
                row.eligible,
                row.percent ?? 0,
              ),
              excludeSemantics: true,
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            format.category(row.category, long: true),
                            style: text.titleMedium,
                          ),
                        ),
                        Text(
                          l10n.insightsCategoryCount(row.completed, row.eligible),
                          style: text.bodyMedium?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: HabitSpace.s12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(HabitRadius.r4),
                      child: LinearProgressIndicator(
                        value: row.eligible == 0 ? 0 : row.completed / row.eligible,
                        minHeight: 8,
                        color: tokens.progress,
                        backgroundColor: tokens.border,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HabitSpace.s12),
          ],
        ],
        const SizedBox(height: HabitSpace.s16),
        Text(l10n.insightsMonthFooter, style: text.bodySmall?.copyWith(color: tokens.muted)),
      ],
    );
  }
}
