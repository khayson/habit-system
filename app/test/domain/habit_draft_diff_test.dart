import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/domain/habit_draft_diff.dart';
import 'package:habit/domain/provisional_type_rules.dart';

/// 4.3c A4: the fields where two versions of a habit differ, in order, with both texts.
void main() {
  const diff = HabitDraftDiff(
    category: _upper,
    target: _target,
    schedule: _schedule,
    noUnit: _none,
  );
  final quantity = ProvisionalTypeRegistry.builtins().lookup('quantity');

  HabitDraft draft({
    String name = 'Water',
    String category = 'health',
    Object target = '2.000',
    String? unit = 'L',
    String type = 'daily',
    Map<String, dynamic> config = const {},
  }) => HabitDraft(
    name: name,
    category: category,
    targetValue: target,
    unit: unit,
    frequencyType: type,
    frequencyConfig: config,
  );

  test('equal drafts differ in nothing (a target typed "2" equals "2.000")', () {
    expect(diff.between(draft(), draft(target: '2'), quantity), isEmpty);
  });

  test('only the differing fields, in order, with both display texts', () {
    final out = diff.between(
      draft(
        name: 'Water (phone)',
        target: '2.500',
        type: 'weekdays',
        config: {
          'days': [1, 3],
        },
      ),
      draft(name: 'Water (tablet)', category: 'learning', unit: 'ml'),
      quantity,
    );
    expect(
      [for (final d in out) (d.field, d.mine, d.synced)],
      [
        (HabitField.name, 'Water (phone)', 'Water (tablet)'),
        (HabitField.category, 'HEALTH', 'LEARNING'),
        (HabitField.target, '2.500 L', '2.000 ml'),
        (HabitField.unit, 'L', 'ml'),
        (HabitField.schedule, 'weekdays 1,3', 'daily'),
      ],
    );
  });

  test('each field kind on its own', () {
    for (final (synced, field) in [
      (draft(name: 'Tea'), HabitField.name),
      (draft(category: 'other'), HabitField.category),
      (draft(target: '3.000'), HabitField.target),
      (draft(type: 'weekly_count', config: {'count': 3}), HabitField.schedule),
    ]) {
      expect(diff.between(draft(), synced, quantity).map((d) => d.field), [field]);
    }
    expect(
      diff.between(draft(unit: null), draft(unit: 'ml'), quantity).single,
      isA<HabitFieldDiff>().having((d) => d.mine, 'mine', 'none'),
    );
  });
}

String _upper(String c) => c.toUpperCase();
String _target(Object? t, String? u) => '$t ${u ?? ''}'.trim();
String _schedule(String type, Map<String, dynamic> c) =>
    type == 'weekdays' ? 'weekdays ${(c['days'] as List).join(',')}' : type;
String _none() => 'none';
