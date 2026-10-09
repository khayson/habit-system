import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../domain/calendar/local_date.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screen 12: habit detail with the month heatmap. Offline-first: closed days from the server's
/// period_evaluations, today and open days from local logs (provisional), not-due from the
/// schedule. Streak numbers are habit_progress as the server confirmed it (invariant 9).
/// Choosing a day opens 13 with that local date.
class HabitDetailScreen extends StatelessWidget {
  final String habitId;
  final DateTime Function() clock;

  const HabitDetailScreen({super.key, required this.habitId, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/$habitId'),
      create: (_) => StreamModel<HabitDetail?>(
        TimeZones.ready.then((_) => account.view.watchDetail(habitId, clock)),
      ),
      child: _Detail(habitId: habitId),
    );
  }
}

class _Detail extends StatefulWidget {
  final String habitId;

  const _Detail({required this.habitId});

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  /// Months before the current one (0 = this month).
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<StreamModel<HabitDetail?>>().value;
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    if (detail == null) return const SafeArea(child: SizedBox());

    final definition = detail.definitionToday;
    final amount = format.amount(
      detail.rules,
      detail.targetOn(detail.today),
      (definition?.wire['unit'] ?? detail.habit.payload['unit']) as String?,
    );
    final frequency = format.frequency(definition?.frequency);
    final schedule = amount == null ? frequency : '$amount $frequency';
    final first = _firstMonth(detail);
    final monthStart = _monthStart(detail.today, _back);
    final protectedDays = detail.protectedInStreak;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          ScreenHeader(
            title: detail.name,
            subtitle: l10n.detailSubtitle(schedule, format.category(detail.category, long: true)),
            onBack: () => context.canPop() ? context.pop() : context.go(Routes.habits),
          ),
          _Stats(detail: detail),
          const SizedBox(height: HabitSpace.s32),
          Semantics(
            customSemanticsActions: {
              if (monthStart.isAfter(first))
                CustomSemanticsAction(label: l10n.heatmapPrevious): () => setState(() => _back++),
              if (_back > 0)
                CustomSemanticsAction(label: l10n.heatmapNext): () => setState(() => _back--),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 200 && monthStart.isAfter(first)) setState(() => _back++);
                if (v < -200 && _back > 0) setState(() => _back--);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(format.month(monthStart), style: text.titleLarge),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minHeight: HabitSize.minTarget),
                        padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.positiveBg,
                          borderRadius: BorderRadius.circular(HabitRadius.r24),
                        ),
                        child: Text(
                          l10n.heatmapMonth,
                          style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HabitSpace.s24),
                  _MonthGrid(detail: detail, monthStart: monthStart),
                ],
              ),
            ),
          ),
          if (_hasProvisional(detail, monthStart)) ...[
            const SizedBox(height: HabitSpace.s16),
            Text(l10n.heatmapProvisional, style: text.bodyMedium?.copyWith(color: tokens.muted)),
          ],
          const SizedBox(height: HabitSpace.s32),
          const _Legend(),
          const SizedBox(height: HabitSpace.s32),
          Text(
            [
              if (protectedDays > 0) l10n.streakProtected(protectedDays),
              l10n.streakPause,
            ].join('\n'),
            style: text.bodyLarge?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: HabitSpace.s32),
          _ReminderRow(detail: detail),
        ],
      ),
    );
  }

  /// Any day of the shown month whose status the device worked out itself (local months only).
  static bool _hasProvisional(HabitDetail detail, LocalDate monthStart) {
    if (monthStart.isBefore(detail.today.addDays(-localHeatmapDays))) return false;
    final end = _monthEnd(monthStart);
    for (var d = monthStart; !d.isAfter(end); d = d.addDays(1)) {
      if (detail.isProvisional(d)) return true;
    }
    return false;
  }

  static LocalDate _monthStart(LocalDate today, int back) {
    final d = DateTime.fromMillisecondsSinceEpoch(today.midnightMillis, isUtc: true);
    final m = DateTime.utc(d.year, d.month - back);
    return LocalDate.ofWallClockMillis(m.millisecondsSinceEpoch);
  }

  /// The month of the habit's first definition: nothing earlier can be due.
  static LocalDate _firstMonth(HabitDetail detail) {
    final start = detail.schedule.versions.isEmpty
        ? detail.today
        : detail.schedule.versions.first.effectiveDate;
    final d = DateTime.fromMillisecondsSinceEpoch(start.midnightMillis, isUtc: true);
    return LocalDate.ofWallClockMillis(DateTime.utc(d.year, d.month).millisecondsSinceEpoch);
  }
}

/// 12's Reminder row (3.2c): None, the time and days, or Off; opens 11 in live mode.
/// The design reaches 11 from 08, 09 and 20; this row is the way in until 09 exists (Phase 4).
class _ReminderRow extends StatelessWidget {
  final HabitDetail detail;

  const _ReminderRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String time(String hhmm) {
      final parts = hhmm.split(':');
      return DateFormat.jm(locale)
          .format(DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
    }

    String days(List<int> d) {
      final sorted = [...d]..sort();
      if (sorted.length == 7) return l10n.reminderSummaryEveryDay;
      if (sorted.join(',') == '1,2,3,4,5') return l10n.reminderSummaryWeekdays;
      // 5 January 2026 was a Monday.
      return sorted.map((x) => DateFormat.E(locale).format(DateTime(2026, 1, 4 + x))).join(', ');
    }

    final on = detail.reminders.where((r) => r.enabled).toList();
    final String summary;
    if (detail.reminders.isEmpty) {
      summary = l10n.reminderSummaryNone;
    } else if (on.isEmpty) {
      summary = l10n.reminderSummaryOff;
    } else if (on.length == 1) {
      summary = l10n.reminderSummary(time(on.single.localTime), days(on.single.daysOfWeek));
    } else {
      summary = on.map((r) => time(r.localTime)).join(' · ');
    }
    return SurfaceCard(
      onTap: () => context.push(Routes.habitReminder(detail.habit.id)),
      semanticsLabel: '${l10n.reminderRow}, $summary',
      child: ExcludeSemantics(
        child: Row(
          children: [
            const IconTile(icon: Icons.notifications_none),
            const SizedBox(width: HabitSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.reminderRow, style: text.titleMedium ?? text.bodyLarge),
                  const SizedBox(height: HabitSpace.s4),
                  Text(summary, style: text.bodySmall?.copyWith(color: tokens.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.primary),
          ],
        ),
      ),
    );
  }
}

/// The three stat cards: current streak, best streak, today (design 12).
class _Stats extends StatelessWidget {
  final HabitDetail detail;

  const _Stats({required this.detail});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final progress = detail.progress;

    String streak(int? count) {
      if (count == null) return l10n.statNotYet;
      return switch (progress?.unit) {
        'weeks' => l10n.statWeeks(count),
        'periods' => l10n.statPeriods(count),
        _ => l10n.statDays(count),
      };
    }

    final asOf = detail.streakAsOf;
    final due = detail.schedule.isDue(detail.today, detail.timeline);
    final done = detail.isComplete(detail.today);
    final todayValue = detail.logOn(detail.today)?.value;
    final String today;
    if (!due) {
      today = l10n.statusNotDue;
    } else if (detail.rules?.display == TypeDisplay.yesNo || detail.rules == null) {
      today = done ? l10n.statDone : l10n.statNotYet;
    } else {
      today =
          format.amount(detail.rules, todayValue ?? detail.rules!.formatValue(0), _unit) ??
          l10n.statNotYet;
    }

    final cards = [
      (
        streak(progress?.current),
        asOf == null ? l10n.statCurrent : l10n.statCurrentAsOf(format.dayMonth(asOf)),
      ),
      (streak(progress?.longest), l10n.statBest),
      (today, done ? l10n.statTodayDone : l10n.statToday),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = HabitSpace.s12;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final perRow = constraints.maxWidth / 3 - gap >= 104 * scale ? 3 : 1;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (value, label) in cards)
              SizedBox(
                width: width,
                child: _StatCard(value: value, label: label),
              ),
          ],
        );
      },
    );
  }

  String? get _unit =>
      (detail.definitionToday?.wire['unit'] ?? detail.habit.payload['unit']) as String?;
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Semantics(
      label: '$value, $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s12, vertical: HabitSpace.s16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(HabitRadius.r24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: HabitSpace.s4),
            Text(label, style: text.bodySmall?.copyWith(fontSize: 12, color: tokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final HabitDetail detail;
  final LocalDate monthStart;

  const _MonthGrid({required this.detail, required this.monthStart});

  @override
  Widget build(BuildContext context) {
    final account = context.read<AccountContext?>()!;
    final remote = monthStart.isBefore(detail.today.addDays(-localHeatmapDays));
    if (!remote) return _Grid(detail: detail, monthStart: monthStart, statuses: null);
    final end = _monthEnd(monthStart);
    final heatmap = account.heatmap;
    return FutureBuilder<Map<String, String>>(
      key: ValueKey(monthStart),
      future: heatmap == null
          ? Future.error(StateError('offline'))
          : heatmap.fetch(detail.habit.id, monthStart, end),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
        final text = Theme.of(context).textTheme;
        final tokens = HabitTokens.of(context);
        if (snapshot.hasData) {
          return _Grid(detail: detail, monthStart: monthStart, statuses: snapshot.data);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: HabitSpace.s48),
          child: Text(
            snapshot.hasError ? l10n.olderNeedsConnection : l10n.olderLoading,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: tokens.muted),
          ),
        );
      },
    );
  }
}

LocalDate _monthEnd(LocalDate monthStart) {
  final d = DateTime.fromMillisecondsSinceEpoch(monthStart.midnightMillis, isUtc: true);
  return LocalDate.ofWallClockMillis(DateTime.utc(d.year, d.month + 1).millisecondsSinceEpoch)
      .addDays(-1);
}

class _Grid extends StatelessWidget {
  final HabitDetail detail;
  final LocalDate monthStart;

  /// From the server for months older than the local window; null = local data.
  final Map<String, String>? statuses;

  const _Grid({required this.detail, required this.monthStart, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final end = _monthEnd(monthStart);
    final lead = monthStart.isoWeekday - 1;
    final days = monthStart.daysUntil(end) + 1;
    final rows = ((lead + days) / 7).ceil();
    // 4 May 2026 was a Monday.
    final weekdays = [
      for (var i = 0; i < 7; i++) DateFormat.EEEEE(locale).format(DateTime.utc(2026, 5, 4 + i)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = HabitSpace.s8;
        final cell = math.max(HabitSize.minTarget, (constraints.maxWidth - gap * 6) / 7);
        final width = cell * 7 + gap * 6;
        Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(width: cell, child: children[i]),
              ],
            ],
          ),
        );
        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: row([
                for (final w in weekdays)
                  Center(
                    child: Text(w, style: text.bodySmall?.copyWith(color: tokens.muted)),
                  ),
              ]),
            ),
            for (var r = 0; r < rows; r++)
              row([
                for (var c = 0; c < 7; c++)
                  if (r * 7 + c < lead || r * 7 + c - lead >= days)
                    SizedBox(height: cell)
                  else
                    _Cell(
                      detail: detail,
                      date: monthStart.addDays(r * 7 + c - lead),
                      size: cell,
                      remote: statuses,
                    ),
              ]),
          ],
        );
        // At large text the grid keeps 44 px cells and scrolls sideways rather than clipping.
        return width > constraints.maxWidth
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)
            : grid;
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final HabitDetail detail;
  final LocalDate date;
  final double size;
  final Map<String, String>? remote;

  const _Cell({required this.detail, required this.date, required this.size, this.remote});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final status = remote == null
        ? detail.statusOn(date)
        : (dayStatusFromWire(remote![date.toString()]) ?? DayStatus.notDue);
    final provisional = remote == null && detail.isProvisional(date);

    final statusText = switch (status) {
      DayStatus.complete => l10n.statusComplete,
      DayStatus.protected => l10n.statusProtected,
      DayStatus.missed => l10n.statusMissed,
      DayStatus.notDue => l10n.statusNotDue,
      DayStatus.pending => l10n.statusPending,
      DayStatus.upcoming => l10n.statusUpcoming,
    };
    final label = provisional
        ? l10n.cellLabelProvisional(format.fullDate(date), statusText)
        : l10n.cellLabel(format.fullDate(date), statusText);

    final (Color? fill, Color ink, String? mark) = switch (status) {
      DayStatus.complete => (tokens.positiveBg, tokens.positiveInk, null),
      DayStatus.protected => (tokens.infoBg, tokens.infoInk, '✱'),
      DayStatus.missed => (tokens.border, tokens.muted, '–'),
      DayStatus.notDue || DayStatus.pending || DayStatus.upcoming => (null, tokens.muted, null),
    };
    final dashed = status == DayStatus.pending || status == DayStatus.upcoming;
    final radius = BorderRadius.circular(HabitRadius.r12);
    final tappable = !date.isAfter(detail.today);

    Widget box = CustomPaint(
      painter: dashed ? _DashedBorder(color: tokens.muted, radius: HabitRadius.r12) : null,
      child: Container(
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: status == DayStatus.notDue ? Border.all(color: tokens.border) : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text('${_day(date)}', style: text.bodyLarge?.copyWith(color: ink)),
            ),
            if (mark != null)
              Positioned(
                top: 2,
                right: 6,
                child: Text(
                  mark,
                  style: text.bodySmall?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
    if (tappable) {
      box = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push(Routes.history(detail.habit.id, date: date.toString())),
          child: box,
        ),
      );
    }
    return Semantics(
      container: true,
      label: label,
      button: tappable,
      excludeSemantics: true,
      child: box,
    );
  }

  static int _day(LocalDate date) =>
      DateTime.fromMillisecondsSinceEpoch(date.midnightMillis, isUtc: true).day;
}

/// Complete / Protected / Missed (–) / Not due (outline), as in the design.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    Widget item(String label, Color? fill, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(HabitRadius.r4),
            border: outline ? Border.all(color: tokens.border) : null,
          ),
        ),
        const SizedBox(width: HabitSpace.s12),
        Flexible(
          child: Text(label, style: text.bodyLarge?.copyWith(color: tokens.muted)),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - HabitSpace.s16) / 2;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final width = half >= 150 * scale ? half : constraints.maxWidth;
        return Wrap(
          spacing: HabitSpace.s16,
          runSpacing: HabitSpace.s16,
          children: [
            SizedBox(width: width, child: item(l10n.legendComplete, tokens.positiveBg)),
            SizedBox(width: width, child: item(l10n.legendProtected, tokens.infoBg)),
            SizedBox(width: width, child: item(l10n.legendMissed, tokens.border)),
            SizedBox(width: width, child: item(l10n.legendNotDue, null, outline: true)),
          ],
        );
      },
    );
  }
}

/// The design's dashed outline for days that are still open or ahead.
class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
