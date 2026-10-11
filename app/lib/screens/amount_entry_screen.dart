import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_form_text.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screen 34: add an amount to today (A35 log.increment). Local data only: works offline. The
/// day's value and the target in force come from the local view, never the latest definition.
class AmountEntryScreen extends StatelessWidget {
  final String habitId;

  /// A prefilled amount in the type's units (the Today quick-add's step).
  final int? prefill;
  final DateTime Function() clock;

  const AmountEntryScreen({
    super.key,
    required this.habitId,
    this.prefill,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/$habitId/add'),
      create: (_) => StreamModel<HabitDetail?>(
        TimeZones.ready.then((_) => account.view.watchDetail(habitId, clock)),
      ),
      child: _Amount(habitId: habitId, prefill: prefill),
    );
  }
}

class _Amount extends StatefulWidget {
  final String habitId;
  final int? prefill;

  const _Amount({required this.habitId, required this.prefill});

  @override
  State<_Amount> createState() => _AmountState();
}

class _AmountState extends State<_Amount> {
  final _types = HabitTypeUiRegistry.builtins();
  final _field = TextEditingController();
  final _focus = FocusNode();
  int? _units;
  int _step = 1;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _seed(HabitTypeUi type, Object? target, String? unit) {
    if (_units != null) return;
    _step = type.suggestStep(target, unit);
    _units = widget.prefill ?? _step;
    _field.text = type.amountInput(_units!);
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.today);

  /// The stepper and the field follow each other: a valid typed amount moves the stepper.
  void _typed(HabitTypeUi type, String text) {
    final parsed = type.parseAmount(text);
    setState(() {
      _error = null;
      if (parsed.ok) _units = type.rules.parseValue(parsed.delta);
    });
  }

  void _stepBy(HabitTypeUi type, int direction) {
    final next = (_units ?? 0) + direction * _step;
    if (next <= 0) return;
    setState(() {
      _units = next;
      _error = null;
      _field.text = type.amountInput(next);
    });
  }

  Future<void> _save(AccountContext account, HabitTypeUi type) async {
    final l10n = AppLocalizations.of(context);
    final parsed = type.parseAmount(_field.text);
    if (!parsed.ok) {
      setState(
        () => _error = parsed.error == TargetFieldError.required
            ? l10n.amountRequired
            : HabitFormText(l10n).target(parsed.error!),
      );
      _focus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    try {
      await account.actions.addAmount(widget.habitId, parsed.delta!);
      if (mounted) _leave();
    } on LogFailure {
      if (mounted) setState(() => _error = l10n.amountTooMuch);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _timeIt(AccountContext account) async {
    await account.actions.startTimer(widget.habitId);
    if (mounted) context.pushReplacement(Routes.timer(widget.habitId));
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    final model = context.watch<StreamModel<HabitDetail?>>();
    final l10n = AppLocalizations.of(context);
    if (account == null || !model.hasValue) return const Scaffold();
    final detail = model.value;
    final type = detail == null ? null : _types.lookup(detail.habit.payload['type'] as String?);

    // No form for an unknown habit, an archived one, a type without amounts or one this app
    // does not know: the reason in words and a way back.
    final String? blocked = detail == null
        ? l10n.editGone
        : detail.habit.archived
        ? l10n.editBlockedArchived
        : type != null && !type.hasAmountEntry
        ? l10n.amountOneTap
        : null;
    if (blocked != null || type == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              ScreenHeader(title: detail?.name ?? '', onBack: _leave),
              if (blocked != null)
                InfoCard(title: blocked, tone: Tone.info, icon: Icons.info_outline)
              else
                const UnknownTypeCard(),
              const SizedBox(height: HabitSpace.s16),
              TextButton(
                onPressed: _leave,
                style: TextButton.styleFrom(
                  minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                ),
                child: Text(l10n.amountBack),
              ),
            ],
          ),
        ),
      );
    }

    final format = HabitFormat(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final today = detail!.today;
    final target = detail.targetOn(today);
    final unit = detail.schedule.unitOn(today) ?? detail.habit.payload['unit'] as String?;
    _seed(type, target, unit);
    final rules = type.rules;
    final saved = rules.parseValue(detail.logOn(today)?.value) ?? 0;
    final after = saved + (_units ?? 0);
    final targetUnits = rules.parseTarget(target);
    final reached = targetUnits != null && rules.isComplete(after, targetUnits);
    final amount = type.amountText(format, _units ?? 0, unit);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: type.amountTitle(l10n),
              subtitle: l10n.amountSubtitle(
                detail.name,
                type.progress(format, rules.formatValue(saved), target, unit),
              ),
              onBack: _leave,
            ),
            _Stepper(
              amount: amount,
              raised: type.amountText(format, (_units ?? 0) + _step, unit),
              lowered: type.amountText(format, (_units ?? 0) - _step, unit),
              canLower: (_units ?? 0) > _step,
              onLower: () => _stepBy(type, -1),
              onRaise: () => _stepBy(type, 1),
            ),
            const SizedBox(height: HabitSpace.s24),
            FieldLabel(type.amountFieldLabel(l10n, unit)),
            TextField(
              key: const ValueKey('amount-field'),
              controller: _field,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onChanged: (t) => _typed(type, t),
              decoration: InputDecoration(error: _error == null ? null : FieldErrorText(_error!)),
            ),
            const SizedBox(height: HabitSpace.s32),
            Container(
              padding: const EdgeInsets.all(HabitSpace.s16),
              decoration: BoxDecoration(
                color: tokens.positiveBg,
                borderRadius: BorderRadius.circular(HabitRadius.r16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.amountAfterSaving,
                    style: text.bodyMedium?.copyWith(color: tokens.positiveInk),
                  ),
                  const SizedBox(height: HabitSpace.s8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      type.progress(format, rules.formatValue(after), target, unit),
                      style: text.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s16),
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    reached ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    size: 18,
                    color: reached ? tokens.positiveInk : tokens.muted,
                  ),
                ),
                const SizedBox(width: HabitSpace.s8),
                Expanded(
                  child: Text(
                    reached ? l10n.amountReached : l10n.amountNotComplete,
                    style: text.bodyMedium?.copyWith(color: tokens.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HabitSpace.s32),
            PrimaryButton(
              label: l10n.amountAdd(amount),
              loading: _busy,
              onPressed: () => _save(account, type),
            ),
            const SizedBox(height: HabitSpace.s8),
            if (rules.supportsTimer)
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => _timeIt(account),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                  ),
                  child: Text(l10n.amountTimeIt),
                ),
              ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _leave,
                style: TextButton.styleFrom(
                  minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                ),
                child: Text(l10n.amountCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "-  250 mL  +": one adjustable control to a screen reader, announcing the amount.
class _Stepper extends StatelessWidget {
  final String amount;
  final String raised;
  final String lowered;
  final bool canLower;
  final VoidCallback onLower;
  final VoidCallback onRaise;

  const _Stepper({
    required this.amount,
    required this.raised,
    required this.lowered,
    required this.canLower,
    required this.onLower,
    required this.onRaise,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: onPressed == null ? tokens.disabledInk : tokens.primary),
      constraints: const BoxConstraints(
        minWidth: HabitSize.minTarget,
        minHeight: HabitSize.minTarget,
      ),
    );
    return Semantics(
      container: true,
      label: l10n.amountStepperLabel,
      value: amount,
      increasedValue: raised,
      decreasedValue: canLower ? lowered : null,
      onIncrease: onRaise,
      onDecrease: canLower ? onLower : null,
      child: SurfaceCard(
        child: Row(
          children: [
            button(Icons.remove, l10n.amountLess, canLower ? onLower : null),
            Expanded(
              child: ExcludeSemantics(
                child: Text(amount, textAlign: TextAlign.center, style: text.titleMedium),
              ),
            ),
            button(Icons.add, l10n.amountMore, onRaise),
          ],
        ),
      ),
    );
  }
}
