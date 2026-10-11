import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../domain/frequency_choice.dart';
import '../domain/habit_draft.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import 'habit_form_text.dart';
import 'habit_ui.dart';

/// One worded message per field of 08 / 09, from the registry's parse and HabitDraft.problems.
class HabitFormErrors {
  final String? name;
  final String? amount;
  final String? unit;
  final String? category;
  final String? schedule;

  const HabitFormErrors({this.name, this.amount, this.unit, this.category, this.schedule});

  static const none = HabitFormErrors();

  /// Each problem under its own field, the first per field (4.2b I2); nothing lands under the
  /// name by default.
  factory HabitFormErrors.fromProblems(AppLocalizations l10n, List<HabitDraftProblem> problems) {
    final words = HabitFormText(l10n);
    String? first(Iterable<HabitDraftProblem> of) {
      final p = problems.where(of.contains).firstOrNull;
      return p == null ? null : words.problem(p);
    }

    return HabitFormErrors(
      name: first(const [HabitDraftProblem.nameRequired, HabitDraftProblem.nameTooLong]),
      amount: first(const [HabitDraftProblem.target, HabitDraftProblem.unknownType]),
      unit: first(const [
        HabitDraftProblem.unitRequired,
        HabitDraftProblem.unitTooLong,
        HabitDraftProblem.unitNotAllowed,
      ]),
      category: first(const [HabitDraftProblem.category]),
      schedule: first(const [
        HabitDraftProblem.frequencyType,
        HabitDraftProblem.weekdays,
        HabitDraftProblem.weeklyCount,
        HabitDraftProblem.interval,
        HabitDraftProblem.intervalAnchor,
      ]),
    );
  }

  bool get any =>
      name != null || amount != null || unit != null || category != null || schedule != null;

  HabitFormErrors without({bool name = false, bool target = false}) => HabitFormErrors(
    name: name ? null : this.name,
    amount: target ? null : amount,
    unit: target ? null : unit,
    category: category,
    schedule: schedule,
  );
}

/// The draft 08 / 09 would send, or the reasons it cannot be sent yet. Validation is
/// HabitDraft.problems (what the server would refuse), after the registry turned the typed
/// target into its wire form.
({HabitDraft? draft, HabitFormErrors errors}) validateHabitForm({
  required AppLocalizations l10n,
  required HabitTypeUi type,
  required String name,
  required String category,
  required TargetInput target,
  required FrequencyChoice frequency,
}) {
  final words = HabitFormText(l10n);
  final parsed = type.parse(target);
  final draft = HabitDraft(
    name: name,
    category: category,
    targetValue: parsed.target,
    unit: parsed.unit,
    frequencyType: frequency.type,
    frequencyConfig: frequency.config,
  );
  final byField = HabitFormErrors.fromProblems(l10n, draft.problems(type.rules));
  // The registry's own message wins for the target fields; a refused parse leaves the draft's
  // target empty, so its "target" problem is not shown twice.
  final errors = HabitFormErrors(
    name: byField.name,
    amount: parsed.amountError != null
        ? words.target(parsed.amountError!)
        : (parsed.ok ? byField.amount : null),
    unit: parsed.unitError != null
        ? words.target(parsed.unitError!)
        : (parsed.ok ? byField.unit : null),
    category: byField.category,
    schedule: byField.schedule,
  );
  return (draft: errors.any ? null : draft, errors: errors);
}

/// The design's setting row (08 / 09: Category, Schedule, Reminder): icon tile, title, summary
/// and a 44 px text action. [message] is an inline problem shown under the summary.
class SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final String? action;
  final VoidCallback? onAction;
  final String? message;

  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    this.action,
    this.onAction,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return SurfaceCard(
      child: Row(
        children: [
          ExcludeSemantics(child: IconTile(icon: icon)),
          const SizedBox(width: HabitSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium ?? text.bodyLarge),
                const SizedBox(height: HabitSpace.s4),
                Text(summary, style: text.bodySmall?.copyWith(color: tokens.muted)),
                if (message != null) ...[
                  const SizedBox(height: HabitSpace.s4),
                  FieldErrorText(message!),
                ],
              ],
            ),
          ),
          if (action != null)
            Semantics(
              container: true,
              label: '$action $title',
              button: true,
              excludeSemantics: true,
              onTap: onAction,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                ),
                child: Text(action!),
              ),
            ),
        ],
      ),
    );
  }
}
