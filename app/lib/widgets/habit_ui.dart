import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';

/// Shared building blocks for the design file's screens. Every status carries text (and usually
/// a symbol), never colour alone; every target is at least 44 px; text scales.

enum Tone { positive, info, warning, error, neutral }

extension ToneColors on Tone {
  Color background(HabitTokens t) => switch (this) {
    Tone.positive => t.positiveBg,
    Tone.info => t.infoBg,
    Tone.warning => t.warningBg,
    Tone.error => t.errorBg,
    Tone.neutral => t.surface,
  };

  Color ink(HabitTokens t) => switch (this) {
    Tone.positive => t.positiveInk,
    Tone.info => t.infoInk,
    Tone.warning => t.warningInk,
    Tone.error => t.errorInk,
    Tone.neutral => t.ink,
  };
}

/// Back arrow (when there is somewhere to go back to), an optional trailing chip, then the
/// screen title and subtitle, as in the design file.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  const ScreenHeader({super.key, required this.title, this.subtitle, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null || trailing != null)
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  tooltip: AppLocalizations.of(context).back,
                  icon: Icon(Icons.arrow_back, color: tokens.muted),
                  constraints: const BoxConstraints(
                    minWidth: HabitSize.minTarget,
                    minHeight: HabitSize.minTarget,
                  ),
                ),
              const Spacer(),
              ?trailing,
            ],
          ),
        const SizedBox(height: HabitSpace.s16),
        Semantics(header: true, child: Text(title, style: text.headlineMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: HabitSpace.s4),
          Text(subtitle!, style: text.bodyLarge?.copyWith(color: tokens.muted)),
        ],
        const SizedBox(height: HabitSpace.s24),
      ],
    );
  }
}

/// The tinted message card ("Private by default", "Waiting for a connection", ...).
class InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final Tone tone;
  final IconData? icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.tone = Tone.positive,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HabitSpace.s16),
      decoration: BoxDecoration(
        color: tone.background(tokens),
        borderRadius: BorderRadius.circular(HabitRadius.r16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: tone.ink(tokens)),
            const SizedBox(width: HabitSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: HabitSpace.s4),
                Text(body, style: text.bodySmall?.copyWith(color: tokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded status pill with text and a symbol. Tappable when [onTap] is set.
class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    required this.icon,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    final ink = tone.ink(tokens);
    final chip = Container(
      constraints: const BoxConstraints(minHeight: HabitSize.minTarget),
      padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s16),
      decoration: BoxDecoration(
        color: tone.background(tokens),
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ink),
          const SizedBox(width: HabitSpace.s8),
          Text(label, style: text.titleSmall?.copyWith(color: ink)),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: onTap == null
          ? chip
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(HabitRadius.r24),
              child: chip,
            ),
    );
  }
}

/// The 44 px tinted square holding a habit or status icon.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Tone tone;

  /// The icon's own colour where the design gives one (04's orange bell on the usual tile).
  final Color? iconColor;

  const IconTile({super.key, required this.icon, this.tone = Tone.positive, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return Container(
      width: HabitSize.minTarget,
      height: HabitSize.minTarget,
      decoration: BoxDecoration(
        color: tone == Tone.neutral ? tokens.positiveBg : tone.background(tokens),
        borderRadius: BorderRadius.circular(HabitRadius.r12),
      ),
      child: Icon(
        icon,
        color: iconColor ?? (tone.ink(tokens) == tokens.ink ? tokens.primary : tone.ink(tokens)),
      ),
    );
  }
}

/// White rounded card used for rows and stats.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const SurfaceCard({super.key, required this.child, this.onTap, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final content = Padding(padding: const EdgeInsets.all(HabitSpace.s16), child: child);
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r16),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(HabitRadius.r16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: HabitSize.controlLarge),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// The single dominant action. While [loading] it keeps its label, shows progress and cannot be
/// pressed again (design: "never a duplicate request").
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: tokens.disabledInk),
              ),
              const SizedBox(width: HabitSpace.s12),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// A form-level error (network, rate limit), announced to screen readers.
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HabitSpace.s16),
        decoration: BoxDecoration(
          color: tokens.errorBg,
          borderRadius: BorderRadius.circular(HabitRadius.r12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: tokens.errorInk),
            const SizedBox(width: HabitSpace.s12),
            Expanded(
              child: Text(message, style: text.bodySmall?.copyWith(color: tokens.errorInk)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field label above the input, as in the design file (a persistent label, never placeholder-only).
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: HabitTokens.of(context).muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: HabitSpace.s8),
      child: Text(text, style: style),
    );
  }
}

/// The design's segmented control (07 categories, 13 Today / History): a tinted track with the
/// selected segment raised on the surface colour. Each segment is a 44 px+ target and announces
/// its selection.
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(HabitSpace.s4),
      decoration: BoxDecoration(
        color: tokens.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HabitRadius.r16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: Material(
                  color: i == selected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(HabitRadius.r12),
                  child: InkWell(
                    onTap: () => onSelected(i),
                    borderRadius: BorderRadius.circular(HabitRadius.r12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: HabitSize.control),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s4),
                          child: Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: i == selected ? tokens.primary : tokens.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
