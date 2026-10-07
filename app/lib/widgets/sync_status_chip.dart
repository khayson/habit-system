import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../providers/sync_provider.dart';
import 'habit_ui.dart';

/// The honest sync status (design: "Local saved is not server synced"), most important first:
/// paused, needs a look, syncing, offline, waiting, synced. Always text plus a symbol.
class SyncStatusChip extends StatelessWidget {
  final VoidCallback? onTap;

  const SyncStatusChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([account.sync, account.queue]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final (label, tone, icon) = describe(l10n, account.sync, account.queue);
        return StatusChip(
          label: label,
          tone: tone,
          icon: icon,
          onTap: onTap,
          semanticsLabel: onTap == null ? label : l10n.chipOpenQueue(label),
        );
      },
    );
  }

  static (String, Tone, IconData) describe(
    AppLocalizations l10n,
    SyncProvider sync,
    StreamModel<QueueView> queue,
  ) {
    final q = queue.value;
    if (q != null && q.paused) return (l10n.chipPaused, Tone.warning, Icons.pause_circle_outline);
    if (q != null && q.needsAttention.isNotEmpty) {
      return (l10n.chipNeedsLook, Tone.warning, Icons.error_outline);
    }
    if (sync.syncing) return (l10n.chipSyncing, Tone.info, Icons.sync);
    if (sync.offline) return (l10n.chipOffline, Tone.warning, Icons.cloud_off_outlined);
    if (q != null && q.waiting > 0) {
      return (l10n.chipWaiting(q.waiting), Tone.info, Icons.schedule);
    }
    if (q != null && q.state.lastSyncedAt == null) {
      return (l10n.chipNotYet, Tone.info, Icons.cloud_queue);
    }
    return (l10n.chipSynced, Tone.positive, Icons.cloud_done_outlined);
  }
}
