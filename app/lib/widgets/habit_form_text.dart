import '../domain/habit_draft.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';

/// Calm wording for every reason a habit form is not sent yet (08, 09, 10). It says what to do,
/// never what the person did wrong.
class HabitFormText {
  final AppLocalizations l10n;

  const HabitFormText(this.l10n);

  String problem(HabitDraftProblem p) => switch (p) {
    HabitDraftProblem.nameRequired => l10n.problemNameRequired,
    HabitDraftProblem.nameTooLong => l10n.newHabitNameTooLong,
    HabitDraftProblem.category => l10n.problemCategory,
    HabitDraftProblem.unknownType => l10n.unknownTypeTitle,
    HabitDraftProblem.target => l10n.targetErrorNotPositive,
    HabitDraftProblem.unitRequired => l10n.targetErrorUnitRequired,
    HabitDraftProblem.unitTooLong => l10n.targetErrorUnitTooLong,
    HabitDraftProblem.unitNotAllowed => l10n.problemUnitNotAllowed,
    HabitDraftProblem.frequencyType => l10n.problemFrequencyType,
    HabitDraftProblem.weekdays => l10n.problemWeekdays,
    HabitDraftProblem.weeklyCount => l10n.problemWeeklyCount,
    HabitDraftProblem.interval => l10n.problemInterval,
    HabitDraftProblem.intervalAnchor => l10n.problemIntervalAnchor,
  };

  String target(TargetFieldError e) => switch (e) {
    TargetFieldError.required => l10n.targetErrorRequired,
    TargetFieldError.notNumber => l10n.targetErrorNotNumber,
    TargetFieldError.tooPrecise => l10n.targetErrorTooPrecise,
    TargetFieldError.notPositive => l10n.targetErrorNotPositive,
    TargetFieldError.tooLarge => l10n.targetErrorTooLarge,
    TargetFieldError.unitRequired => l10n.targetErrorUnitRequired,
    TargetFieldError.unitTooLong => l10n.targetErrorUnitTooLong,
  };
}
