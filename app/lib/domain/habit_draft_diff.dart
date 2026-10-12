import 'habit_draft.dart';
import 'provisional_type_rules.dart';

/// One field where two versions of a habit differ, with both display texts (screen 19).
class HabitFieldDiff {
  final HabitField field;
  final String mine;
  final String synced;

  const HabitFieldDiff(this.field, this.mine, this.synced);
}

enum HabitField { name, category, target, unit, schedule }

/// 4.3c A4: the fields where this device's habit edit and the synced habit differ, in the order
/// name, category, target, unit, schedule. A habit.update carries the whole draft, so "use mine"
/// puts back every field listed here (4.3b review I4). Pure Dart: the screen passes the display
/// formatters (the type registry's target text, the schedule text, the category label).
class HabitDraftDiff {
  final String Function(String category) category;
  final String Function(Object? target, String? unit) target;
  final String Function(String frequencyType, Map<String, dynamic> config) schedule;
  final String Function() noUnit;

  const HabitDraftDiff({
    required this.category,
    required this.target,
    required this.schedule,
    required this.noUnit,
  });

  List<HabitFieldDiff> between(HabitDraft mine, HabitDraft synced, ProvisionalTypeRules? rules) {
    final a = mine.toPayload();
    final b = synced.toPayload();
    final out = <HabitFieldDiff>[];
    if (a['name'] != b['name']) {
      out.add(HabitFieldDiff(HabitField.name, a['name']! as String, b['name']! as String));
    }
    if (a['category'] != b['category']) {
      out.add(
        HabitFieldDiff(
          HabitField.category,
          category(a['category']! as String),
          category(b['category']! as String),
        ),
      );
    }
    final sameTarget = rules == null
        ? '${a['target_value']}' == '${b['target_value']}'
        : rules.parseTarget(a['target_value']) == rules.parseTarget(b['target_value']);
    if (!sameTarget) {
      out.add(
        HabitFieldDiff(
          HabitField.target,
          target(a['target_value'], a['unit'] as String?),
          target(b['target_value'], b['unit'] as String?),
        ),
      );
    }
    if (a['unit'] != b['unit']) {
      out.add(
        HabitFieldDiff(
          HabitField.unit,
          a['unit'] as String? ?? noUnit(),
          b['unit'] as String? ?? noUnit(),
        ),
      );
    }
    final sameSchedule =
        HabitDraft(
          name: '',
          category: '',
          targetValue: null,
          unit: null,
          frequencyType: mine.frequencyType,
          frequencyConfig: mine.frequencyConfig,
        ).sameAs(
          HabitDraft(
            name: '',
            category: '',
            targetValue: null,
            unit: null,
            frequencyType: synced.frequencyType,
            frequencyConfig: synced.frequencyConfig,
          ),
          null,
        );
    if (!sameSchedule) {
      out.add(
        HabitFieldDiff(
          HabitField.schedule,
          schedule(mine.frequencyType, mine.frequencyConfig),
          schedule(synced.frequencyType, synced.frequencyConfig),
        ),
      );
    }
    return out;
  }
}
