import 'dart:async';

import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_icons.dart';
import 'habit_ui.dart';

/// What a toast is about: its icon says it as well as its colour (A12).
enum ToastTone {
  /// Something was done: a check.
  positive,

  /// A neutral note: an info mark.
  info,
}

/// A52: the app's own toast (Khay Studios' choice over snackbars, 2026-10-25). A rounded pill
/// near the top, over the root overlay, so it stays visible after the navigation that often
/// follows the action. One at a time; a new one replaces the current one.
///
/// Take the handle before any navigation (`final toast = AppToast.of(context);`), then show.
class AppToast {
  /// A52: without an action.
  static const plain = Duration(seconds: 4);

  /// A52: with an action (Undo), a little longer to reach it.
  static const withAction = Duration(seconds: 6);

  static OverlayEntry? _current;

  final OverlayState _overlay;

  AppToast._(this._overlay);

  factory AppToast.of(BuildContext context) => AppToast._(Overlay.of(context, rootOverlay: true));

  /// Shows [message]; with [actionLabel] and [onAction], one action button (44 px).
  void show(
    String message, {
    ToastTone tone = ToastTone.positive,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    dismissCurrent();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(
        key: UniqueKey(),
        message: message,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        onGone: () {
          if (identical(_current, entry)) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    _overlay.insert(entry);
  }

  /// Removes the toast on screen, if any (a new toast or a screen that must start clean).
  static void dismissCurrent() {
    final current = _current;
    _current = null;
    if (current != null && current.mounted) current.remove();
  }
}

class _Toast extends StatefulWidget {
  final String message;
  final ToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onGone;

  const _Toast({
    super.key,
    required this.message,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
    required this.onGone,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _leaving = false;

  bool get _hasAction => widget.actionLabel != null && widget.onAction != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motion.isDismissed && !_leaving) {
      // Reduced motion: it simply appears.
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward();
      }
      // With a screen reader on it stays until dismissed or replaced.
      if (!MediaQuery.accessibleNavigationOf(context)) {
        _timer = Timer(_hasAction ? AppToast.withAction : AppToast.plain, _dismiss);
      }
    }
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) await _motion.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final (icon, toneColor) = switch (widget.tone) {
      ToastTone.positive => (AppIcons.done, Tone.positive),
      ToastTone.info => (AppIcons.info, Tone.info),
    };
    final curve = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + HabitSpace.s8,
      left: HabitSpace.s16,
      right: HabitSpace.s16,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(curve),
          child: Dismissible(
            key: const ValueKey('toast'),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _leaving = true;
              _timer?.cancel();
              widget.onGone();
            },
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                color: tokens.surface,
                elevation: 6,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HabitRadius.r24),
                  side: BorderSide(color: tokens.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HabitSpace.s16,
                    HabitSpace.s4,
                    HabitSpace.s4,
                    HabitSpace.s4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: toneColor.background(tokens),
                          shape: BoxShape.circle,
                        ),
                        child: AppIcon(icon, size: 18, color: toneColor.ink(tokens)),
                      ),
                      const SizedBox(width: HabitSpace.s12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: HabitSpace.s12),
                          child: Text(
                            widget.message,
                            style: text.bodyMedium?.copyWith(color: tokens.ink),
                          ),
                        ),
                      ),
                      if (_hasAction)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                            foregroundColor: tokens.primary,
                          ),
                          onPressed: () {
                            widget.onAction!();
                            _dismiss();
                          },
                          child: Text(widget.actionLabel!),
                        ),
                      IconButton(
                        tooltip: l10n.toastClose,
                        constraints: const BoxConstraints(
                          minWidth: HabitSize.minTarget,
                          minHeight: HabitSize.minTarget,
                        ),
                        onPressed: _dismiss,
                        icon: AppIcon(AppIcons.close, size: 18, color: tokens.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
