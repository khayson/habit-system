import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/habit_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/ledger_pager.dart';
import '../../widgets/habit_ui.dart';

/// One history row on 16 or 17: an icon tile, a title and a muted line, the amount at the end.
/// Read out as one label: title, detail, amount.
class LedgerRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String detail;
  final String amount;
  final Color amountColor;

  const LedgerRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Semantics(
      container: true,
      label: l10n.ledgerRowLabel(title, detail, amount),
      excludeSemantics: true,
      child: SurfaceCard(
        child: Row(
          children: [
            IconTile(icon: icon, tone: tone),
            const SizedBox(width: HabitSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium ?? text.bodyLarge),
                  const SizedBox(height: HabitSpace.s4),
                  Text(detail, style: text.bodySmall?.copyWith(color: tokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: HabitSpace.s12),
            Text(amount, style: text.bodyMedium?.copyWith(color: amountColor)),
          ],
        ),
      ),
    );
  }
}

/// The list part of a history section, driven by a [LedgerPager] above it: loading, a neutral
/// error with Try again, the rows, and Show more while there is a next page.
class LedgerList<T> extends StatelessWidget {
  final Widget Function(BuildContext context, T row) rowBuilder;

  const LedgerList({super.key, required this.rowBuilder});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final pager = context.watch<LedgerPager<T>>();
    final muted = text.bodyMedium?.copyWith(color: tokens.muted);

    if (!pager.loaded) {
      if (pager.error == null) {
        return const Padding(
          padding: EdgeInsets.all(HabitSpace.s24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.ledgerLoadError, style: muted),
          const SizedBox(height: HabitSpace.s8),
          _Button(label: l10n.ledgerTryAgain, busy: pager.loading, onPressed: pager.load),
        ],
      );
    }
    if (pager.rows.isEmpty) return Text(l10n.ledgerEmpty, style: muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in pager.rows) ...[
          rowBuilder(context, row),
          const SizedBox(height: HabitSpace.s12),
        ],
        if (pager.moreError != null) ...[
          Text(l10n.ledgerMoreError, style: muted),
          const SizedBox(height: HabitSpace.s8),
        ],
        if (pager.hasMore)
          _Button(label: l10n.ledgerShowMore, busy: pager.loadingMore, onPressed: pager.more),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _Button({required this.label, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: HabitSize.minTarget),
      child: TextButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    ),
  );
}

/// "+10 XP" / "−10 XP" and "+1" / "−1": the sign is the text, never colour alone.
String signed(int n) => n < 0 ? '−${-n}' : '+$n';
