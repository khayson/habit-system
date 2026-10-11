import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/l10n/generated/app_localizations_en.dart';
import 'package:habit/widgets/habit_form.dart';

/// 4.2b review I2: a refused create or edit shows each problem under its own field.
void main() {
  final l10n = AppLocalizationsEn();

  test('each problem lands under its own field, none under the name by default', () {
    final errors = HabitFormErrors.fromProblems(l10n, const [
      HabitDraftProblem.unitRequired,
      HabitDraftProblem.weekdays,
      HabitDraftProblem.target,
      HabitDraftProblem.category,
    ]);
    expect(
      (errors.name, errors.amount, errors.unit, errors.category, errors.schedule),
      (
        null,
        'Use a number above zero.',
        'Add a unit, such as ml or pages.',
        'Choose a category.',
        'Choose at least one day.',
      ),
    );
    expect(
      HabitFormErrors.fromProblems(l10n, const [HabitDraftProblem.nameTooLong]).name,
      'Use 100 characters or fewer.',
    );
  });
}
