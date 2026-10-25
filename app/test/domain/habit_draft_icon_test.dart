import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/domain/provisional_type_rules.dart';

/// A53: the icon travels in habit.update like any editable field, but never as a definition.
void main() {
  final rules = ProvisionalTypeRegistry.builtins().lookup('quantity');
  Map<String, dynamic> wire({Object? icon = 'book-02', bool withIcon = true}) => {
    'name': 'Reading',
    'category': 'learning',
    'target_value': '20.000',
    'unit': 'pages',
    'frequency_type': 'daily',
    'frequency_config': <String, dynamic>{},
    if (withIcon) 'icon': icon,
  };

  test('reads and sends the icon, keeping a key this app does not know', () {
    expect(HabitDraft.fromWire(wire()).toPayload()['icon'], 'book-02');
    expect(
      HabitDraft.fromWire(wire(icon: 'from-a-newer-app')).toPayload()['icon'],
      'from-a-newer-app',
    );
    expect(HabitDraft.fromWire(wire(withIcon: false)).toPayload(), containsPair('icon', null));
    expect(HabitDraft.fromWire(wire(icon: 7)).icon, isNull, reason: 'not a string: no icon');
  });

  test('an icon change is a change; the same icon is not', () {
    final a = HabitDraft.fromWire(wire());
    expect(a.sameAs(HabitDraft.fromWire(wire()), rules), isTrue);
    expect(a.sameAs(HabitDraft.fromWire(wire(icon: 'book-open-01')), rules), isFalse);
    expect(a.sameAs(HabitDraft.fromWire(wire(icon: null)), rules), isFalse);
  });

  test('merged: an untouched icon takes the current one, a picked one wins', () {
    final start = HabitDraft.fromWire(wire());
    final current = HabitDraft.fromWire(wire(icon: 'yoga-01'));
    final renamed = HabitDraft.fromWire({...wire(), 'name': 'Evening reading'});
    expect(HabitDraft.merged(start, current, renamed, rules).icon, 'yoga-01');
    final picked = HabitDraft.fromWire(wire(icon: 'book-open-01'));
    expect(HabitDraft.merged(start, current, picked, rules).icon, 'book-open-01');
  });
}
