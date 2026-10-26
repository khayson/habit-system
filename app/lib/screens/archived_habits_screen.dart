import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import 'widgets/habit_swipe.dart';
import '../widgets/app_icons.dart';

/// Screen 22: archived routines (A34). Local data only (watchArchived, confirmed plus queued
/// archives and restores), so it works offline. Restore queues habit.restore; the row leaves at
/// once through the overlay.
class ArchivedHabitsScreen extends StatelessWidget {
  final DateTime Function() clock;

  const ArchivedHabitsScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/archived'),
      create: (_) => StreamModel<List<ArchivedHabit>>(
        Future.value(account.view.watchArchived(deviceNow: clock)),
      ),
      child: const _Archived(),
    );
  }
}

class _Archived extends StatefulWidget {
  const _Archived();

  @override
  State<_Archived> createState() => _ArchivedState();
}

class _ArchivedState extends State<_Archived> {
  bool _restored = false;
  final Set<String> _restoring = {};

  Future<void> _restore(AccountContext account, ArchivedHabit habit) async {
    setState(() => _restoring.add(habit.id));
    try {
      await account.actions.restoreHabit(habit.id);
      if (mounted) setState(() => _restored = true);
    } on HabitEditFailure catch (e) {
      // The habit's newest change needs a look first: the app's place for that (screen 18).
      if (mounted && e.kind == HabitEditFailureKind.needsAttention) context.push(Routes.queue);
    } finally {
      if (mounted) setState(() => _restoring.remove(habit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final habits =
        context.watch<StreamModel<List<ArchivedHabit>>>().value ?? const <ArchivedHabit>[];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          ScreenHeader(
            title: l10n.archivedTitle,
            subtitle: l10n.archivedSubtitle,
            onBack: () => context.canPop() ? context.pop() : context.go(Routes.habits),
          ),
          if (_restored) ...[
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  AppIcon(AppIcons.done, color: tokens.positiveInk),
                  const SizedBox(width: HabitSpace.s8),
                  Expanded(
                    child: Text(
                      l10n.restoredMessage,
                      style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s16),
          ],
          for (final habit in habits) ...[
            // A51: swipe right restores (with Undo), left asks before deleting.
            HabitSwipe(
              habitId: habit.id,
              rightLabel: l10n.swipeRestore,
              rightIcon: AppIcons.restore,
              onRight: () => restoreWithUndo(context, account, habit.id, habit.name),
              onLeft: () => confirmAndDeleteHabit(context, account, habit.id, habit.name),
              child: SurfaceCard(
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: IconTile(
                        icon: HabitFormat.icon(habit.icon, habit.category),
                        tile: HabitTile.forCategory(habit.category),
                      ),
                    ),
                    const SizedBox(width: HabitSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name, style: text.titleMedium ?? text.bodyLarge),
                          const SizedBox(height: HabitSpace.s4),
                          Text(
                            _detail(l10n, format, habit),
                            style: text.bodySmall?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: l10n.archivedRestoreLabel(habit.name),
                      button: true,
                      excludeSemantics: true,
                      onTap: _restoring.contains(habit.id) ? null : () => _restore(account, habit),
                      child: TextButton(
                        onPressed: _restoring.contains(habit.id)
                            ? null
                            : () => _restore(account, habit),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                        ),
                        child: Text(l10n.archivedRestore),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HabitSpace.s16),
          ],
          if (habits.isNotEmpty) const SizedBox(height: HabitSpace.s16),
          InfoCard(title: l10n.restoreInfoTitle, body: l10n.restoreInfoBody, tone: Tone.info),
          const SizedBox(height: HabitSpace.s32),
          // Always shown, also when nothing is archived (the empty state is these two cards).
          Container(
            padding: const EdgeInsets.all(HabitSpace.s24),
            decoration: BoxDecoration(
              color: tokens.positiveBg,
              borderRadius: BorderRadius.circular(HabitRadius.r16),
            ),
            child: Column(
              children: [
                AppIcon(AppIcons.leaf, size: 48, color: tokens.primary),
                const SizedBox(height: HabitSpace.s16),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.startAgainTitle,
                    style: text.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: HabitSpace.s8),
                Text(
                  l10n.startAgainBody,
                  style: text.bodyMedium?.copyWith(color: tokens.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: HabitSpace.s8),
                TextButton(
                  onPressed: () => context.push(Routes.newHabit),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                  ),
                  child: Text('${l10n.startAgainLink} →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Archived 12 May · Mindfulness"; an archive not yet sent has no date: "Archived · ...".
  static String _detail(AppLocalizations l10n, HabitFormat format, ArchivedHabit habit) {
    final category = format.category(habit.category, long: true);
    final on = habit.archivedOn;
    if (on == null) return l10n.archivedRowNoDate(category);
    return l10n.archivedRow(format.dayMonth(on), category);
  }
}
