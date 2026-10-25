import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../config/habit_tokens.dart';
import '../../data/local_mutation_service.dart' show HabitEditFailure, HabitEditFailureKind;
import '../../l10n/generated/app_localizations.dart';
import '../../providers/account_context.dart';
import '../../widgets/habit_ui.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_toast.dart';
import '../privacy_screen.dart' show tonalButton;

/// A51: a habit row that can be swiped (Habits 07 and Archived routines 22, never Today).
///
/// - Right past [threshold] of the row: [onRight] runs at once (archive on 07, restore on 22).
/// - Left past it: [onLeft] runs (the delete confirmation); nothing is deleted by the swipe.
/// - A shorter swipe shows the action underneath and springs back.
///
/// The row always springs back; the list's own stream removes it once the write lands. Both
/// actions are also screen-reader actions, named in words.
class HabitSwipe extends StatelessWidget {
  /// A51: about 70 % of the row, so a stray swipe while scrolling does nothing.
  static const threshold = 0.7;

  final String habitId;
  final String rightLabel;
  final AppIconData rightIcon;
  final Future<void> Function() onRight;
  final Future<void> Function() onLeft;
  final Widget child;

  const HabitSwipe({
    super.key,
    required this.habitId,
    required this.rightLabel,
    required this.rightIcon,
    required this.onRight,
    required this.onLeft,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: rightLabel): onRight,
        CustomSemanticsAction(label: l10n.swipeDelete): onLeft,
      },
      child: Dismissible(
        key: ValueKey('swipe-$habitId'),
        dismissThresholds: const {
          DismissDirection.startToEnd: threshold,
          DismissDirection.endToStart: threshold,
        },
        onUpdate: (details) {
          if (details.reached && !details.previousReached) HapticFeedback.lightImpact();
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await onRight();
          } else {
            await onLeft();
          }
          // Spring back: the list drops the row itself once the write lands.
          return false;
        },
        background: _Background(
          label: rightLabel,
          icon: rightIcon,
          color: tokens.positiveBg,
          ink: tokens.positiveInk,
          alignment: AlignmentDirectional.centerStart,
        ),
        secondaryBackground: _Background(
          label: l10n.swipeDelete,
          icon: AppIcons.delete,
          color: tokens.errorBg,
          ink: tokens.errorInk,
          alignment: AlignmentDirectional.centerEnd,
        ),
        child: child,
      ),
    );
  }
}

/// What a swipe reveals: an icon and the action in words, never colour alone.
class _Background extends StatelessWidget {
  final String label;
  final AppIconData icon;
  final Color color;
  final Color ink;
  final AlignmentGeometry alignment;

  const _Background({
    required this.label,
    required this.icon,
    required this.color,
    required this.ink,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(HabitRadius.r16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s24),
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, color: ink),
            const SizedBox(width: HabitSpace.s8),
            Text(
              label,
              style: text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A51: archives at once and offers Undo (habit.restore; an archive and a restore on the same
/// day leave the active range unbroken, A34). A habit whose newest change needs a look opens the
/// sync queue instead, as everywhere else.
Future<void> archiveWithUndo(
  BuildContext context,
  AccountContext account,
  String habitId,
  String name,
) => _toggle(context, account, habitId, name, archive: true);

/// A51 on 22: restores at once and offers Undo (habit.archive).
Future<void> restoreWithUndo(
  BuildContext context,
  AccountContext account,
  String habitId,
  String name,
) => _toggle(context, account, habitId, name, archive: false);

Future<void> _toggle(
  BuildContext context,
  AccountContext account,
  String habitId,
  String name, {
  required bool archive,
}) async {
  final toast = AppToast.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    archive
        ? await account.actions.archiveHabit(habitId)
        : await account.actions.restoreHabit(habitId);
  } on HabitEditFailure catch (e) {
    if (context.mounted && e.kind == HabitEditFailureKind.needsAttention) {
      context.push(Routes.queue);
    }
    return;
  }
  toast.show(
    archive ? l10n.archivedSnack(name) : l10n.restoredSnack(name),
    actionLabel: l10n.snackUndo,
    onAction: () =>
        archive ? account.actions.restoreHabit(habitId) : account.actions.archiveHabit(habitId),
  );
}

/// A51: "Delete {name}?" as a bottom sheet in 28's style. True when the person chose
/// "Delete habit".
Future<bool> confirmDeleteHabit(BuildContext context, String name) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    // Over the whole app, the bottom bar included: nothing else is usable while it asks.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final text = Theme.of(context).textTheme;
      final tokens = HabitTokens.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HabitSpace.margin,
            0,
            HabitSpace.margin,
            HabitSpace.margin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.deleteHabitTitle(name), style: text.headlineSmall),
              ),
              const SizedBox(height: HabitSpace.s12),
              Text(l10n.deleteHabitBody, style: text.bodyMedium?.copyWith(color: tokens.muted)),
              const SizedBox(height: HabitSpace.s32),
              tonalButton(
                label: l10n.deleteHabitKeep,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: HabitSpace.s12),
              DestructiveButton(
                label: l10n.deleteHabitConfirm,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// A51: confirms, then deletes the habit (a local write; offline is fine) and says so. Returns
/// whether it was deleted.
Future<bool> confirmAndDeleteHabit(
  BuildContext context,
  AccountContext account,
  String habitId,
  String name,
) async {
  final toast = AppToast.of(context);
  final l10n = AppLocalizations.of(context);
  if (!await confirmDeleteHabit(context, name)) return false;
  await account.actions.deleteHabit(habitId);
  toast.show(l10n.deletedSnack(name));
  return true;
}
