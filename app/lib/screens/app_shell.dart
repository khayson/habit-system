import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';

/// The design file's bottom navigation (screens 05, 07, 12): Today, Habits, Insights, Profile.
/// Insights is drawn as in the design and arrives with its phase; until then it is disabled
/// and says so to assistive technology. Profile (20) opens with Phase 3b.
class AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final habits = location.startsWith(Routes.habits);
    final profile = location.startsWith(Routes.profile);
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(top: BorderSide(color: tokens.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: HabitSpace.s8),
            child: Row(
              children: [
                _Tab(
                  icon: Icons.home_outlined,
                  label: l10n.navToday,
                  selected: !habits && !profile,
                  onTap: () => context.go(Routes.today),
                ),
                _Tab(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.navHabits,
                  selected: habits,
                  onTap: () => context.go(Routes.habits),
                ),
                _Tab(
                  icon: Icons.signal_cellular_alt_outlined,
                  label: l10n.navInsights,
                  selected: false,
                ),
                _Tab(
                  icon: Icons.person_outline,
                  label: l10n.navProfile,
                  selected: profile,
                  onTap: () => context.go(Routes.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Tab({required this.icon, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    final color = selected ? tokens.primary : tokens.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: onTap == null ? AppLocalizations.of(context).navLater(label) : label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HabitSize.controlLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: HabitSpace.s4),
                Text(
                  label,
                  style: text.bodySmall?.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
