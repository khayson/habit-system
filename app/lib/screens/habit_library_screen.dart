import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import 'widgets/habit_swipe.dart';
import '../widgets/app_icons.dart';

/// Screen 07: the habit library. Reads local data only (confirmed rows plus pending creates),
/// so it works offline. Archived habits are counted, not listed, as in the design.
class HabitLibraryScreen extends StatelessWidget {
  /// The device clock: today picks each habit's definition in force (I2). A seam for tests.
  final DateTime Function() clock;

  const HabitLibraryScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    return ChangeNotifierProvider(
      key: ValueKey(account.session.userId),
      create: (_) => StreamModel<List<HabitView>>(
        Future.value(account.view.watchHabits(deviceNow: clock, includeArchived: true)),
      ),
      child: const _Library(),
    );
  }
}

class _Library extends StatefulWidget {
  const _Library();

  @override
  State<_Library> createState() => _LibraryState();
}

class _LibraryState extends State<_Library> {
  final _search = TextEditingController();
  String? _category; // null = All

  static const _categories = ['health', 'mindfulness', 'learning'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final all = context.watch<StreamModel<List<HabitView>>>().value ?? const <HabitView>[];
    // The overlay's state (A34): a queued archive or restore counts at once.
    final active = all.where((h) => !h.archived).toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // creation order (UUIDv7)
    final query = _search.text.trim().toLowerCase();
    final shown = active.where((h) {
      final name = (h.payload['name'] as String? ?? '').toLowerCase();
      return (query.isEmpty || name.contains(query)) &&
          (_category == null || h.payload['category'] == _category);
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          ScreenHeader(
            title: l10n.libraryTitle,
            subtitle: l10n.librarySubtitle(active.length, all.length - active.length),
            subtitleWidget: all.length == active.length
                ? null
                : _ArchivedLink(active: active.length, archived: all.length - active.length),
          ),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(hintText: l10n.librarySearch),
          ),
          const SizedBox(height: HabitSpace.s16),
          SegmentedTabs(
            labels: [l10n.libraryAll, for (final c in _categories) format.category(c)],
            selected: _category == null ? 0 : _categories.indexOf(_category!) + 1,
            onSelected: (i) => setState(() => _category = i == 0 ? null : _categories[i - 1]),
          ),
          const SizedBox(height: HabitSpace.s16),
          if (shown.isEmpty && active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HabitSpace.s24),
              child: Text(
                l10n.libraryNoMatch,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.muted),
              ),
            ),
          for (final habit in shown) ...[
            _HabitRow(habit: habit),
            const SizedBox(height: HabitSpace.s12),
          ],
          const SizedBox(height: HabitSpace.s12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.newHabit),
              icon: const AppIcon(AppIcons.add),
              label: Text(l10n.libraryCreate),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HabitView habit;

  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final account = context.read<AccountContext?>()!;
    final p = habit.payload;
    final rules = account.view.types.lookup(p['type'] as String? ?? '');
    // P3: the definition in force today, not the latest (which may start tomorrow).
    final inForce = habit.inForceToday;
    final detail = format.rowDetail(
      rules,
      inForce?.wire['target_value'] ?? p['target_value'],
      (inForce?.wire['unit'] ?? p['unit']) as String?,
      inForce?.frequency,
    );
    final name = p['name'] as String? ?? '';

    // A51: swipe right archives (with Undo), left asks before deleting.
    return HabitSwipe(
      habitId: habit.id,
      rightLabel: l10n.swipeArchive,
      rightIcon: AppIcons.archive,
      onRight: () => archiveWithUndo(context, account, habit.id, name),
      onLeft: () => confirmAndDeleteHabit(context, account, habit.id, name),
      child: _card(
        context,
        l10n,
        text,
        tokens,
        HabitFormat.icon(habit.icon, habit.category),
        name,
        detail,
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme text,
    HabitTokens tokens,
    AppIconData icon,
    String name,
    String detail,
  ) {
    return SurfaceCard(
      onTap: () => context.go(Routes.habit(habit.id)),
      semanticsLabel: l10n.libraryOpen(name, detail),
      child: ExcludeSemantics(
        child: Row(
          children: [
            IconTile(icon: icon),
            const SizedBox(width: HabitSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: text.titleMedium ?? text.bodyLarge),
                  const SizedBox(height: HabitSpace.s4),
                  Text(detail, style: text.bodySmall?.copyWith(color: tokens.muted)),
                ],
              ),
            ),
            AppIcon(AppIcons.chevronRight, color: tokens.primary),
          ],
        ),
      ),
    );
  }
}

/// 07's subtitle with "N archived" as a 44 px link to screen 22 (4.2b). With nothing archived
/// the plain subtitle stays.
class _ArchivedLink extends StatelessWidget {
  final int active;
  final int archived;

  const _ArchivedLink({required this.active, required this.archived});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodyLarge;
    final tokens = HabitTokens.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${l10n.libraryActive(active)} · ', style: style?.copyWith(color: tokens.muted)),
        Semantics(
          container: true,
          link: true,
          label: l10n.libraryArchivedLink(archived),
          hint: l10n.libraryArchivedLinkHint,
          excludeSemantics: true,
          onTap: () => context.push(Routes.archivedHabits),
          child: TextButton(
            onPressed: () => context.push(Routes.archivedHabits),
            style: TextButton.styleFrom(
              minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s4),
              textStyle: style,
            ),
            child: Text(
              l10n.libraryArchivedLink(archived),
              style: style?.copyWith(color: tokens.primary, decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }
}
