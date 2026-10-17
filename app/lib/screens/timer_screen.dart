import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/completion_wait.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screens 33 (running) and 36 (paused): one screen over the habit's timer draft (A36). The time
/// shown comes from the draft's stored values and the injected clock, so closing or killing the
/// app never loses time. No notification, no wake lock: nothing runs when the screen is closed.
class TimerScreen extends StatelessWidget {
  final String habitId;
  final DateTime Function() clock;

  const TimerScreen({super.key, required this.habitId, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return MultiProvider(
      key: ValueKey('${account.session.userId}/$habitId/timer'),
      providers: [
        ChangeNotifierProvider(
          create: (_) => StreamModel<HabitDetail?>(
            TimeZones.ready.then((_) => account.view.watchDetail(habitId, clock)),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StreamModel<TimerDraftView?>(Future.value(account.actions.watchTimer(habitId))),
        ),
      ],
      child: _Timer(habitId: habitId, clock: clock),
    );
  }
}

class _Timer extends StatefulWidget {
  final String habitId;
  final DateTime Function() clock;

  const _Timer({required this.habitId, required this.clock});

  @override
  State<_Timer> createState() => _TimerState();
}

class _TimerState extends State<_Timer> {
  Timer? _ticker;
  bool _leaving = false;
  bool _busy = false;

  /// A finish that could not be saved: the words, and whether the hint shows. The draft stays.
  String? _failure;
  bool _failureHint = false;

  /// A46: waiting for the ack of a finish that completed the day, with the snackbar line the
  /// screen shows when it leaves as before.
  CompletionWait? _wait;
  String? _savedLine;

  @override
  void dispose() {
    _wait?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _tick(bool running) {
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Back to Today with a short line (the draft is gone: saved, empty or discarded elsewhere).
  void _leave(String message) {
    if (_leaving) return;
    _leaving = true;
    _wait?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.today);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pause and resume (4.3b L2): a refusal (the habit archived since the screen opened) shows
  /// the failure card with Discard timer; nothing escapes, nothing is lost.
  Future<void> _guarded(Future<Object?> Function() action) => _run(() async {
    try {
      await action();
    } on TimerFailure catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _failure = e.kind == TimerFailureKind.archived ? l10n.timerArchived : l10n.timerGone;
        _failureHint = false;
      });
    }
  });

  Future<void> _finish(AccountContext account) => _run(() async {
    final l10n = AppLocalizations.of(context);
    final elapsed = context.read<StreamModel<TimerDraftView?>>().value?.elapsed(widget.clock());
    try {
      final write = await account.actions.finishTimer(widget.habitId);
      if (!mounted) return;
      if (write == null) {
        _leave(l10n.timerNothingToSave);
      } else {
        final seconds = elapsed?.inSeconds ?? 0;
        final saved = seconds < 60
            ? l10n.timerSavedSeconds(seconds)
            : l10n.timerSavedMinutes(seconds ~/ 60);
        final wait = CompletionWait.start(account, write);
        if (wait == null) return _leave(saved);
        setState(() {
          _wait = wait;
          _savedLine = saved;
        });
        final delta = await wait.result;
        if (!mounted || _leaving) return;
        if (delta != null && account.ackWatch.firstOpening(write.mutationId)) {
          _leaving = true;
          context.pushReplacement(Routes.complete(widget.habitId), extra: delta);
        } else {
          _leave(saved);
        }
      }
    } on TimerFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = switch (e.kind) {
          TimerFailureKind.archived => l10n.timerArchived,
          TimerFailureKind.noDraft => l10n.timerGone,
          _ => l10n.timerTooLong,
        };
        _failureHint = e.kind == TimerFailureKind.tooLong;
      });
    } on LogFailure {
      if (mounted) {
        setState(() {
          _failure = l10n.timerTooMuchToday;
          _failureHint = false;
        });
      }
    }
  });

  Future<void> _discard(AccountContext account) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        final text = Theme.of(sheet).textTheme;
        final tokens = HabitTokens.of(sheet);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              HabitSpace.margin,
              0,
              HabitSpace.margin,
              HabitSpace.margin,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.timerDiscardTitle, style: text.titleLarge),
                ),
                const SizedBox(height: HabitSpace.s8),
                Text(l10n.timerDiscardBody, style: text.bodyLarge?.copyWith(color: tokens.muted)),
                const SizedBox(height: HabitSpace.s24),
                PrimaryButton(
                  label: l10n.timerDiscardConfirm,
                  onPressed: () => Navigator.pop(sheet, true),
                ),
                const SizedBox(height: HabitSpace.s8),
                TextButton(
                  onPressed: () => Navigator.pop(sheet, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                  ),
                  child: Text(l10n.timerKeep),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    _leaving = true;
    await account.actions.discardTimer(widget.habitId);
    if (mounted) context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    final detailModel = context.watch<StreamModel<HabitDetail?>>();
    final draftModel = context.watch<StreamModel<TimerDraftView?>>();
    final l10n = AppLocalizations.of(context);
    if (account == null || !draftModel.hasValue || !detailModel.hasValue) {
      return const Scaffold();
    }
    final draft = draftModel.value;
    final detail = detailModel.value;
    if (draft == null && _wait != null) {
      // A46: finished here and waiting for the ack; Back leaves as before.
      return _Confirming(onBack: () => _leave(_savedLine ?? l10n.timerGone));
    }
    if (draft == null) {
      // Finished or discarded elsewhere (or by this screen, which is already leaving).
      _tick(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leave(l10n.timerGone);
      });
      return const Scaffold();
    }
    final running = draft.state == TimerDraftView.running;
    _tick(running);

    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final rules = account.view.types.lookup(detail?.habit.payload['type'] as String? ?? '');
    final today = detail?.today;
    final targetSeconds = today == null ? null : rules?.parseTarget(detail!.targetOn(today));
    final saved = today == null ? 0 : rules?.parseValue(detail!.logOn(today)?.value) ?? 0;
    final elapsed = draft.elapsed(widget.clock());
    final name = detail?.name ?? '';
    final targetMinutes = targetSeconds == null ? '' : format.minutes(targetSeconds);
    final over = targetSeconds == null
        ? timerClock(elapsed)
        : l10n.timerOver(timerClock(elapsed), timerClock(Duration(seconds: targetSeconds)));

    Widget link(String label, VoidCallback? onPressed) => TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
      ),
      child: Text(label),
    );
    // Design 33 / 36: the secondary action is a light green button with green text.
    Widget tonal(String label, VoidCallback? onPressed) => SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.positiveBg,
          foregroundColor: tokens.positiveInk,
          minimumSize: const Size(HabitSize.minTarget, HabitSize.control),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
    final pause = _busy ? null : () => _guarded(() => account.actions.pauseTimer(widget.habitId));
    final resume = _busy ? null : () => _guarded(() => account.actions.resumeTimer(widget.habitId));
    final finish = _busy ? null : () => _finish(account);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: running ? l10n.timerRunningTitle : l10n.timerPausedTitle,
              subtitle: running
                  ? l10n.timerRunningSubtitle(name, targetMinutes)
                  : l10n.timerPausedSubtitle(name),
              // Back leaves the draft as it is.
              onBack: () => context.canPop() ? context.pop() : context.go(Routes.today),
            ),
            Container(
              padding: const EdgeInsets.all(HabitSpace.s16),
              decoration: BoxDecoration(
                color: tokens.positiveBg,
                borderRadius: BorderRadius.circular(HabitRadius.r16),
              ),
              child: Column(
                children: [
                  // One readable value, refreshed when the minute changes, not each second.
                  Semantics(
                    label: l10n.timerSpoken(elapsed.inMinutes, targetMinutes),
                    excludeSemantics: true,
                    child: Text(over, style: text.headlineSmall, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: HabitSpace.s8),
                  link(running ? l10n.timerPause : l10n.timerResume, running ? pause : resume),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s24),
            if (running)
              // ASSUMPTION(4.3b-timer-total): today's saved time plus this timer, whole minutes.
              Container(
                padding: const EdgeInsets.all(HabitSpace.s16),
                decoration: BoxDecoration(
                  color: tokens.positiveBg,
                  borderRadius: BorderRadius.circular(HabitRadius.r16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.timerTodayTotal((saved + elapsed.inSeconds) ~/ 60),
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: HabitSpace.s8),
                    Text(
                      l10n.timerKeepGoing,
                      style: text.bodyMedium?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              )
            else
              InfoCard(
                title: l10n.timerPausedCardTitle,
                body: l10n.timerPausedCardBody(elapsed.inMinutes),
                tone: Tone.info,
                icon: Icons.schedule,
              ),
            if (_failure != null) ...[
              const SizedBox(height: HabitSpace.s16),
              InfoCard(
                title: _failure!,
                body: _failureHint ? l10n.timerTooLongHint : null,
                tone: Tone.warning,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: HabitSpace.s8),
              tonal(l10n.timerDiscard, _busy ? null : () => _discard(account)),
            ],
            const SizedBox(height: HabitSpace.s32),
            if (running) ...[
              tonal(l10n.timerPauseButton, pause),
              const SizedBox(height: HabitSpace.s12),
              PrimaryButton(label: l10n.timerFinish, loading: _busy, onPressed: finish),
            ] else ...[
              PrimaryButton(label: l10n.timerResumeButton, onPressed: resume),
              const SizedBox(height: HabitSpace.s12),
              tonal(l10n.timerFinish, finish),
            ],
            const SizedBox(height: HabitSpace.s16),
            Text(
              running ? l10n.timerRunningNote : l10n.timerPausedNote,
              style: text.bodySmall?.copyWith(color: tokens.muted),
            ),
            if (_failure == null) ...[
              const SizedBox(height: HabitSpace.s8),
              // A design gap: a way to throw a timer away, behind a confirm sheet.
              Center(child: link(l10n.timerDiscard, _busy ? null : () => _discard(account))),
            ],
          ],
        ),
      ),
    );
  }
}

/// The timer's finish while it waits for the ack (A46): the draft is gone, the check-in saved.
class _Confirming extends StatelessWidget {
  final VoidCallback onBack;

  const _Confirming({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              ScreenHeader(title: '', onBack: onBack),
              const SizedBox(height: HabitSpace.s48),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: HabitSpace.s16),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.saveConfirming,
                  style: text.bodyMedium?.copyWith(color: tokens.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
