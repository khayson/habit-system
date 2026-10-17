import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/account_calendar.dart';
import '../data/rewards_view.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// What the screen says about the habit, read from local data once.
class _Completed {
  final String name;
  final ProvisionalTypeRules? rules;
  final Object? value;
  final String? unit;

  const _Completed(this.name, this.rules, this.value, this.unit);
}

/// Screens 06 (duration) and 35 (quantity), one layout (A46). Opened only by a save screen for
/// an accepted ack with xp_delta above 0. The chip is that xp_delta; the Level card is the
/// local reward_state, live, so a later page's reward_state updates it (A44).
class CompletionScreen extends StatelessWidget {
  final String habitId;
  final int xpDelta;
  final DateTime Function() clock;

  const CompletionScreen({
    super.key,
    required this.habitId,
    required this.xpDelta,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return MultiProvider(
      key: ValueKey('${account.session.userId}/$habitId'),
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              StreamModel<ConfirmedRewardNumbers?>(Future.value(account.rewards.watch())),
        ),
        ChangeNotifierProvider(
          create: (_) => StreamModel<_Completed?>(Future.value(Stream.fromFuture(_load(account)))),
        ),
      ],
      child: _CompletionBody(xpDelta: xpDelta),
    );
  }

  Future<_Completed?> _load(AccountContext account) async {
    final now = clock();
    final habit = (await account.view.habits(deviceNow: now))
        .where((h) => h.id == habitId)
        .firstOrNull;
    if (habit == null) return null;
    final calendar = await AccountCalendar.load(account.session.db, deviceNow: now);
    final today = calendar?.today(now);
    final log = today == null ? null : await account.view.log(habitId, today.toString());
    final p = habit.payload;
    return _Completed(
      p['name'] as String? ?? '',
      account.view.types.lookup(p['type'] as String? ?? ''),
      log?.value,
      p['unit'] as String?,
    );
  }
}

class _CompletionBody extends StatefulWidget {
  final int xpDelta;

  const _CompletionBody({required this.xpDelta});

  @override
  State<_CompletionBody> createState() => _CompletionBodyState();
}

class _CompletionBodyState extends State<_CompletionBody> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final habit = context.watch<StreamModel<_Completed?>>().value;
    final rewards = context.watch<StreamModel<ConfirmedRewardNumbers?>>().value;
    final value = habit == null ? null : format.amount(habit.rules, habit.value, habit.unit);
    // A short fade only, and none when the device asks for reduced motion (invariant 12).
    final still = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: still || _shown ? 1 : 0,
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              ScreenHeader(
                title: l10n.completeTitle,
                subtitle: l10n.completeSubtitle,
                onBack: () => context.canPop() ? context.pop() : context.go(Routes.today),
              ),
              const SizedBox(height: HabitSpace.s32),
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(color: tokens.positiveBg, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 64, color: tokens.positiveInk),
                  ),
                ),
              ),
              const SizedBox(height: HabitSpace.s32),
              if (habit != null)
                Semantics(
                  header: true,
                  child: Text(
                    l10n.completeHeading(habit.name),
                    style: text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (value != null) ...[
                const SizedBox(height: HabitSpace.s8),
                Text(
                  l10n.completeLine(value),
                  style: text.bodyLarge?.copyWith(color: tokens.muted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: HabitSpace.s16),
              Center(
                child: Semantics(
                  label: l10n.completeXpChipLabel(widget.xpDelta),
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HabitSpace.s24,
                      vertical: HabitSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.positiveBg,
                      borderRadius: BorderRadius.circular(HabitRadius.r16),
                    ),
                    child: Text(
                      l10n.completeXpChip(widget.xpDelta),
                      style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                    ),
                  ),
                ),
              ),
              if (rewards != null) ...[
                const SizedBox(height: HabitSpace.s32),
                _LevelCard(rewards: rewards),
              ],
              const SizedBox(height: HabitSpace.s48),
              PrimaryButton(label: l10n.completeBack, onPressed: () => context.go(Routes.today)),
              const SizedBox(height: HabitSpace.s16),
              Text(
                l10n.completeFooter,
                style: text.bodySmall?.copyWith(color: tokens.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final ConfirmedRewardNumbers rewards;

  const _LevelCard({required this.rewards});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final progress = LevelProgress.of(rewards);
    final label = progress == null
        ? '${l10n.completeLevel(rewards.level)}, ${l10n.completeXpTotal(rewards.xp)}'
        : l10n.completeLevelCardLabel(
            rewards.level,
            rewards.xp,
            progress.into,
            progress.span,
            progress.nextLevel,
          );
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: HabitSpace.s12,
              runSpacing: HabitSpace.s4,
              children: [
                Text(l10n.completeLevel(rewards.level), style: text.titleLarge),
                Text(
                  l10n.completeXpTotal(rewards.xp),
                  style: text.bodyLarge?.copyWith(color: tokens.positiveInk),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: HabitSpace.s16),
              ClipRRect(
                borderRadius: BorderRadius.circular(HabitRadius.r4),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  color: tokens.progress,
                  backgroundColor: tokens.border,
                ),
              ),
              const SizedBox(height: HabitSpace.s12),
              Text(
                l10n.progressToward(progress.into, progress.span, progress.nextLevel),
                style: text.bodyMedium?.copyWith(color: tokens.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
