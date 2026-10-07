import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/local_view.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../sync/outbox_states.dart';
import '../widgets/habit_ui.dart';
import '../widgets/sync_status_chip.dart';
import 'widgets/needs_attention.dart';

/// Screen 18: what is saved on this device and not yet confirmed. Counts by state, the queued
/// changes, "Discard" for changes that need a decision, "Try again" for ones backing off, the
/// paused reason, and "Sync now".
///
/// The design's "Background sync" row is left out: background sync arrives in Phase 5 and the
/// screen must not claim it (honest status).
class SyncQueueScreen extends StatelessWidget {
  const SyncQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([account.queue, account.sync]),
          builder: (context, _) {
            final queue = account.queue.value;
            return ListView(
              padding: const EdgeInsets.all(HabitSpace.margin),
              children: [
                ScreenHeader(
                  title: l10n.queueTitle,
                  subtitle: l10n.queueSubtitle,
                  onBack: () => context.canPop() ? context.pop() : context.go(Routes.today),
                  trailing: const SyncStatusChip(),
                ),
                if (queue != null) ..._content(context, account, queue),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, AccountContext account, QueueView queue) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final lastSynced = queue.state.lastSyncedAt;
    final time = lastSynced == null
        ? l10n.queueNever
        : DateFormat.jm(Localizations.localeOf(context).toLanguageTag())
              .format(DateTime.fromMillisecondsSinceEpoch(lastSynced));

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Stat(value: '${queue.waiting}', label: l10n.queuePending),
          ),
          const SizedBox(width: HabitSpace.gutter),
          Expanded(
            child: _Stat(value: time, label: l10n.queueLastSynced),
          ),
        ],
      ),
      const SizedBox(height: HabitSpace.s24),
      if (queue.paused)
        InfoCard(
          title: l10n.queuePausedTitle,
          body: l10n.queuePausedBody(queue.state.statusCode ?? '—'),
          tone: Tone.warning,
          icon: Icons.pause_circle_outline,
        )
      else if (account.sync.offline)
        InfoCard(
          title: l10n.queueOfflineTitle,
          body: l10n.queueOfflineBody,
          tone: Tone.info,
          icon: Icons.cloud_off_outlined,
        )
      else if (queue.items.isEmpty)
        InfoCard(
          title: l10n.queueSyncedTitle,
          body: l10n.queueSyncedBody,
          icon: Icons.cloud_done_outlined,
        ),
      const SizedBox(height: HabitSpace.s24),
      for (final item in queue.items) ...[
        _QueueRow(item: item, account: account),
        const SizedBox(height: HabitSpace.s12),
      ],
      const SizedBox(height: HabitSpace.s12),
      OutlinedButton.icon(
        onPressed: account.sync.syncing ? null : () => account.sync.sync(force: true),
        icon: account.sync.syncing
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
        label: Text(l10n.queueSyncNow),
      ),
      const SizedBox(height: HabitSpace.s24),
      Text(l10n.queueFooter, style: text.bodySmall?.copyWith(color: tokens.muted)),
    ];
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.headlineMedium),
          Text(label, style: text.bodySmall?.copyWith(color: tokens.muted)),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final QueueItem item;
  final AccountContext account;

  const _QueueRow({required this.item, required this.account});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final row = item.row;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final at = DateTime.tryParse(row.occurredAt)?.toLocal();
    final when = at == null ? '' : DateFormat.MMMd(locale).add_jm().format(at);

    final (stateLabel, tone) = switch (row.state) {
      OutboxState.inFlight => (l10n.queueStateSending, Tone.info),
      OutboxState.blocked => (l10n.queueStateRetrying, Tone.warning),
      OutboxState.waiting => (l10n.queueStateWaiting, Tone.info),
      OutboxState.needsAttention => (l10n.queueStateNeedsLook, Tone.warning),
      _ => (l10n.queueStateQueued, Tone.info),
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: row.entity == 'habit' ? Icons.add_task : Icons.check, tone: tone),
              const SizedBox(width: HabitSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.queueItemTitle(item.habitName ?? l10n.queueUnnamedHabit, _change(l10n)),
                      style: text.titleMedium ?? text.bodyLarge,
                    ),
                    const SizedBox(height: HabitSpace.s4),
                    Text(
                      row.state == OutboxState.needsAttention
                          ? reasonText(l10n, row.lastError)
                          : l10n.queueItemWhen(when),
                      style: text.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HabitSpace.s8),
              Text(stateLabel, style: text.titleSmall?.copyWith(color: tone.ink(tokens))),
            ],
          ),
          if (row.state == OutboxState.needsAttention)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: tokens.errorInk),
                onPressed: () => confirmDiscard(context, account, row),
                child: Text(l10n.discardConfirm),
              ),
            ),
          if (row.state == OutboxState.blocked)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await account.actions.retryNow(row.mutationId);
                },
                child: Text(l10n.queueTryAgain),
              ),
            ),
        ],
      ),
    );
  }

  /// What the change does, from the operation and the type rules (no type keys here).
  String _change(AppLocalizations l10n) {
    final row = item.row;
    if (row.operation == 'habit.create') return l10n.queueChangeNewHabit;
    if (row.operation == 'log.delete') return l10n.queueChangeRemoved;
    if (row.operation == 'log.set_value') {
      final value = item.payload['value'];
      final zero = ProvisionalTypeRegistry.builtins().all.any((r) => r.parseValue(value) == 0);
      return zero ? l10n.queueChangeUndo : l10n.queueChangeCheckIn;
    }
    return l10n.queueChangeOther;
  }
}
