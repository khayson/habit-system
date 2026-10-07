import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_ui.dart';
import '../widgets/sync_status_chip.dart';
import 'widgets/needs_attention.dart';

/// Screen 05 (binary habits only in 2b.2), with screen 23 as its first-run empty state. Reads
/// local data only and works fully offline; values waiting to sync are labelled as such.
class TodayScreen extends StatelessWidget {
  final DateTime Function() clock;

  const TodayScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey(account.session.userId),
      create: (_) =>
          StreamModel<TodayView?>(TimeZones.ready.then((_) => account.view.watchToday(clock))),
      child: const _TodayBody(),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final model = context.watch<StreamModel<TodayView?>>();
    final today = model.value;

    final Widget body;
    if (model.error != null && !model.hasValue) {
      body = _Message(text: l10n.todayLoadError, icon: Icons.error_outline);
    } else if (today == null) {
      body = _Message(text: l10n.todayOpening, icon: null);
    } else if (today.items.isEmpty) {
      body = const _EmptyToday();
    } else {
      body = _TodayList(today: today);
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

class _TodayList extends StatelessWidget {
  final TodayView today;

  const _TodayList({required this.today});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMEEEEd(locale)
        .format(DateTime.fromMillisecondsSinceEpoch(today.date.midnightMillis, isUtc: true));
    final total = today.items.length;
    final done = today.completeCount;

    return ListView(
      padding: const EdgeInsets.all(HabitSpace.margin),
      children: [
        Semantics(header: true, child: Text(_greeting(l10n, today), style: text.headlineMedium)),
        const SizedBox(height: HabitSpace.s4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: HabitSpace.s12,
          runSpacing: HabitSpace.s8,
          children: [
            Text(date, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            SyncStatusChip(onTap: () => context.push(Routes.queue)),
          ],
        ),
        const SizedBox(height: HabitSpace.s24),
        Container(
          padding: const EdgeInsets.all(HabitSpace.s24),
          decoration: BoxDecoration(
            color: tokens.positiveBg,
            borderRadius: BorderRadius.circular(HabitRadius.r16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.todaySummary(done, total), style: text.titleLarge),
              const SizedBox(height: HabitSpace.s16),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HabitRadius.r4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 8,
                    color: tokens.progress,
                    backgroundColor: tokens.border,
                  ),
                ),
              ),
              if (today.hasPending) ...[
                const SizedBox(height: HabitSpace.s12),
                Text(
                  l10n.todaySummaryProvisional,
                  style: text.bodySmall?.copyWith(color: tokens.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: HabitSpace.s24),
        for (final item in today.items) ...[
          _HabitRow(item: item),
          const SizedBox(height: HabitSpace.s12),
        ],
        // ASSUMPTION(A2b2-create-entry): the design creates habits from 07 (Habits tab, a later
        // phase) and 23; until 07 exists, Today keeps a quiet link to the minimal editor.
        Center(
          child: TextButton.icon(
            onPressed: () => context.push(Routes.newHabit),
            icon: const Icon(Icons.add),
            label: Text(l10n.todayCreateHabit),
          ),
        ),
      ],
    );
  }

  static String _greeting(AppLocalizations l10n, TodayView today) {
    final name = today.userName?.trim();
    if (name == null || name.isEmpty) return l10n.todayGreetingPlain;
    final first = name.split(RegExp(r'\s+')).first;
    final hour = today.localNow.hour;
    if (hour < 12) return l10n.todayGreetingMorning(first);
    if (hour < 18) return l10n.todayGreetingAfternoon(first);
    return l10n.todayGreetingEvening(first);
  }
}

class _HabitRow extends StatelessWidget {
  final TodayItem item;

  const _HabitRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final account = context.read<AccountContext?>()!;

    final (subtitle, trailing, tone) = switch (item) {
      _ when item.needsAttention => (l10n.todayNeedsLook, Icons.error_outline, Tone.warning),
      _ when item.rules == null => (l10n.todayUnknownType, Icons.system_update_alt, Tone.info),
      _ when item.complete => (
        item.pending ? l10n.todayDoneWaiting : l10n.todayDone,
        Icons.check_circle,
        Tone.positive,
      ),
      _ when !item.rules!.oneTap => (l10n.todayOtherType, Icons.hourglass_empty, Tone.info),
      _ when item.habit.provisional && item.log.syncState == null => (
        l10n.todayNewHabitWaiting,
        Icons.radio_button_unchecked,
        Tone.neutral,
      ),
      _ => (
        item.pending ? l10n.todayNotDoneWaiting : l10n.todayNotDone,
        Icons.radio_button_unchecked,
        Tone.neutral,
      ),
    };

    VoidCallback? onTap;
    String? action;
    if (item.needsAttention) {
      onTap = () => showNeedsAttention(context, account, item.attention!);
      action = l10n.todayNeedsLook;
    } else if (item.canToggle) {
      onTap = () => account.actions.toggle(item);
      action = item.complete ? l10n.todayUndo(item.name) : l10n.todayCheckIn(item.name);
    }

    return SurfaceCard(
      onTap: onTap,
      semanticsLabel: action == null ? null : '$action. $subtitle',
      child: ExcludeSemantics(
        excluding: action != null,
        child: Row(
          children: [
            IconTile(icon: item.rules == null ? Icons.help_outline : Icons.check, tone: tone),
            const SizedBox(width: HabitSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleMedium ?? text.bodyLarge),
                  const SizedBox(height: HabitSpace.s4),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: tokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: HabitSpace.s12),
            Icon(trailing, color: tone == Tone.neutral ? tokens.muted : tone.ink(tokens)),
          ],
        ),
      ),
    );
  }
}

/// Screen 23: the first-run empty Today.
class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(HabitSpace.margin),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SyncStatusChip(onTap: () => context.push(Routes.queue)),
        ),
        ScreenHeader(title: l10n.emptyTitle, subtitle: l10n.emptySubtitle),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: tokens.positiveBg, shape: BoxShape.circle),
            child: Icon(Icons.eco_outlined, size: 96, color: tokens.primary),
          ),
        ),
        const SizedBox(height: HabitSpace.s32),
        Text(l10n.emptyHeading, style: text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: HabitSpace.s12),
        Text(
          l10n.emptyBody,
          style: text.bodyLarge?.copyWith(color: tokens.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HabitSpace.s48),
        PrimaryButton(label: l10n.emptyButton, onPressed: () => context.push(Routes.newHabit)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Message({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HabitSpace.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null) const CircularProgressIndicator() else Icon(icon, size: 32),
            const SizedBox(height: HabitSpace.s16),
            Text(text, style: style, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
