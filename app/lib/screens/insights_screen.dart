import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../core/file_sharer.dart';
import '../data/local_view.dart';
import '../domain/calendar/local_date.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/insights.dart';
import '../providers/account_context.dart';
import '../sync/outbox_states.dart';
import '../widgets/app_toast.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screens 14 (Week) and 15 (Month), one screen with the design's switch (A47). Shows what GET
/// /insights sent and computes no rule: the last answer this session at once, then a fresh one.
/// An explicit network action (CLAUDE.md, Flutter rules): loading, error and Try again apply.
class InsightsScreen extends StatefulWidget {
  /// A56: "Share progress" hands an image of the summary card to the system share sheet; the
  /// person chooses where it goes. Nothing is posted by the app.
  final FileSharer sharer;

  const InsightsScreen({super.key, this.sharer = const SharePlusFileSharer()});

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
  Map<String, (String?, String?, String?)> _habits = const {};

  /// 5.3b review L1: unsent check-ins seen on the last queue change; when they all reach the
  /// server, the numbers are fetched again so they include them.
  AccountContext? _account;
  bool _hadWaiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.read<AccountContext?>();
    if (!identical(account, _account)) {
      _account?.queue.removeListener(_onQueue);
      _account = account;
      account?.queue.addListener(_onQueue);
      _hadWaiting = _waiting(account);
    }
    if (_shown == null && !_loading) _load();
  }

  @override
  void dispose() {
    _account?.queue.removeListener(_onQueue);
    super.dispose();
  }

  static bool _waiting(AccountContext? account) =>
      (account?.queue.value?.items ?? const <QueueItem>[]).any(
        (i) => i.row.entity == 'habit_log' && OutboxState.unacked.contains(i.row.state),
      );

  void _onQueue() {
    final waiting = _waiting(_account);
    if (_hadWaiting && !waiting && mounted) _load();
    _hadWaiting = waiting;
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
        h.id: (h.payload['name'] as String?, h.icon, h.category),
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

  final _summaryKey = GlobalKey();
  bool _sharing = false;

  /// Renders the summary card (categories and totals only, no habit names) to a PNG in a
  /// temporary folder, shares it, then deletes it.
  Future<void> _share() async {
    final toast = AppToast.of(context);
    final failed = AppLocalizations.of(context).insightsShareFailed;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final boundary = _summaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _sharing = true);
    File? file;
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) throw StateError('no png');
      final root = await widget.sharer.temporaryRoot();
      file = File(p.join(root.path, 'habit-progress-$_period.png'));
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      await widget.sharer.share(file.path);
    } catch (_) {
      toast.show(failed, tone: ToastTone.info);
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _sharing = false);
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
              // A56: the mockup's ✕ closes Insights; like Profile, a tab root goes back to Today.
              onClose: () => context.go(Routes.today),
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
                return _waiting(account)
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
            // 5.3b review L2: a refresh that failed while numbers are shown says so.
            if (shown != null && _failed) ...[
              Text(l10n.insightsRefreshFailed, style: muted),
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
              const SizedBox(height: HabitSpace.s8),
            ],
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
            ] else ...[
              if (shown.byCategory.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text(l10n.insightsByCategory, style: text.titleLarge),
                ),
                const SizedBox(height: HabitSpace.s16),
                _CategoryBars(rows: shown.byCategory),
                const SizedBox(height: HabitSpace.s24),
              ],
              RepaintBoundary(
                key: _summaryKey,
                child: _Summary(insights: shown),
              ),
              const SizedBox(height: HabitSpace.s16),
              FilledButton(onPressed: _sharing ? null : _share, child: Text(l10n.insightsShare)),
              const SizedBox(height: HabitSpace.s24),
              if (week)
                _Week(insights: shown, habits: _habits)
              else
                Text(
                  l10n.insightsMonthFooter,
                  style: text.bodySmall?.copyWith(color: tokens.muted),
                ),
            ],
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

/// A56: the mockups' tall bars, one per category the server counted: the share of closed,
/// eligible periods completed, the percentage inside the bar and the category below. The bars
/// show what GET /insights sent; nothing is computed here.
class _CategoryBars extends StatelessWidget {
  static const double height = 240;

  /// A few categories still read as bars, not blocks (well under [height]).
  static const double maxWidth = 72;

  /// The shortest fill: room for its percentage.
  static const double minFill = 48;

  final List<CategoryInsight> rows;

  const _CategoryBars({required this.rows});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final colors = [
      (tokens.chartBrown, tokens.onAccent),
      (tokens.chartRust, tokens.onAccent),
      (tokens.chartLime, tokens.ink),
      (tokens.chartPink, tokens.ink),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(width: HabitSpace.s8),
          Expanded(
            child: _CategoryBar(
              row: rows[i],
              fill: colors[i % colors.length].$1,
              onFill: colors[i % colors.length].$2,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryInsight row;
  final Color fill;
  final Color onFill;

  const _CategoryBar({required this.row, required this.fill, required this.onFill});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final percent = row.percent;
    return Semantics(
      container: true,
      label: l10n.insightsCategoryLabel(
        format.category(row.category, long: true),
        row.completed,
        row.eligible,
        percent ?? 0,
      ),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: _CategoryBars.height,
            width: _CategoryBars.maxWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // Never shorter than the percentage it carries.
                final filled = percent == null
                    ? 0.0
                    : (constraints.maxHeight * percent / 100).clamp(
                        _CategoryBars.minFill,
                        constraints.maxHeight,
                      );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(width / 2),
                  child: CustomPaint(
                    painter: _HatchPainter(background: tokens.background, line: tokens.chartTrack),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: percent == null
                          ? null
                          : Container(
                              height: filled,
                              width: width,
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: HabitSpace.s12),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(width / 2),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s4),
                                  child: Text(
                                    l10n.insightsPercent(percent),
                                    style: text.titleSmall?.copyWith(
                                      color: onFill,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: HabitSpace.s12),
          Text(
            format.category(row.category),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: tokens.ink),
          ),
        ],
      ),
    );
  }
}

/// The bars' empty track: thin diagonal lines on the background, as drawn.
class _HatchPainter extends CustomPainter {
  final Color background;
  final Color line;

  const _HatchPainter({required this.background, required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    const gap = 10.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.background != background || old.line != line;
}

/// A56: the white summary card under the bars: XP earned this period, then the consistency the
/// server counted. It is also the image [InsightsScreen] hands to the share sheet.
class _Summary extends StatelessWidget {
  final Insights insights;

  const _Summary({required this.insights});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final week = insights.period == 'week';
    final totals = insights.totals;
    final percent = totals.percent;
    final through = insights.window.through;
    final periods = week
        ? l10n.insightsClosedPeriods(totals.completed, totals.eligible)
        : l10n.insightsEligiblePeriods(totals.completed, totals.eligible);
    final caption = text.bodySmall?.copyWith(color: tokens.muted);
    return Container(
      padding: const EdgeInsets.all(HabitSpace.s24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week ? l10n.insightsSummaryWeek : l10n.insightsSummaryMonth,
                      style: text.titleMedium,
                    ),
                    if (week) ...[
                      const SizedBox(height: HabitSpace.s4),
                      Text(
                        through == null
                            ? l10n.insightsNoClosedDays
                            : l10n.insightsThrough(format.dayMonth(LocalDate.parse(through))),
                        style: caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: HabitSpace.s12),
              Text(
                l10n.insightsXp(insights.xpEarned),
                style: text.titleLarge?.copyWith(color: tokens.accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: HabitSpace.s16),
          Divider(height: 1, color: tokens.border),
          const SizedBox(height: HabitSpace.s16),
          if (percent == null)
            Text(l10n.insightsNoClosedPeriods, style: text.bodyLarge, textAlign: TextAlign.center)
          else
            Semantics(
              container: true,
              label: '${l10n.insightsPercent(percent)}, $periods',
              excludeSemantics: true,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(l10n.insightsConsistency, style: caption),
                          const SizedBox(height: HabitSpace.s4),
                          Text(
                            l10n.insightsPercent(percent),
                            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(width: HabitSpace.s24, color: tokens.border),
                    Expanded(
                      child: Center(
                        child: Text(periods, style: text.bodyLarge, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  final Insights insights;
  final Map<String, (String?, String?, String?)> habits;

  const _Week({required this.insights, required this.habits});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final days = insights.days ?? const <InsightsDay>[];
    final scale = InsightsDay.scale(days);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  IconTile(
                    icon: HabitFormat.icon(habits[open.habitId]?.$2, habits[open.habitId]?.$3),
                    tile: HabitTile.forCategory(habits[open.habitId]?.$3),
                  ),
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
