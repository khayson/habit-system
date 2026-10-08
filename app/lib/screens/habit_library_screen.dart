import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/local_view.dart';
import '../domain/habit_schedule.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screen 07: the habit library. Reads local data only (confirmed rows plus pending creates),
/// so it works offline. Archived habits are counted, not listed, as in the design.
class HabitLibraryScreen extends StatelessWidget {
  const HabitLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const SizedBox();
    return ChangeNotifierProvider(
      key: ValueKey(account.session.userId),
      create: (_) => StreamModel<List<HabitView>>(Future.value(account.view.watchHabits())),
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
    bool archived(HabitView h) => h.payload['archived_at'] != null;
    final active = all.where((h) => !archived(h)).toList()
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
              icon: const Icon(Icons.add),
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
    final schedule = HabitSchedule.fromWire(p);
    final latest = schedule.versions.isEmpty ? null : schedule.versions.last;
    final detail = format.rowDetail(
      rules,
      p['target_value'],
      p['unit'] as String?,
      latest?.frequency,
    );
    final name = p['name'] as String? ?? '';

    return SurfaceCard(
      onTap: () => context.go(Routes.habit(habit.id)),
      semanticsLabel: l10n.libraryOpen(name, detail),
      child: ExcludeSemantics(
        child: Row(
          children: [
            IconTile(icon: HabitFormat.icon(rules)),
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
            Icon(Icons.chevron_right, color: tokens.primary),
          ],
        ),
      ),
    );
  }
}
