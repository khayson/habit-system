import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/account_calendar.dart';
import '../data/profile_view.dart';
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

/// The wallet facts only GET /freezes knows (A43): held in memory for this screen.
class WalletFacts {
  final int cap;
  final LocalDate? nextRefillOn;

  /// The account calendar's year today, so the refill date shows a year only when it differs.
  final int? thisYear;

  const WalletFacts({required this.cap, required this.nextRefillOn, required this.thisYear});
}

/// Screen 17, "A little breathing room". The balance is reward_state and the switch is the
/// local profile overlay, so both work offline; the cap, the refill date and the usage
/// history come from GET /freezes (an explicit network action, never stored).
class FreezesScreen extends StatelessWidget {
  final DateTime Function() clock;

  const FreezesScreen({super.key, this.clock = DateTime.now});

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
          create: (_) => StreamModel<ProfileState?>(Future.value(account.profile.watch())),
        ),
        ChangeNotifierProvider(create: (_) => ValueNotifier<WalletFacts?>(null)),
        ChangeNotifierProvider(
          create: (context) {
            final facts = context.read<ValueNotifier<WalletFacts?>>();
            return LedgerPager<FreezeRow>((cursor) async {
              final api = account.rewardsApi ?? (throw StateError('No server for this account.'));
              final page = await api.fetchFreezes(cursor: cursor);
              final now = clock();
              final rows = await RewardHistory(account.view).freezeRows(page.ledger, now);
              if (cursor == null) {
                final calendar = await AccountCalendar.load(account.session.db, deviceNow: now);
                final today = calendar?.today(now);
                facts.value = WalletFacts(
                  cap: page.cap,
                  nextRefillOn: _date(page.nextRefillOn),
                  thisYear: today == null ? null : _year(today),
                );
              }
              return LedgerPage(rows, page.nextCursor);
            })..load();
          },
        ),
      ],
      child: const _FreezesBody(),
    );
  }

  static LocalDate? _date(String value) {
    try {
      return LocalDate.parse(value);
    } on Object {
      return null;
    }
  }
}

DateTime _utc(LocalDate date) =>
    DateTime.fromMillisecondsSinceEpoch(date.midnightMillis, isUtc: true);

int _year(LocalDate date) =>
    DateTime.fromMillisecondsSinceEpoch(date.midnightMillis, isUtc: true).year;

class _FreezesBody extends StatelessWidget {
  const _FreezesBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          ScreenHeader(
            title: l10n.freezesTitle,
            subtitle: l10n.freezesSubtitle,
            onBack: () => context.canPop() ? context.pop() : context.go(Routes.profile),
          ),
          const _WalletCard(),
          const SizedBox(height: HabitSpace.s24),
          const _AutoProtectRow(),
          const SizedBox(height: HabitSpace.s32),
          Semantics(header: true, child: Text(l10n.freezesHistory, style: text.titleLarge)),
          const SizedBox(height: HabitSpace.s16),
          LedgerList<FreezeRow>(rowBuilder: (context, row) => _FreezeRowView(row: row)),
          const SizedBox(height: HabitSpace.s24),
          InfoCard(title: l10n.freezeNoteTitle, body: l10n.freezeNoteBody),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final balance = context.watch<StreamModel<ConfirmedRewardNumbers?>>().value?.freezeBalance;
    final facts = context.watch<ValueNotifier<WalletFacts?>>().value;
    final refill = facts?.nextRefillOn;
    final refillText = refill == null
        ? null
        : l10n.freezesRefill(
            facts?.thisYear == _year(refill)
                ? l10n.refillDate(_utc(refill))
                : l10n.refillDateYear(_utc(refill)),
            facts!.cap,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HabitSpace.s32),
      decoration: BoxDecoration(
        color: tokens.infoBg,
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Column(
        children: [
          ExcludeSemantics(child: Icon(Icons.ac_unit, size: 56, color: tokens.infoInk)),
          const SizedBox(height: HabitSpace.s16),
          Text(
            balance == null
                ? l10n.freezesNoNumbers
                : facts == null
                ? l10n.freezesBalance(balance)
                : l10n.freezesBalanceCap(balance, facts.cap),
            style: balance == null
                ? text.bodyMedium?.copyWith(color: tokens.muted)
                : text.headlineMedium?.copyWith(color: tokens.ink),
            textAlign: TextAlign.center,
          ),
          if (balance != null && refillText != null) ...[
            const SizedBox(height: HabitSpace.s12),
            Text(
              refillText,
              style: text.bodyMedium?.copyWith(color: tokens.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _AutoProtectRow extends StatelessWidget {
  const _AutoProtectRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final account = context.read<AccountContext>();
    final profile = context.watch<StreamModel<ProfileState?>>().value;
    final on = profile?.autoFreeze ?? false;

    Future<void> toggle() async {
      await account.writer.setAutoFreeze(!on);
      account.sync.scheduleAfterWrite();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          toggled: on,
          label: l10n.autoProtectTitle,
          hint: l10n.autoProtectBody,
          onTap: profile == null ? null : toggle,
          excludeSemantics: true,
          child: SurfaceCard(
            onTap: profile == null ? null : toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: HabitSize.minTarget),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.autoProtectTitle, style: text.titleMedium ?? text.bodyLarge),
                        const SizedBox(height: HabitSpace.s8),
                        Text(
                          l10n.autoProtectBody,
                          style: text.bodySmall?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: HabitSpace.s12),
                  Switch(value: on, onChanged: profile == null ? null : (_) => toggle()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: HabitSpace.s8),
        // ASSUMPTION(A11-prospective-line): the design does not say that opting in is
        // prospective; one neutral line does.
        Text(l10n.autoProtectProspective, style: text.bodySmall?.copyWith(color: tokens.muted)),
        if (profile != null && profile.autoFreezeNeedsAttention) ...[
          const SizedBox(height: HabitSpace.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HabitSize.minTarget),
            child: TextButton.icon(
              onPressed: () => context.push(Routes.queue),
              icon: const Icon(Icons.error_outline),
              label: Text(l10n.autoProtectNeedsLook),
            ),
          ),
        ] else if (profile != null && profile.autoFreezeQueued) ...[
          const SizedBox(height: HabitSpace.s8),
          Row(
            children: [
              Icon(Icons.schedule, size: HabitSize.icon, color: tokens.infoInk),
              const SizedBox(width: HabitSpace.s8),
              Expanded(
                child: Text(
                  l10n.autoProtectQueued,
                  style: text.bodyMedium?.copyWith(color: tokens.infoInk),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FreezeRowView extends StatelessWidget {
  final FreezeRow row;

  const _FreezeRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final date = row.date == null ? '' : format.dayMonth(row.date!);
    final title = row.aboutHabit
        ? l10n.freezeRowTitle(row.habitName ?? l10n.ledgerHabitUnknown, date)
        : switch (row.kind) {
            FreezeRowKind.signupGrant => l10n.freezeSignup,
            FreezeRowKind.monthlyGrant => l10n.freezeMonthly,
            FreezeRowKind.alreadyFull => l10n.freezeAlreadyFull,
            _ => l10n.freezeUnknown,
          };
    final detail = switch (row.kind) {
      FreezeRowKind.spend => switch (row.period) {
        PeriodWord.daily => l10n.freezeSpendDaily,
        PeriodWord.weekly => l10n.freezeSpendWeekly,
        PeriodWord.other => l10n.freezeSpendOther,
      },
      FreezeRowKind.refund => l10n.freezeRefund,
      FreezeRowKind.refundAtCap => l10n.freezeRefundAtCap,
      _ => date,
    };
    return LedgerRow(
      icon: Icons.ac_unit,
      tone: Tone.info,
      title: title,
      detail: detail,
      amount: row.delta == 0 ? '0' : signed(row.delta),
      amountColor: tokens.infoInk,
    );
  }
}
