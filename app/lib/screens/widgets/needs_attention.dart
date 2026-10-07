import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../config/habit_tokens.dart';
import '../../data/app_database.dart';
import '../../data/entity_codec.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/account_context.dart';

/// Why the server did not take a change, in plain words (no blame, no loss threats).
String reasonText(AppLocalizations l10n, String? lastError) {
  final error = EntityCodec.decodeJson(lastError);
  final code = error is Map ? error['code'] : null;
  return switch (code) {
    'version_conflict' => l10n.reasonVersionConflict,
    'resource_deleted' => l10n.reasonResourceDeleted,
    'parent_rejected' => l10n.reasonParentRejected,
    'future_event' => l10n.reasonFutureEvent,
    _ => l10n.reasonGeneric,
  };
}

/// Confirms, then discards (recorded in discarded_mutations). Destructive actions always ask
/// first (design: behavior contract).
Future<bool> confirmDiscard(BuildContext context, AccountContext account, OutboxRow row) async {
  final l10n = AppLocalizations.of(context);
  final tokens = HabitTokens.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.discardTitle),
      content: Text(l10n.discardBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: tokens.errorInk),
          child: Text(l10n.discardConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  return account.actions.discard(row.mutationId);
}

/// The resolve sheet for a habit-day whose change needs a decision (Phase 2b.1 review §6). Full
/// conflict review (screen 19) arrives in Phase 4.
Future<void> showNeedsAttention(BuildContext context, AccountContext account, OutboxRow row) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      final tokens = HabitTokens.of(sheet);
      return SafeArea(
        child: Padding(
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
              Text(l10n.resolveTitle, style: text.titleLarge),
              const SizedBox(height: HabitSpace.s8),
              Text(
                reasonText(l10n, row.lastError),
                style: text.bodyLarge?.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: HabitSpace.s24),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push(Routes.queue);
                },
                child: Text(l10n.resolveOpenQueue),
              ),
              const SizedBox(height: HabitSpace.s12),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: tokens.errorInk),
                onPressed: () async {
                  final done = await confirmDiscard(sheet, account, row);
                  if (done && sheet.mounted) Navigator.pop(sheet);
                },
                child: Text(l10n.resolveDiscard),
              ),
            ],
          ),
        ),
      );
    },
  );
}
