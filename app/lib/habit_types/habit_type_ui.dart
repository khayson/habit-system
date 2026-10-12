import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// A21 / invariant 14: how each habit type is entered and shown on screens 08 and 09. The only
/// UI code that knows the types; its keys come from [ProvisionalTypeRegistry]. A type this app
/// does not know has no entry: screens show [UnknownTypeCard] and no edit controls.
class HabitTypeUiRegistry {
  final Map<String, HabitTypeUi> _entries;

  HabitTypeUiRegistry(Iterable<HabitTypeUi> entries)
    : _entries = {for (final e in entries) e.key: e};

  factory HabitTypeUiRegistry.builtins() =>
      HabitTypeUiRegistry(const [YesNoTypeUi(), QuantityTypeUi(), DurationTypeUi()]);

  HabitTypeUi? lookup(String? key) => key == null ? null : _entries[key];

  /// In the design's order (08's segmented control: Yes / no, Quantity, Duration).
  List<HabitTypeUi> get all => _entries.values.toList();
}

/// Why a target input could not become a wire value. Screens word it (calm, never blaming).
enum TargetFieldError {
  required,
  notNumber,
  tooPrecise,
  notPositive,
  tooLarge,
  unitRequired,
  unitTooLong,
}

/// [HabitTypeUi.parseAmount]'s result (4.3b): the delta in wire form, or why not.
class AmountParse {
  final Object? delta;
  final TargetFieldError? error;

  const AmountParse({this.delta, this.error});

  bool get ok => error == null;
}

/// What the person typed (or what an existing habit starts with).
class TargetInput {
  final String amount;
  final String unit;

  const TargetInput({this.amount = '', this.unit = ''});
}

/// [parse]'s result: the draft's target and unit, or a message per field.
class TargetParse {
  final Object? target;
  final String? unit;
  final TargetFieldError? amountError;
  final TargetFieldError? unitError;

  const TargetParse({this.target, this.unit, this.amountError, this.unitError});

  bool get ok => amountError == null && unitError == null;
}

/// The target input's text state, owned (and disposed) by the screen so typed text survives a
/// failed submit or a type switch.
class TargetFields {
  final amount = TextEditingController();
  final unit = TextEditingController();
  final amountFocus = FocusNode();
  final unitFocus = FocusNode();

  TargetInput get value => TargetInput(amount: amount.text, unit: unit.text);

  void set(TargetInput input) {
    amount.text = input.amount;
    unit.text = input.unit;
  }

  void dispose() {
    amount.dispose();
    unit.dispose();
    amountFocus.dispose();
    unitFocus.dispose();
  }
}

abstract class HabitTypeUi {
  const HabitTypeUi();

  ProvisionalTypeRules get rules;

  String get key => rules.key;

  /// Yes / no habits have no target field (the target is 1).
  bool get hasTargetInput;

  /// The input an existing habit starts with (09).
  TargetInput initial(Object? target, String? unit);

  /// The draft's target_value and unit from what was typed, or a field error.
  TargetParse parse(TargetInput input);

  /// Display text ("2000 ml", "10 min", "Yes / no").
  String format(HabitFormat format, Object? target, String? unit);

  /// 4.3b: progress is added by an amount (screen 34, the Today quick-add). Yes / no is not.
  bool get hasAmountEntry => false;

  /// The delta (wire form) from what was typed on 34, or a field error.
  AmountParse parseAmount(String text) => const AmountParse(error: TargetFieldError.notNumber);

  /// One step of the stepper and the Today quick-add, in the type's units.
  int suggestStep(Object? target, String? unit) => 1;

  /// "1.25 / 2 L", "6 / 10 min": the day's value over the target in force; [spoken] reads
  /// "1.25 of 2 L" for screen readers.
  String progress(
    HabitFormat format,
    Object? value,
    Object? target,
    String? unit, {
    bool spoken = false,
  }) => format.typeLabel(rules);

  /// "+250 ml", "+1 min": an amount in the type's units as an addition.
  String plusAmount(HabitFormat format, int units, String? unit) => '+$units';

  /// "250 ml", "1 min": an amount in the type's units.
  String amountText(HabitFormat format, int units, String? unit) => '$units';

  /// The amount field's own text for [units] ("250", "1.5").
  String amountInput(int units) => '$units';

  /// 4.3c: how a logged value reads on screen 19 ("1.5 L", "6 min", "Done").
  String entryText(HabitFormat format, int units, String? unit) => amountText(format, units, unit);

  /// Screen 34's title and its field's label.
  /// ASSUMPTION(4.3b-amount-title): a title per kind, not the design's one sample habit's.
  String amountTitle(AppLocalizations l10n) => l10n.amountTitleProgress;
  String amountFieldLabel(AppLocalizations l10n, String? unit) => l10n.amountCustomIn(unit ?? '');

  /// The target field(s). [amountError] / [unitError] are already worded.
  Widget buildTarget(
    BuildContext context,
    TargetFields fields, {
    String? amountError,
    String? unitError,
    ValueChanged<String>? onChanged,
  });
}

class YesNoTypeUi extends HabitTypeUi {
  const YesNoTypeUi();

  @override
  ProvisionalTypeRules get rules => const BinaryRules();

  @override
  bool get hasTargetInput => false;

  @override
  TargetInput initial(Object? target, String? unit) => const TargetInput();

  @override
  TargetParse parse(TargetInput input) => TargetParse(target: rules.formatValue(1));

  @override
  String entryText(HabitFormat format, int units, String? unit) =>
      units >= 1 ? format.l10n.entryDone : format.l10n.entryNotDone;

  @override
  String format(HabitFormat format, Object? target, String? unit) => format.typeLabel(rules);

  @override
  Widget buildTarget(
    BuildContext context,
    TargetFields fields, {
    String? amountError,
    String? unitError,
    ValueChanged<String>? onChanged,
  }) => const SizedBox.shrink();
}

class QuantityTypeUi extends HabitTypeUi {
  const QuantityTypeUi();

  @override
  ProvisionalTypeRules get rules => const QuantityRules();

  @override
  bool get hasTargetInput => true;

  @override
  TargetInput initial(Object? target, String? unit) {
    final units = rules.parseTarget(target);
    return TargetInput(amount: units == null ? '' : _plain(units, 3), unit: unit ?? '');
  }

  @override
  TargetParse parse(TargetInput input) {
    final amount = _decimal(input.amount, maxFraction: 3);
    final unit = input.unit.trim();
    TargetFieldError? unitError;
    if (unit.isEmpty) unitError = TargetFieldError.unitRequired;
    if (unit.runes.length > 24) unitError = TargetFieldError.unitTooLong;
    if (amount.error != null || unitError != null) {
      return TargetParse(amountError: amount.error, unitError: unitError);
    }
    // A decimal string with exactly three places, never a double ("250" -> "250.000").
    final wire = rules.formatValue(amount.thousandths!);
    if (rules.parseTarget(wire) == null) {
      return const TargetParse(amountError: TargetFieldError.tooLarge);
    }
    return TargetParse(target: wire, unit: unit);
  }

  @override
  String format(HabitFormat format, Object? target, String? unit) =>
      format.amount(rules, target, unit) ?? format.typeLabel(rules);

  @override
  bool get hasAmountEntry => true;

  @override
  AmountParse parseAmount(String text) {
    final amount = _decimal(text, maxFraction: 3);
    if (amount.error != null) return AmountParse(error: amount.error);
    // A decimal string with three places ("250" -> "250.000"), never a double.
    final wire = rules.formatValue(amount.thousandths!);
    if (rules.parseValue(wire) == null) return const AmountParse(error: TargetFieldError.tooLarge);
    return AmountParse(delta: wire);
  }

  /// ASSUMPTION(4.3b-step): the "nice" number (1, 2, 2.5 or 5 times a power of ten, never below
  /// 0.001) nearest by ratio to an eighth of the target.
  @override
  int suggestStep(Object? target, String? unit) {
    final t = rules.parseTarget(target);
    if (t == null) return 1000;
    return niceStep(t / 8);
  }

  @override
  String progress(
    HabitFormat format,
    Object? value,
    Object? target,
    String? unit, {
    bool spoken = false,
  }) {
    final v = rules.parseValue(value) ?? 0;
    final t = rules.parseTarget(target) ?? 0;
    final of = spoken ? format.l10n.progressOfSpoken : format.l10n.progressOf;
    return of(format.decimal(v), format.decimal(t), unit ?? '').trim();
  }

  @override
  String plusAmount(HabitFormat format, int units, String? unit) =>
      format.l10n.plusAmount(amountText(format, units, unit));

  @override
  String amountText(HabitFormat format, int units, String? unit) =>
      [format.decimal(units), if (unit != null && unit.isNotEmpty) unit].join(' ');

  @override
  String amountInput(int units) => _plain(units, 3);

  @override
  Widget buildTarget(
    BuildContext context,
    TargetFields fields, {
    String? amountError,
    String? unitError,
    ValueChanged<String>? onChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    final amount = TextField(
      key: const ValueKey('target-amount'),
      controller: fields.amount,
      focusNode: fields.amountFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l10n.targetAmount,
        error: amountError == null ? null : FieldErrorText(amountError),
      ),
    );
    final unit = TextField(
      key: const ValueKey('target-unit'),
      controller: fields.unit,
      focusNode: fields.unitFocus,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l10n.targetUnit,
        hintText: l10n.targetUnitHint,
        error: unitError == null ? null : FieldErrorText(unitError),
      ),
    );
    // Side by side as in the design; stacked when large text would squeeze them.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        children: [
          amount,
          const SizedBox(height: HabitSpace.s12),
          unit,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: amount),
        const SizedBox(width: HabitSpace.s12),
        Expanded(flex: 2, child: unit),
      ],
    );
  }
}

class DurationTypeUi extends HabitTypeUi {
  const DurationTypeUi();

  @override
  ProvisionalTypeRules get rules => const DurationRules();

  @override
  bool get hasTargetInput => true;

  @override
  TargetInput initial(Object? target, String? unit) {
    final seconds = rules.parseTarget(target);
    // Minutes with up to three places: any whole-second target reads back to the same seconds.
    return TargetInput(amount: seconds == null ? '' : _plain((seconds * 1000 / 60).round(), 3));
  }

  @override
  TargetParse parse(TargetInput input) {
    final minutes = _decimal(input.amount, maxFraction: 3);
    if (minutes.error != null) return TargetParse(amountError: minutes.error);
    // Whole seconds, an integer, never a double.
    final seconds = (minutes.thousandths! * 60 / 1000).round();
    if (seconds <= 0) return const TargetParse(amountError: TargetFieldError.notPositive);
    final wire = rules.formatValue(seconds);
    if (rules.parseTarget(wire) == null) {
      return const TargetParse(amountError: TargetFieldError.tooLarge);
    }
    return TargetParse(target: wire);
  }

  @override
  String format(HabitFormat format, Object? target, String? unit) =>
      format.amount(rules, target, null) ?? format.typeLabel(rules);

  @override
  bool get hasAmountEntry => true;

  @override
  AmountParse parseAmount(String text) {
    final minutes = _decimal(text, maxFraction: 3);
    if (minutes.error != null) return AmountParse(error: minutes.error);
    // Whole seconds, an integer, never a double.
    final seconds = (minutes.thousandths! * 60 / 1000).round();
    if (seconds <= 0) return const AmountParse(error: TargetFieldError.notPositive);
    final wire = rules.formatValue(seconds);
    if (rules.parseValue(wire) == null) return const AmountParse(error: TargetFieldError.tooLarge);
    return AmountParse(delta: wire);
  }

  /// ASSUMPTION(4.3b-step): one minute, as design 05's "+1 min".
  @override
  int suggestStep(Object? target, String? unit) => 60;

  /// Minutes; seconds only when the value is not whole minutes ("6 min 30 s / 10 min").
  @override
  String progress(
    HabitFormat format,
    Object? value,
    Object? target,
    String? unit, {
    bool spoken = false,
  }) {
    final v = rules.parseValue(value) ?? 0;
    final t = rules.parseTarget(target) ?? 0;
    final shown = v % 60 == 0 ? '${v ~/ 60}' : format.l10n.minutesSeconds(v ~/ 60, v % 60);
    final of = spoken ? format.l10n.progressOfSpoken : format.l10n.progressOf;
    return of(shown, format.minutes(t), format.l10n.minutesUnit);
  }

  @override
  String plusAmount(HabitFormat format, int units, String? unit) =>
      format.l10n.plusAmount(amountText(format, units, unit));

  @override
  String amountText(HabitFormat format, int units, String? unit) =>
      format.l10n.minutesShort(format.minutes(units));

  @override
  String amountInput(int units) => _plain((units * 1000 / 60).round(), 3);

  @override
  String amountTitle(AppLocalizations l10n) => l10n.amountTitleTime;

  @override
  String amountFieldLabel(AppLocalizations l10n, String? unit) => l10n.amountCustomMinutes;

  @override
  Widget buildTarget(
    BuildContext context,
    TargetFields fields, {
    String? amountError,
    String? unitError,
    ValueChanged<String>? onChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const ValueKey('target-amount'),
      controller: fields.amount,
      focusNode: fields.amountFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l10n.targetMinutes,
        suffixText: l10n.targetMinutesSuffix,
        error: amountError == null ? null : FieldErrorText(amountError),
      ),
    );
  }
}

/// "250", "1.5", "-2", "abc": a plain decimal with '.' as the separator, as thousandths.
({int? thousandths, TargetFieldError? error}) _decimal(String text, {required int maxFraction}) {
  final t = text.trim();
  if (t.isEmpty) return (thousandths: null, error: TargetFieldError.required);
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(t);
  if (match == null) return (thousandths: null, error: TargetFieldError.notNumber);
  final fraction = match.group(3) ?? '';
  if (fraction.length > maxFraction) return (thousandths: null, error: TargetFieldError.tooPrecise);
  final whole = match.group(2)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (whole.length > 12) return (thousandths: null, error: TargetFieldError.tooLarge);
  final value = int.parse(whole) * 1000 + int.parse(fraction.padRight(3, '0'));
  if (match.group(1)!.isNotEmpty || value == 0) {
    return (thousandths: null, error: TargetFieldError.notPositive);
  }
  return (thousandths: value, error: null);
}

/// The "nice" step (1, 2, 2.5 or 5 times a power of ten, in thousandths, at least 1) nearest
/// to [ideal] by ratio; a tie goes to the smaller step.
int niceStep(double ideal) {
  int? best;
  var bestScore = double.infinity;
  for (var power = 1; power <= 1000000000000; power *= 10) {
    for (final m in const [10, 20, 25, 50]) {
      if ((m * power) % 10 != 0) continue;
      final step = m * power ~/ 10;
      if (step < 1) continue;
      final ratio = ideal <= 0 ? double.infinity : (step > ideal ? step / ideal : ideal / step);
      if (ratio < bestScore) {
        best = step;
        bestScore = ratio;
      }
    }
  }
  return best ?? 1;
}

/// "06:00", "1:02:05": a timer's elapsed time (h:mm:ss from one hour).
String timerClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(d.inMinutes)}:${two(s)}';
}

/// Thousandths as plain text with no grouping and no trailing zeros: 2000000 -> "2000".
String _plain(int thousandths, int places) {
  final whole = thousandths ~/ 1000;
  final fraction = (thousandths % 1000)
      .toString()
      .padLeft(places, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

/// A21: a habit of a type this app version does not know. Read-only; no edit controls.
// ASSUMPTION(4.2b-unknown-card-copy): the title is the prompt's; the body line is ours.
class UnknownTypeCard extends StatelessWidget {
  const UnknownTypeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      title: l10n.unknownTypeTitle,
      body: l10n.unknownTypeBody,
      tone: Tone.info,
      icon: Icons.system_update_outlined,
    );
  }
}
