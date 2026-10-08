import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_view.dart';
import '../domain/calendar/day_resolver.dart';
import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screen 13: history and past check-ins for one habit. Reached from 12 with a chosen local
/// date. "Save past check-in" writes log.set_value with date_mode backdate + log_date through
/// LocalMutationService (offline, outbox first). Dates the server would refuse (after the local
/// today, more than 30 days back, habit not active) are refused here in plain words and nothing
/// is written.
class HistoryScreen extends StatelessWidget {
  final String habitId;
  final String? initialDate;
  final DateTime Function() clock;

  const HistoryScreen({
    super.key,
    required this.habitId,
    this.initialDate,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/$habitId'),
      create: (_) => StreamModel<HabitDetail?>(
        TimeZones.ready.then((_) => account.view.watchDetail(habitId, clock)),
      ),
      child: Scaffold(
        body: SafeArea(
          child: _History(habitId: habitId, initialDate: initialDate),
        ),
      ),
    );
  }
}

class _History extends StatefulWidget {
  final String habitId;
  final String? initialDate;

  const _History({required this.habitId, required this.initialDate});

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  final _value = TextEditingController();
  final _formKey = GlobalKey();
  int _tab = 1; // Today | History
  LocalDate? _date;
  bool _done = true;
  String? _refusal;
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  /// First frame with data: the chosen date (from 12) or yesterday, and that day's value.
  void _seed(HabitDetail detail, HabitFormat format) {
    if (_seeded) return;
    _seeded = true;
    final chosen = widget.initialDate == null ? null : LocalDate.parse(widget.initialDate!);
    _select(detail, format, chosen ?? detail.today.addDays(-1));
  }

  void _select(HabitDetail detail, HabitFormat format, LocalDate date) {
    _date = date;
    _refusal = null;
    final rules = detail.rules;
    final logged = detail.logOn(date)?.value;
    final units = rules?.parseValue(logged) ?? rules?.parseTarget(detail.targetOn(date));
    _done = logged == null || (units ?? 0) >= 1;
    _value.text = switch (rules?.display) {
      TypeDisplay.duration => units == null ? '' : format.minutes(units),
      TypeDisplay.quantity => units == null ? '' : format.decimal(units),
      _ => '',
    };
  }

  String? _refusalText(AppLocalizations l10n, String? code) => switch (code) {
    'backdate_future' => l10n.historyRefuseFuture,
    'backdate_too_old' => l10n.historyRefuseOld,
    'habit_not_active' => l10n.historyRefuseInactive,
    null => null,
    _ => l10n.historyRefuseInactive,
  };

  /// The wire value for the form, or null with [_refusal] set when it cannot be read.
  Object? _wireValue(HabitDetail detail, AppLocalizations l10n) {
    final rules = detail.rules!;
    switch (rules.display) {
      case TypeDisplay.yesNo:
        return rules.formatValue(_done ? 1 : 0);
      case TypeDisplay.duration:
        final minutes = int.tryParse(_value.text.trim());
        if (minutes == null || minutes < 0) {
          setState(() => _refusal = l10n.historyValueInvalidMinutes);
          return null;
        }
        return rules.formatValue(minutes * 60);
      case TypeDisplay.quantity:
        final match = RegExp(r'^(\d+)(?:[.,](\d{1,3}))?$').firstMatch(_value.text.trim());
        if (match == null) {
          setState(() => _refusal = l10n.historyValueInvalidAmount);
          return null;
        }
        final fraction = (match.group(2) ?? '').padRight(3, '0');
        return rules.formatValue(int.parse(match.group(1)!) * 1000 + int.parse(fraction));
    }
  }

  Future<void> _save(HabitDetail detail) async {
    final l10n = AppLocalizations.of(context);
    final account = context.read<AccountContext?>()!;
    final date = _date;
    if (date == null || detail.rules == null) return;
    final code = detail.backdateRefusal(date);
    if (code != null) {
      setState(() => _refusal = _refusalText(l10n, code));
      return;
    }
    final value = _wireValue(detail, l10n);
    if (value == null) return;
    setState(() => _saving = true);
    try {
      await account.actions.setValueOn(habitId: detail.habit.id, date: date, value: value);
      if (!mounted) return;
      setState(() => _refusal = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.historySaved)));
    } on DayResolutionException catch (e) {
      if (mounted) setState(() => _refusal = _refusalText(l10n, e.reason));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(HabitDetail detail, HabitFormat format) async {
    final today = detail.today;
    DateTime asDate(LocalDate d) =>
        DateTime.fromMillisecondsSinceEpoch(d.midnightMillis, isUtc: true);
    final first = today.addDays(-DayResolver.maxBackdateDays);
    final current = _date ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: asDate(current.isBefore(first) || current.isAfter(today) ? today : current),
      firstDate: asDate(first),
      lastDate: asDate(today),
      helpText: format.l10n.historyDateChoose,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _select(
        detail,
        format,
        LocalDate.ofWallClockMillis(
          DateTime.utc(picked.year, picked.month, picked.day).millisecondsSinceEpoch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<StreamModel<HabitDetail?>>().value;
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    if (detail == null) return const SizedBox();
    _seed(detail, format);

    final rows = detail.recentCheckIns
        .where((log) => (log.date == detail.today.toString()) == (_tab == 0))
        .toList();
    final date = _date!;
    final rules = detail.rules;
    final unit =
        (detail.schedule.versionOn(date)?.wire['unit'] ?? detail.habit.payload['unit']) as String?;
    final target = format.amount(rules, detail.targetOn(date), unit);

    return ListView(
      padding: const EdgeInsets.all(HabitSpace.margin),
      children: [
        ScreenHeader(
          title: l10n.historyTitle,
          subtitle: l10n.historySubtitle,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.habit(detail.habit.id)),
        ),
        SegmentedTabs(
          labels: [l10n.historyTabToday, l10n.historyTabHistory],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: HabitSpace.s16),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HabitSpace.s16),
            child: Text(
              _tab == 0 ? l10n.historyEmptyToday : l10n.historyEmpty,
              style: text.bodyLarge?.copyWith(color: tokens.muted),
            ),
          ),
        for (final log in rows) ...[
          _CheckInRow(
            detail: detail,
            log: log,
            onEdit: () {
              setState(() => _select(detail, format, LocalDate.parse(log.date)));
              final form = _formKey.currentContext;
              if (form != null) Scrollable.ensureVisible(form, duration: Durations.medium2);
            },
          ),
          const SizedBox(height: HabitSpace.s12),
        ],
        const SizedBox(height: HabitSpace.s24),
        Semantics(
          key: _formKey,
          header: true,
          child: Text(l10n.historyAddTitle, style: text.titleLarge),
        ),
        const SizedBox(height: HabitSpace.s16),
        FieldLabel(l10n.historyDateLabel),
        const SizedBox(height: HabitSpace.s8),
        _FieldBox(
          semanticsLabel: '${l10n.historyDateChoose}, ${format.fullDate(date)}',
          onTap: () => _pickDate(detail, format),
          child: Text(format.fullDate(date), style: text.bodyLarge),
        ),
        const SizedBox(height: HabitSpace.s24),
        if (rules != null) ...[
          FieldLabel(switch (rules.display) {
            TypeDisplay.yesNo => l10n.historyValueCheckIn,
            TypeDisplay.duration => l10n.historyValueDuration,
            TypeDisplay.quantity => l10n.historyValueAmount,
          }),
          const SizedBox(height: HabitSpace.s8),
          if (rules.display == TypeDisplay.yesNo)
            SegmentedTabs(
              labels: [l10n.historyValueDone, l10n.historyValueNotDone],
              selected: _done ? 0 : 1,
              onSelected: (i) => setState(() => _done = i == 0),
            )
          else
            TextField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: rules.display == TypeDisplay.duration ? l10n.historyMinutesUnit : unit,
              ),
            ),
          if (target != null) ...[
            const SizedBox(height: HabitSpace.s8),
            Text(l10n.historyTarget(target), style: text.bodySmall?.copyWith(color: tokens.muted)),
          ],
          const SizedBox(height: HabitSpace.s24),
        ],
        if (_refusal != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(_refusal!, style: text.bodyMedium?.copyWith(color: tokens.errorInk)),
          ),
          const SizedBox(height: HabitSpace.s12),
        ],
        Text(l10n.historyNote, style: text.bodyMedium?.copyWith(color: tokens.muted)),
        const SizedBox(height: HabitSpace.s32),
        PrimaryButton(
          label: l10n.historySave,
          loading: _saving,
          onPressed: rules == null ? null : () => _save(detail),
        ),
      ],
    );
  }
}

class _CheckInRow extends StatelessWidget {
  final HabitDetail detail;
  final LogView log;
  final VoidCallback onEdit;

  const _CheckInRow({required this.detail, required this.log, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final date = LocalDate.parse(log.date);
    final rules = detail.rules;
    final unit =
        (detail.schedule.versionOn(date)?.wire['unit'] ?? detail.habit.payload['unit']) as String?;
    final value =
        format.amount(rules, log.value, unit) ??
        ((rules?.parseValue(log.value) ?? 0) >= 1
            ? l10n.historyValueDone
            : l10n.historyValueNotDone);
    final at = log.changedAt;
    final line = log.provisional || at == null
        ? l10n.historyRowWaiting(value)
        : l10n.historyRowDetail(value, format.time(detail.calendar.localTimeAt(at)));
    final title = l10n.historyRow(format.dayMonth(date), detail.name);

    return SurfaceCard(
      child: Row(
        children: [
          ExcludeSemantics(child: IconTile(icon: HabitFormat.icon(rules))),
          const SizedBox(width: HabitSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium ?? text.bodyLarge),
                const SizedBox(height: HabitSpace.s4),
                Text(line, style: text.bodySmall?.copyWith(color: tokens.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
            ),
            child: Semantics(
              label: l10n.historyEditLabel(format.dayMonth(date)),
              excludeSemantics: true,
              child: Text(l10n.historyEdit),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's white input box, used as a button for the date.
class _FieldBox extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _FieldBox({required this.child, required this.onTap, required this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HabitRadius.r16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HabitSize.controlLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s24),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
