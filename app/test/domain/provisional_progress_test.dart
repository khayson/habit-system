import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/provisional_progress.dart';
import 'package:habit/domain/provisional_type_rules.dart';

import '../support/contract_fixtures.dart';

/// The Dart half of contract-fixtures/domain/progress.json and weekly.json. The PHP suite runs
/// the same files against the server domain.
void main() {
  final progress = ProvisionalProgress();
  final types = ProvisionalTypeRegistry.builtins();

  List<TodayHabit> habitsFrom(List<dynamic> rows, [Map<String, dynamic> changes = const {}]) => [
    for (final row in rows.cast<Map<String, dynamic>>())
      TodayHabit(
        id: row['id'] as String,
        type: row['type'] as String,
        target: row['target'],
        value: changes.containsKey(row['id']) ? changes[row['id']] : row['value'],
      ),
  ];

  group('progress.json', () {
    final fixture = contractFixture('domain/progress.json');

    test('declares the Dart suite', () {
      expect(fixture['suites'], contains('dart'));
    });

    test('Today 3/5, then meditation makes 4/5', () {
      final today = fixture['today'] as Map<String, dynamic>;
      final after = fixture['after'] as Map<String, dynamic>;

      final before = progress.today(habitsFrom(today['habits'] as List<dynamic>));
      final changed = progress.today(
        habitsFrom(today['habits'] as List<dynamic>, after['changes'] as Map<String, dynamic>),
      );

      expect((before.complete, before.total), (3, 5));
      expect((changed.complete, changed.total), (4, 5));
      for (final row in (today['habits'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final day = progress.day(
          type: row['type'] as String,
          target: row['target'],
          value: row['value'],
        );
        expect(day!.complete, row['complete'], reason: row['name'] as String);
      }
    });

    for (final row in (fixture['values'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test('value: ${row['name']}', () {
        final rules = types.lookup(row['type'] as String)!;
        final current = rules.parseValue(row['value'])!;
        final result = row.containsKey('increment')
            ? rules.increment(current, row['increment'])!
            : rules.parseValue(row['set'])!;

        expect(rules.formatValue(result), row['result']);
        expect(rules.isComplete(result, rules.parseTarget(row['target'])!), row['complete']);
      });
    }

    for (final row in (fixture['invalid_values'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test('rejects ${row['type']}: ${row['reason']}', () {
        expect(types.lookup(row['type'] as String)!.parseValue(row['value']), isNull);
      });
    }

    test('unknown types are preserved and left out of the count (A21)', () {
      final unknown = fixture['unknown_type'] as Map<String, dynamic>;
      final expected = unknown['expect'] as Map<String, dynamic>;

      final summary = progress.today(habitsFrom(unknown['habits'] as List<dynamic>));

      expect(
        (summary.complete, summary.total, summary.unknown),
        (expected['complete'], expected['total'], expected['unknown']),
      );
    });
  });

  group('weekly.json (provisional)', () {
    final fixture = contractFixture('domain/weekly.json');

    test('declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

    for (final c in (fixture['cases'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final habit = c['habit'] as Map<String, dynamic>;
        final definition = (habit['definitions'] as List<dynamic>).first as Map<String, dynamic>;
        final config = definition['frequency_config'] as Map<String, dynamic>;
        final expected = c['provisional'] as Map<String, dynamic>;
        final monday = DateTime.parse((c['period_key'] as String).substring(2));
        final logs = (habit['logs'] as Map<String, dynamic>)
          ..removeWhere((date, _) {
            final d = DateTime.parse(date);
            return d.isBefore(monday) || !d.isBefore(monday.add(const Duration(days: 7)));
          });

        final week = progress.week(
          type: definition['type'] as String,
          perDayTarget: definition['target'],
          countTarget: config['count'] as int,
          logs: logs,
        )!;

        expect(week.distinctCompletedDays, expected['distinct_completed_days']);
        expect(week.targetDays, expected['target_days']);
        expect(week.complete, expected['complete']);
        expect(week.pending, !(expected['complete'] as bool));
      });
    }
  });

  test('the app registry knows exactly the server\'s three types', () {
    expect(types.keys, ['binary', 'quantity', 'duration']);
  });

  test('binary habits are set, never incremented', () {
    expect(types.lookup('binary')!.increment(0, 1), isNull);
  });
}
