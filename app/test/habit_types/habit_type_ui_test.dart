import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:habit/habit_types/habit_type_ui.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/widgets/habit_format.dart';

/// Phase 4.2b Part A: the type-widget registry (A21, invariant 14).
void main() {
  final registry = HabitTypeUiRegistry.builtins();
  final types = ProvisionalTypeRegistry.builtins();
  HabitTypeUi ui(String key) => registry.lookup(key)!;

  test('one entry per type the provisional registry knows, keyed the same', () {
    expect(registry.all.map((e) => e.key).toSet(), types.all.map((r) => r.key).toSet());
    expect(registry.lookup('stopwatch'), isNull);
  });

  group('yes / no', () {
    test('no target field; the target is 1 and there is no unit', () {
      final yesNo = ui('binary');
      expect(yesNo.hasTargetInput, isFalse);
      final parsed = yesNo.parse(const TargetInput());
      expect((parsed.ok, parsed.target, parsed.unit), (true, 1, null));
    });
  });

  group('quantity', () {
    final quantity = ui('quantity');

    test('the target is a decimal string with three places, never a double', () {
      for (final (typed, wire) in [
        ('250', '250.000'),
        ('1.5', '1.500'),
        ('0.125', '0.125'),
        (' 007 ', '7.000'),
      ]) {
        final parsed = quantity.parse(TargetInput(amount: typed, unit: ' ml '));
        expect((parsed.target, parsed.unit), (wire, 'ml'), reason: typed);
        expect(parsed.target, isA<String>());
      }
    });

    test('round trip: initial(parse(x)) reads back as typed', () {
      for (final typed in ['250', '1.5', '0.125', '2000']) {
        final parsed = quantity.parse(TargetInput(amount: typed, unit: 'ml'));
        final back = quantity.initial(parsed.target, parsed.unit);
        expect((back.amount, back.unit), (typed, 'ml'));
      }
    });

    test('refuses more than 3 decimals, zero, negatives and non-numbers, by field', () {
      final cases = {
        '': TargetFieldError.required,
        '1.2345': TargetFieldError.tooPrecise,
        '0': TargetFieldError.notPositive,
        '0.000': TargetFieldError.notPositive,
        '-5': TargetFieldError.notPositive,
        'abc': TargetFieldError.notNumber,
        '1,5': TargetFieldError.notNumber,
        '1e3': TargetFieldError.notNumber,
        '9999999999': TargetFieldError.tooLarge,
      };
      cases.forEach((typed, error) {
        final parsed = quantity.parse(TargetInput(amount: typed, unit: 'ml'));
        expect((parsed.ok, parsed.amountError, parsed.target), (false, error, null), reason: typed);
      });
      expect(
        quantity.parse(const TargetInput(amount: '2', unit: ' ')).unitError,
        TargetFieldError.unitRequired,
      );
      expect(
        quantity.parse(TargetInput(amount: '2', unit: 'u' * 25)).unitError,
        TargetFieldError.unitTooLong,
      );
    });
  });

  group('duration', () {
    final duration = ui('duration');

    test('minutes become whole seconds, an integer', () {
      for (final (typed, seconds) in [('10', 600), ('1.5', 90), ('0.5', 30), ('90', 5400)]) {
        final parsed = duration.parse(TargetInput(amount: typed));
        expect((parsed.target, parsed.unit), (seconds, null), reason: typed);
        expect(parsed.target, isA<int>());
      }
    });

    test('round trip: any whole-second target reads back to the same seconds', () {
      for (final seconds in [600, 90, 100, 1, 1799]) {
        final input = duration.initial(seconds, null);
        expect(duration.parse(input).target, seconds, reason: input.amount);
      }
      expect(duration.initial(600, null).amount, '10');
    });

    test('refuses zero, negatives and non-numbers', () {
      for (final (typed, error) in [
        ('', TargetFieldError.required),
        ('0', TargetFieldError.notPositive),
        ('-1', TargetFieldError.notPositive),
        ('ten', TargetFieldError.notNumber),
        ('0.001', TargetFieldError.notPositive),
        ('100000', TargetFieldError.tooLarge),
      ]) {
        expect(duration.parse(TargetInput(amount: typed)).amountError, error, reason: typed);
      }
    });
  });

  testWidgets('format: display text from target and unit', (tester) async {
    late HabitFormat format;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            format = HabitFormat(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(ui('quantity').format(format, '2000.000', 'ml'), '2000 ml');
    expect(ui('duration').format(format, 600, null), '10 min');
    expect(ui('binary').format(format, 1, null), 'Yes / no');
  });

  testWidgets('an unknown type: a read-only card, and the habit is not editable', (tester) async {
    final habit = HabitView(
      payload: {'id': 'h1', 'name': 'Sleep', 'type': 'sleep_window', 'target_value': 8},
      confirmedVersion: 1,
      syncState: null,
      knownType: false,
    );
    expect(habit.editable, isNull);
    expect(habit.editBlocked, HabitEditBlock.unknownType);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: UnknownTypeCard()),
      ),
    );
    expect(find.text('This habit needs a newer version of the app'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
  });

  group('4.3b: amount entry, steps and progress text', () {
    test('only quantity and duration take an amount', () {
      expect(
        {for (final e in registry.all) e.key: e.hasAmountEntry},
        {'binary': false, 'quantity': true, 'duration': true},
      );
    });

    test('parseAmount: quantity is a thousandths string, duration whole seconds', () {
      final q = ui('quantity');
      final d = ui('duration');
      expect(
        [
          for (final t in ['250', '0.25', '1.5']) q.parseAmount(t).delta,
        ],
        ['250.000', '0.250', '1.500'],
      );
      expect(
        [
          for (final t in ['1', '1.5', '0.25']) d.parseAmount(t).delta,
        ],
        [60, 90, 15],
      );
      for (final e in [q, d]) {
        for (final (typed, error) in [
          ('', TargetFieldError.required),
          ('0', TargetFieldError.notPositive),
          ('-2', TargetFieldError.notPositive),
          ('1.2345', TargetFieldError.tooPrecise),
          ('ten', TargetFieldError.notNumber),
          ('9999999999', TargetFieldError.tooLarge),
        ]) {
          expect(e.parseAmount(typed).error, error, reason: '${e.key} "$typed"');
        }
      }
    });

    test('suggestStep: the nice number nearest an eighth of the target', () {
      final q = ui('quantity');
      expect(
        [
          for (final t in ['2000.000', '2.000', '20.000', '8.000', '10000.000', '0.003'])
            q.suggestStep(t, null),
        ],
        [250000, 250, 2500, 1000, 1000000, 1],
        reason: '250 ml, 0.25 L, 2.5 pages, 1 glass, 1000 steps, 0.001',
      );
      expect(ui('duration').suggestStep(600, null), 60);
    });

    testWidgets('progress, the plus label and the timer clock', (tester) async {
      late HabitFormat format;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              format = HabitFormat(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final q = ui('quantity');
      final d = ui('duration');
      expect(q.progress(format, '1.250', '2.000', 'L'), '1.25 / 2 L');
      expect(q.plusAmount(format, 250000, 'mL'), '+250 mL');
      expect(d.progress(format, 360, 600, null), '6 / 10 min');
      expect(d.progress(format, 390, 600, null), '6 min 30 s / 10 min');
      expect(d.plusAmount(format, 60, null), '+1 min');
      // 4.3c A1: how a logged value reads on 19.
      expect(q.entryText(format, 1500, 'L'), '1.5 L');
      expect(d.entryText(format, 360, null), '6 min');
      expect(ui('binary').entryText(format, 1, null), 'Done');
      expect(ui('binary').entryText(format, 0, null), 'Not done');
      expect((q.amountInput(250000), d.amountInput(60), d.amountInput(90)), ('250', '1', '1.5'));
      expect(
        [
          for (final s in [0, 360, 3599, 3725]) timerClock(Duration(seconds: s)),
        ],
        ['00:00', '06:00', '59:59', '1:02:05'],
      );
    });
  });
}
