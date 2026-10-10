import 'package:flutter/material.dart';

import '../../config/habit_tokens.dart';
import '../../widgets/habit_ui.dart';

/// A tinted notice with one action: screen 11's notification permission states, and the same
/// states on screen 20's Reminders sheet.
class NoticeBanner extends StatelessWidget {
  final Tone tone;
  final String title;
  final String body;
  final String? extra;
  final String action;
  final VoidCallback onAction;

  const NoticeBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        HabitSpace.s24,
        HabitSpace.s24,
        HabitSpace.s16,
        HabitSpace.s12,
      ),
      decoration: BoxDecoration(
        color: tone.background(tokens),
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium?.copyWith(color: tokens.ink)),
          const SizedBox(height: HabitSpace.s8),
          Text(body, style: text.bodyMedium?.copyWith(color: tokens.muted)),
          if (extra != null) ...[
            const SizedBox(height: HabitSpace.s8),
            Text(extra!, style: text.bodyMedium?.copyWith(color: tokens.ink)),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
              ),
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}
