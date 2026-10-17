import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/reward_history.dart';
import '../data/rewards_view.dart';
import '../domain/calendar/local_date.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/ledger_pager.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import 'widgets/ledger_list.dart';

/// Screen 16, "Progress you earned". The level and XP are reward_state as the server last
/// confirmed them, so they show offline (A44). Recent XP is an explicit network action: GET
/// /rewards, shown from memory, never written to the database.
class ProgressScreen extends StatelessWidget {
  final DateTime Function() clock;

  const ProgressScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    return MultiProvider(
      key: ValueKey(account.session.userId),
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              StreamModel<ConfirmedRewardNumbers?>(Future.value(account.rewards.watch())),
        ),
        ChangeNotifierProvider(
          create: (_) => LedgerPager<XpRow>((cursor) async {
            final api = account.rewardsApi ?? (throw StateError('No server for this account.'));
            final page = await api.fetchRewards(cursor: cursor);
            final rows = await RewardHistory(account.view).xpRows(page.ledger, clock());
            return LedgerPage(rows, page.nextCursor);
          })..load(),
        ),
      ],
      child: const _ProgressBody(),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final rewards = context.watch<StreamModel<ConfirmedRewardNumbers?>>().value;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          // ASSUMPTION(A5-progress-subtitle): the design's "After your meditation check-in."
          // names the check-in that led here (5.2c); opened from Profile there is none.
          ScreenHeader(
            title: l10n.progressTitle,
            onBack: () => context.canPop() ? context.pop() : context.go(Routes.profile),
          ),
          if (rewards == null)
            Text(l10n.progressNoNumbers, style: text.bodyMedium?.copyWith(color: tokens.muted))
          else
            _LevelCard(rewards: rewards),
          const SizedBox(height: HabitSpace.s32),
          Semantics(header: true, child: Text(l10n.progressRecent, style: text.titleLarge)),
          const SizedBox(height: HabitSpace.s16),
          LedgerList<XpRow>(rowBuilder: (context, row) => _XpRowView(row: row)),
          const SizedBox(height: HabitSpace.s24),
          Text(l10n.progressFooter, style: text.bodyMedium?.copyWith(color: tokens.muted)),
        ],
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
    return Container(
      padding: const EdgeInsets.all(HabitSpace.s32),
      decoration: BoxDecoration(
        color: tokens.positiveBg,
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Column(
        children: [
          Text(
            l10n.progressLevel(rewards.level),
            style: text.labelLarge?.copyWith(color: tokens.positiveInk),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HabitSpace.s24),
          Text(
            l10n.progressXp(rewards.xp),
            style: text.displaySmall?.copyWith(
              color: tokens.positiveInk,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (progress != null) ...[
            const SizedBox(height: HabitSpace.s24),
            // The bar is decoration; the label below carries the meaning (A44).
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HabitRadius.r4),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  color: tokens.progress,
                  backgroundColor: tokens.border,
                ),
              ),
            ),
            const SizedBox(height: HabitSpace.s16),
            Text(
              l10n.progressToward(progress.into, progress.span, progress.nextLevel),
              style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _XpRowView extends StatelessWidget {
  final XpRow row;

  const _XpRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final day = dayLabel(l10n, format, row.dayWord, row.date);
    final value = row.completedLocally
        ? format.amount(row.rules, row.completedValue, row.unit)
        : null;
    final detail = switch (row.kind) {
      XpRowKind.completion =>
        value == null ? l10n.xpRowCompleted(day) : l10n.xpRowCompletedValue(day, value),
      XpRowKind.changed => l10n.xpRowChanged(day),
      XpRowKind.unknown => l10n.xpRowUnknown(day),
    };
    return LedgerRow(
      icon: HabitFormat.icon(row.rules),
      tone: Tone.positive,
      title: row.habitName ?? l10n.ledgerHabitUnknown,
      detail: detail,
      amount: row.delta < 0 ? l10n.xpAmountReturned(-row.delta) : l10n.xpAmountGained(row.delta),
      amountColor: row.delta < 0 ? tokens.muted : tokens.positiveInk,
    );
  }
}

/// "Today", "Yesterday" or "20 May", from the account calendar's day words.
String dayLabel(AppLocalizations l10n, HabitFormat format, DayWord word, LocalDate? date) =>
    switch (word) {
      DayWord.today => l10n.ledgerToday,
      DayWord.yesterday => l10n.ledgerYesterday,
      DayWord.date => date == null ? '' : format.dayMonth(date),
    };
