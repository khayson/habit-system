import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/app_icons.dart';

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
/// screen title and subtitle. A56: with [onClose], a ✕ in a white circle sits beside the title,
/// as the mockups close a screen.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// A56: closes the screen (the ✕ beside the title).
  final VoidCallback? onClose;

  /// Used instead of [subtitle] when part of the line is a link (07's "2 archived").
  final Widget? subtitleWidget;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.subtitleWidget,
    this.onClose,
  });

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
                  icon: AppIcon(AppIcons.back, color: tokens.muted),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(header: true, child: Text(title, style: text.headlineMedium)),
            ),
            if (onClose != null) ...[
              const SizedBox(width: HabitSpace.s12),
              CircleCloseButton(onPressed: onClose!),
            ],
          ],
        ),
        if (subtitleWidget != null) ...[
          const SizedBox(height: HabitSpace.s4),
          subtitleWidget!,
        ] else if (subtitle != null) ...[
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
  final String? body;
  final Tone tone;
  final AppIconData? icon;

  /// The title in the tone's ink, as 25, 26 and 27 draw it.
  final bool tintTitle;

  const InfoCard({
    super.key,
    required this.title,
    this.body,
    this.tone = Tone.positive,
    this.icon,
    this.tintTitle = false,
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
            AppIcon(icon!, color: tone.ink(tokens)),
            const SizedBox(width: HabitSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tintTitle ? tone.ink(tokens) : null,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: HabitSpace.s4),
                  Text(body!, style: text.bodySmall?.copyWith(color: tokens.muted)),
                ],
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
  final AppIconData icon;
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
          AppIcon(icon, size: 18, color: ink),
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

/// A56: the mockups' pastel tiles behind a habit's icon.
enum HabitTile {
  peach,
  lime,
  pink;

  /// A habit's tile follows its category, so a list reads in the mockups' mix of colours.
  static HabitTile forCategory(String? category) => switch (category) {
    'mindfulness' => HabitTile.lime,
    'learning' => HabitTile.pink,
    'other' => HabitTile.lime,
    _ => HabitTile.peach,
  };

  Color background(HabitTokens t) => switch (this) {
    HabitTile.peach => t.tilePeach,
    HabitTile.lime => t.tileLime,
    HabitTile.pink => t.tilePink,
  };

  Color ink(HabitTokens t) => switch (this) {
    HabitTile.peach => t.tilePeachInk,
    HabitTile.lime => t.tileLimeInk,
    HabitTile.pink => t.tilePinkInk,
  };
}

/// The 44 px tinted square holding a habit or status icon. A56: a habit's icon sits on its
/// pastel [tile]; a status icon on its [tone].
class IconTile extends StatelessWidget {
  final AppIconData icon;
  final Tone tone;

  /// A56: the pastel tile for a habit (overrides [tone]).
  final HabitTile? tile;

  /// The icon's own colour where the design gives one.
  final Color? iconColor;

  /// The square's side; 44 by default (the mockups' Today rows).
  final double size;

  const IconTile({
    super.key,
    required this.icon,
    this.tone = Tone.positive,
    this.tile,
    this.iconColor,
    this.size = HabitSize.minTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final background =
        tile?.background(tokens) ??
        (tone == Tone.neutral ? tokens.positiveBg : tone.background(tokens));
    final ink =
        iconColor ??
        tile?.ink(tokens) ??
        (tone.ink(tokens) == tokens.ink ? tokens.accent : tone.ink(tokens));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.3)),
      child: AppIcon(icon, size: size * 0.5, color: ink),
    );
  }
}

/// A56: the mockups' close control, a ✕ in a white circle (48 px).
class CircleCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CircleCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return Material(
      color: tokens.surface,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: AppLocalizations.of(context).close,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: AppIcon(AppIcons.close, size: 22, color: tokens.ink),
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
        borderRadius: BorderRadius.circular(HabitRadius.r20),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(HabitRadius.r20),
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

/// A destructive action (28, the habit delete sheet): filled in the error ink, disabled while
/// [onPressed] is null, busy while [loading]. Its full label is what a screen reader reads.
class DestructiveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const DestructiveButton({super.key, required this.label, this.loading = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = HabitTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
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
            AppIcon(AppIcons.alert, color: tokens.errorInk),
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

/// The segmented control (07 categories, 13 Today / History). A56: white pills on a soft track,
/// the selected one dark, as the mockups mark the chosen day. Each segment is a 44 px+ target and
/// announces its selection.
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
        color: tokens.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HabitSize.control),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: Material(
                  color: i == selected ? tokens.selected : Colors.transparent,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: () => onSelected(i),
                    customBorder: const StadiumBorder(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: HabitSize.control),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s4),
                          child: Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: i == selected ? tokens.onSelected : tokens.ink,
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

/// An inline field message: a symbol and words, never colour alone (4.2b).
class FieldErrorText extends StatelessWidget {
  final String message;

  const FieldErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.errorInk);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(AppIcons.info, size: 16, color: tokens.errorInk),
          ),
          const SizedBox(width: HabitSpace.s4),
          Flexible(child: Text(message, style: style)),
        ],
      ),
    );
  }
}

/// A labelled whole-number stepper (10's times per week and interval): two 44 px buttons and the
/// value in words. Screen readers get one adjustable control with its value.
class CountStepper extends StatelessWidget {
  final String label;
  final int value;
  final String valueText;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const CountStepper({
    super.key,
    required this.label,
    required this.value,
    required this.valueText,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final canLower = value > min;
    final canRaise = value < max;
    Widget button(AppIconData icon, String tooltip, bool enabled, int to) => IconButton.outlined(
      onPressed: enabled ? () => onChanged(to) : null,
      tooltip: tooltip,
      icon: AppIcon(icon),
      constraints: const BoxConstraints(
        minWidth: HabitSize.minTarget,
        minHeight: HabitSize.minTarget,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Semantics(
          container: true,
          label: label,
          value: valueText,
          increasedValue: canRaise ? '${value + 1}' : null,
          decreasedValue: canLower ? '${value - 1}' : null,
          onIncrease: canRaise ? () => onChanged(value + 1) : null,
          onDecrease: canLower ? () => onChanged(value - 1) : null,
          child: Row(
            children: [
              button(AppIcons.remove, l10n.freqFewer, canLower, value - 1),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    valueText,
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(color: tokens.ink),
                  ),
                ),
              ),
              button(AppIcons.add, l10n.freqMore, canRaise, value + 1),
            ],
          ),
        ),
      ],
    );
  }
}
