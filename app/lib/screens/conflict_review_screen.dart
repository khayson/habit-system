import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/conflicts.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../domain/calendar/local_date.dart';
import '../domain/frequency_choice.dart';
import '../domain/habit_draft_diff.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import '../widgets/schedule_text.dart';
import 'widgets/needs_attention.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_toast.dart';

/// Screen 19: review one change the server did not take (A37). It follows the queued row
/// (watchConflicts), so a sync or another screen resolving it shows here at once. Keep synced is
/// always the primary, safe choice; neither choice asks first (the old value stays in
/// discarded_mutations).
class ConflictReviewScreen extends StatelessWidget {
  final String mutationId;
  final DateTime Function() clock;

  const ConflictReviewScreen({super.key, required this.mutationId, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/review/$mutationId'),
      create: (_) => StreamModel<ConflictView?>(
        Future.value(
          account.view.watchConflicts().map(
            (all) => all.where((c) => c.mutationId == mutationId).firstOrNull,
          ),
        ),
      ),
      child: _Review(mutationId: mutationId, clock: clock),
    );
  }
}

class _Review extends StatefulWidget {
  final String mutationId;
  final DateTime Function() clock;

  const _Review({required this.mutationId, required this.clock});

  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  StreamModel<HabitDetail?>? _detail;
  String? _detailFor;
  bool _busy = false;

  /// The label of the button whose write runs, so its own spinner shows (4.3c review note b).
  String? _pressed;
  bool _leaving = false;

  @override
  void dispose() {
    _detail?.dispose();
    super.dispose();
  }

  /// The habit's detail (type, unit in force, calendar), opened once the conflict names it.
  HabitDetail? _habit(AccountContext account, String? habitId) {
    if (habitId == null) return null;
    if (_detailFor != habitId) {
      _detail?.dispose();
      _detailFor = habitId;
      _detail = StreamModel<HabitDetail?>(
        TimeZones.ready.then((_) => account.view.watchDetail(habitId, widget.clock)),
      )..addListener(() => mounted ? setState(() {}) : null);
    }
    return _detail!.value;
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.queue);

  void _leave(String message, {ToastTone tone = ToastTone.positive}) {
    if (_leaving) return;
    _leaving = true;
    final toast = AppToast.of(context);
    _back();
    toast.show(message, tone: tone);
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keep(AccountContext account) => _act(() async {
    final l10n = AppLocalizations.of(context);
    final result = await account.actions.keepSynced(widget.mutationId);
    if (mounted) {
      final done = result == ResolveResult.done;
      _leave(
        done ? l10n.reviewKeptSynced : l10n.reviewGone,
        tone: done ? ToastTone.positive : ToastTone.info,
      );
    }
  });

  Future<void> _mine(AccountContext account) => _act(() async {
    final l10n = AppLocalizations.of(context);
    final result = await account.actions.useMine(widget.mutationId);
    if (mounted) {
      final done = result == ResolveResult.done;
      _leave(
        done ? l10n.reviewUsedMine : l10n.reviewGone,
        tone: done ? ToastTone.positive : ToastTone.info,
      );
    }
  });

  Future<void> _discard(AccountContext account) => _act(() async {
    final row = await account.view.outboxRow(widget.mutationId);
    if (row == null || !mounted) return;
    final done = await confirmDiscard(context, account, row);
    if (done && mounted) _leave(AppLocalizations.of(context).reviewDiscarded);
  });

  Future<void> _restore(AccountContext account, String habitId) => _act(() async {
    try {
      await account.actions.restoreHabit(habitId);
    } on HabitEditFailure {
      // The habit is gone, or another change to it needs a look first (4.3c review note e).
      if (mounted) _leave(AppLocalizations.of(context).reviewGone, tone: ToastTone.info);
    }
  });

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    final model = context.watch<StreamModel<ConflictView?>>();
    final l10n = AppLocalizations.of(context);
    if (account == null || !model.hasValue) return const Scaffold();
    final conflict = model.value;
    if (conflict == null) {
      // Synced, or resolved elsewhere: say so, and wait for the person.
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              ScreenHeader(title: l10n.reviewTitle, onBack: _back),
              InfoCard(title: l10n.reviewGone, tone: Tone.info, icon: AppIcons.done),
              const SizedBox(height: HabitSpace.s16),
              TextButton(
                onPressed: _back,
                style: TextButton.styleFrom(
                  minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                ),
                child: Text(l10n.amountBack),
              ),
            ],
          ),
        ),
      );
    }
    final detail = _habit(account, conflict.habitId);
    // 4.3c review L1: until the habit has loaded, show nothing rather than the discard-only
    // variant a missing habit gets.
    if (conflict.habitId != null && _detail?.hasValue != true) return const Scaffold();
    final plan = _Plan.of(context, conflict, detail);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(title: l10n.reviewTitle, subtitle: plan.subtitle, onBack: _back),
            if (plan.safeTitle != null) ...[
              InfoCard(
                title: plan.safeTitle!,
                body: plan.safeBody,
                tone: Tone.warning,
                icon: AppIcons.privacy,
              ),
              const SizedBox(height: HabitSpace.s24),
            ],
            if (plan.mine != null) ...[
              _ValueCard(title: l10n.reviewOnDevice, card: plan.mine!, tone: Tone.neutral),
              const SizedBox(height: HabitSpace.s16),
            ],
            if (plan.synced != null) ...[
              _ValueCard(title: plan.syncedTitle, card: plan.synced!, tone: Tone.positive),
              const SizedBox(height: HabitSpace.s24),
            ],
            if (plan.note != null) ...[
              Text(
                plan.note!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: HabitTokens.of(context).muted),
              ),
              const SizedBox(height: HabitSpace.s32),
            ],
            ..._buttons(context, account, conflict, detail, plan),
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons(
    BuildContext context,
    AccountContext account,
    ConflictView conflict,
    HabitDetail? detail,
    _Plan plan,
  ) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    VoidCallback? press(String label, VoidCallback onPressed) => _busy
        ? null
        : () {
            _pressed = label;
            onPressed();
          };
    Widget primary(String label, VoidCallback onPressed) => PrimaryButton(
      label: label,
      loading: _busy && _pressed == label,
      onPressed: press(label, onPressed),
    );
    Widget secondary(String label, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: press(label, onPressed),
        style: FilledButton.styleFrom(
          backgroundColor: tokens.positiveBg,
          foregroundColor: tokens.positiveInk,
          minimumSize: const Size(HabitSize.minTarget, HabitSize.control),
        ),
        child: _busy && _pressed == label
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: tokens.positiveInk),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
    const gap = SizedBox(height: HabitSpace.s12);
    void keep() => _keep(account);
    void mine() => _mine(account);
    void discard() => _discard(account);

    switch (plan.variant) {
      case _Variant.bothRemoved:
        return [primary(l10n.reviewDone, keep)];
      case _Variant.other:
        return [secondary(l10n.reviewDiscardChange, discard)];
      case _Variant.archived:
        final active = detail != null && !detail.habit.archived;
        if (!active || !conflict.canUseMine) {
          return [
            primary(l10n.reviewRestore(plan.habit), () => _restore(account, conflict.habitId!)),
            gap,
            secondary(l10n.reviewDiscardCheckIn, discard),
          ];
        }
        return [
          primary(l10n.reviewSaveCheckIn(plan.mineValue), mine),
          gap,
          secondary(l10n.reviewDiscardCheckIn, discard),
        ];
      case _Variant.deleted:
        return [
          primary(l10n.reviewKeepDeleted, keep),
          if (conflict.canUseMine) ...[gap, secondary(l10n.reviewBringBack(plan.mineValue), mine)],
        ];
      case _Variant.staleRemove:
        return [
          primary(l10n.reviewKeepSynced(plan.syncedValue), keep),
          if (conflict.canUseMine) ...[gap, secondary(l10n.reviewRemoveEntry, mine)],
        ];
      case _Variant.staleHabit:
      case _Variant.staleHabitChoice:
        return [
          primary(l10n.reviewKeepSyncedVersion, keep),
          if (conflict.canUseMine) ...[
            gap,
            secondary(
              plan.variant == _Variant.staleHabit
                  ? l10n.reviewUseMyVersion
                  : l10n.reviewUseMyChoice,
              mine,
            ),
          ],
        ];
      case _Variant.staleValue:
        return [
          primary(l10n.reviewKeepSynced(plan.syncedValue), keep),
          if (conflict.canUseMine) ...[gap, secondary(l10n.reviewUseMine(plan.mineValue), mine)],
        ];
    }
  }
}

enum _Variant {
  staleValue,
  staleRemove,
  deleted,
  bothRemoved,
  archived,
  staleHabit,
  staleHabitChoice,
  other,
}

/// One card's content: the value (or field lines) and its line.
class _Card {
  final List<String> values;
  final String? line;

  /// A glyph drawn before a value, by its index (the habit's icon, A53); the text says it.
  final Map<int, AppIconData> icons;

  const _Card(this.values, this.line, {this.icons = const {}});
}

/// What 19 shows for one conflict: the variant, the copy and both cards.
class _Plan {
  final _Variant variant;
  final String habit;
  final String subtitle;
  final String? safeTitle;
  final String? safeBody;
  final _Card? mine;
  final _Card? synced;
  final String syncedTitle;
  final String? note;
  final String mineValue;
  final String syncedValue;

  const _Plan({
    required this.variant,
    required this.habit,
    required this.subtitle,
    this.safeTitle,
    this.safeBody,
    this.mine,
    this.synced,
    required this.syncedTitle,
    this.note,
    this.mineValue = '',
    this.syncedValue = '',
  });

  static final _types = HabitTypeUiRegistry.builtins();

  static _Plan of(BuildContext context, ConflictView c, HabitDetail? detail) {
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final habit = c.habitName ?? detail?.name ?? '';
    final type = _types.lookup(detail?.habit.payload['type'] as String?);
    final day = c.localDate;
    final unit = day == null
        ? null
        : detail?.schedule.unitOn(day) ?? detail?.habit.payload['unit'] as String?;
    String entry(int? units) =>
        units == null || type == null ? '' : type.entryText(format, units, unit);
    String at() {
      final when = c.occurredAt;
      if (when == null || detail == null) return '';
      final local = detail.calendar.localTimeAt(when);
      final localDay = LocalDate.ofWallClockMillis(
        DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch,
      );
      return localDay == detail.today ? format.time(local) : l10n.dayMonthTime(local, local);
    }

    final base = c.baseVersion ?? 0;
    // An increment has no base version (A35): its line names the time only.
    // An increment has no base version (A35): "Added at"; a first entry of the day has base 0.
    String edited() => switch (c.baseVersion) {
      null when c.operation == 'log.increment' => l10n.reviewAddedAt(at()),
      null => l10n.reviewEditedAtOnly(at()),
      0 => l10n.reviewEditedAtFirst(at()),
      final v => l10n.reviewEditedAt(at(), v),
    };
    String removed() =>
        base == 0 ? l10n.reviewRemovedAtFirst(at()) : l10n.reviewRemovedAt(at(), base);
    final server = c.serverVersion ?? 0;
    final mineValue = entry(c.mineUnits);
    final syncedValue = entry(c.serverValueUnits);
    final date = day == null ? '' : format.dayMonth(day);

    // Kind other, or a habit this device cannot read: discard only.
    if (c.kind == ConflictKind.other || (c.habitId != null && detail == null)) {
      return _Plan(
        variant: _Variant.other,
        habit: habit,
        subtitle: reasonText(l10n, c.lastError),
        syncedTitle: l10n.reviewLatestEntry,
      );
    }
    switch (c.kind) {
      case ConflictKind.staleValue when c.operation == 'log.delete':
        // ASSUMPTION(4.3c-stale-remove): no design; the stale-value layout with "Entry removed".
        return _Plan(
          variant: _Variant.staleRemove,
          habit: habit,
          subtitle: l10n.reviewStaleSubtitle(habit, date),
          safeTitle: l10n.reviewSafeTitle,
          safeBody: l10n.reviewSafeStaleBody,
          mine: _Card([l10n.reviewEntryRemoved], removed()),
          synced: _Card([syncedValue], l10n.reviewEditedElsewhere(server)),
          syncedTitle: l10n.reviewLatestEntry,
          note: l10n.reviewNote,
          syncedValue: syncedValue,
        );
      case ConflictKind.staleValue:
        // ASSUMPTION(4.3c-date-line): the design's subtitle has no date; the day is added.
        return _Plan(
          variant: _Variant.staleValue,
          habit: habit,
          subtitle: l10n.reviewStaleSubtitle(habit, date),
          safeTitle: l10n.reviewSafeTitle,
          safeBody: l10n.reviewSafeStaleBody,
          mine: _Card([mineValue], edited()),
          synced: _Card([syncedValue], l10n.reviewEditedElsewhere(server)),
          syncedTitle: l10n.reviewLatestEntry,
          note: l10n.reviewNote,
          mineValue: mineValue,
          syncedValue: syncedValue,
        );
      case ConflictKind.deletedDay when c.operation == 'log.delete':
        // ASSUMPTION(4.3c-both-removed): nothing to decide; one Done.
        return _Plan(
          variant: _Variant.bothRemoved,
          habit: habit,
          subtitle: l10n.reviewBothRemoved,
          syncedTitle: l10n.reviewLatestEntry,
        );
      case ConflictKind.deletedDay:
        // ASSUMPTION(4.3c-deleted-day): no design; the value that would come back (A37).
        return _Plan(
          variant: _Variant.deleted,
          habit: habit,
          subtitle: l10n.reviewDeletedSubtitle(habit),
          safeTitle: l10n.reviewSafeTitle,
          safeBody: l10n.reviewDeletedBody,
          mine: _Card([mineValue], edited()),
          synced: _Card([l10n.reviewDeleted], l10n.reviewDeletedElsewhere(server)),
          syncedTitle: l10n.reviewLatestEntry,
          note: l10n.reviewNote,
          mineValue: mineValue,
        );
      case ConflictKind.archivedHabit:
        // ASSUMPTION(4.3c-archived-habit): no design; restore first, then save the check-in.
        return _Plan(
          variant: _Variant.archived,
          habit: habit,
          subtitle: l10n.reviewArchivedSubtitle(habit),
          safeTitle: l10n.reviewSafeTitle,
          safeBody: l10n.reviewArchivedBody(habit),
          mine: _Card([mineValue], edited()),
          synced: _Card([l10n.reviewArchived], l10n.reviewArchivedElsewhere),
          syncedTitle: l10n.reviewLatestEntry,
          mineValue: mineValue,
        );
      case ConflictKind.staleHabitEdit when c.mineHabit == null:
        // ASSUMPTION(4.3c-stale-archive): an archive or restore against a changed habit.
        final archive = c.operation == 'habit.archive';
        return _Plan(
          variant: _Variant.staleHabitChoice,
          habit: habit,
          subtitle: l10n.reviewHabitSubtitle(habit),
          safeTitle: l10n.reviewEditSafeTitle,
          safeBody: l10n.reviewEditSafeBody,
          mine: _Card([archive ? l10n.reviewArchiveThis : l10n.reviewRestoreThis], edited()),
          synced: _Card([
            switch (c.serverArchived) {
              true => l10n.reviewArchived,
              false => l10n.reviewActive,
              null => l10n.reviewChangedElsewhere,
            },
          ], l10n.reviewEditedElsewhere(server)),
          syncedTitle: l10n.reviewLatestVersion,
          note: l10n.reviewNote,
        );
      case ConflictKind.staleHabitEdit:
        // ASSUMPTION(4.3c-stale-habit): every differing field, both ways (4.3b review I4).
        final schedule = ScheduleText(context);
        final diff = HabitDraftDiff(
          category: (cat) => format.category(cat, long: true),
          target: (t, u) => type?.format(format, t, u) ?? '$t',
          schedule: (ft, cfg) => schedule.summary(FrequencyChoice(ft, cfg)),
          noUnit: () => l10n.reviewNoUnit,
        );
        final fields = c.serverHabit == null
            ? const <HabitFieldDiff>[]
            : diff.between(c.mineHabit!, c.serverHabit!, type?.rules);
        String label(HabitField f) => switch (f) {
          HabitField.name => l10n.reviewFieldName,
          HabitField.category => l10n.reviewFieldCategory,
          HabitField.target => l10n.reviewFieldTarget,
          HabitField.unit => l10n.reviewFieldUnit,
          HabitField.schedule => l10n.reviewFieldSchedule,
          HabitField.icon => l10n.reviewFieldIcon,
        };
        Map<int, AppIconData> glyphs(String? Function(HabitFieldDiff) key) => {
          for (final (i, f) in fields.indexed)
            if (key(f) != null) i: AppIcons.habit(key(f)),
        };
        return _Plan(
          variant: _Variant.staleHabit,
          habit: habit,
          subtitle: l10n.reviewHabitSubtitle(habit),
          safeTitle: l10n.reviewEditSafeTitle,
          safeBody: l10n.reviewEditSafeBody,
          mine: _Card(
            [for (final f in fields) l10n.reviewFieldLine(label(f.field), f.mine)],
            edited(),
            icons: glyphs((f) => f.mineIcon),
          ),
          // Note c: with no field to compare, say only that it changed there.
          synced: _Card(
            [for (final f in fields) l10n.reviewFieldLine(label(f.field), f.synced)],
            fields.isEmpty ? l10n.reviewChangedElsewhere : l10n.reviewEditedElsewhere(server),
            icons: glyphs((f) => f.syncedIcon),
          ),
          syncedTitle: l10n.reviewLatestVersion,
          note: '${l10n.reviewNote} ${l10n.reviewNoteFields}',
        );
      case ConflictKind.other:
        throw StateError('handled above');
    }
  }
}

/// "On this device" / "Latest synced entry": one semantic group that reads its value and line.
class _ValueCard extends StatelessWidget {
  final String title;
  final _Card card;
  final Tone tone;

  const _ValueCard({required this.title, required this.card, required this.tone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final single = card.values.length == 1;
    return Semantics(
      container: true,
      label: l10n.reviewCardSpoken(title, card.values.join('. '), card.line ?? ''),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HabitSpace.s16),
        decoration: BoxDecoration(
          color: tone == Tone.positive ? tokens.positiveBg : tokens.surface,
          borderRadius: BorderRadius.circular(HabitRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.bodyMedium?.copyWith(
                color: tone == Tone.positive ? tokens.positiveInk : tokens.muted,
              ),
            ),
            const SizedBox(height: HabitSpace.s8),
            for (final (i, v) in card.values.indexed)
              if (card.icons[i] case final glyph?)
                Row(
                  children: [
                    AppIcon(glyph, size: 20, color: tokens.ink),
                    const SizedBox(width: HabitSpace.s8),
                    Expanded(child: Text(v, style: single ? text.headlineMedium : text.bodyLarge)),
                  ],
                )
              else
                Text(v, style: single ? text.headlineMedium : text.bodyLarge),
            if (card.line != null && card.line!.isNotEmpty) ...[
              const SizedBox(height: HabitSpace.s8),
              Text(card.line!, style: text.bodySmall?.copyWith(color: tokens.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
