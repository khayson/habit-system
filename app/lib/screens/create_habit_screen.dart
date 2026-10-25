import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/account_calendar.dart';
import '../data/local_mutation_service.dart';
import '../domain/frequency_choice.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../widgets/habit_form.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import '../widgets/schedule_text.dart';
import 'frequency_screen.dart';
import 'reminder_editor_screen.dart';
import 'widgets/habit_icon_picker.dart';
import '../widgets/habit_icons.dart';
import '../widgets/app_icons.dart';

/// Screen 08: create a habit of any type the app knows (A21 registry), with its target, category,
/// schedule (10) and an optional first reminder (11). Validated as the server would before
/// anything is written; written locally first (works offline), habit and reminder in one
/// transaction.
class CreateHabitScreen extends StatefulWidget {
  /// The device clock: the start date and 10's interval range come from today (a test seam).
  final DateTime Function() clock;

  const CreateHabitScreen({super.key, this.clock = DateTime.now});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _types = HabitTypeUiRegistry.builtins();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _target = TargetFields();
  // ASSUMPTION(4.2b-default-type): 08 opens on Yes / no, the registry's first type (the design
  // shows Duration selected in its mock-up; the smallest habit is the calmer default).
  late HabitTypeUi _type = _types.all.first;
  String _category = _categories.first;
  FrequencyChoice _frequency = FrequencyChoice.daily;
  ReminderDraft? _reminder;

  /// A53: the icon to send; suggested from the name until the person picks one.
  String? _icon;
  bool _iconPicked = false;
  HabitFormErrors _errors = HabitFormErrors.none;
  bool _busy = false;

  /// The design's three categories, mapped to the API's values.
  static const _categories = ['health', 'mindfulness', 'learning'];

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _create(AccountContext account) async {
    final l10n = AppLocalizations.of(context);
    final result = validateHabitForm(
      l10n: l10n,
      type: _type,
      name: _name.text,
      category: _category,
      target: _target.value,
      frequency: _frequency,
      icon: _icon,
    );
    setState(() => _errors = result.errors);
    final draft = result.draft;
    if (draft == null) {
      _focusFirstError();
      return;
    }
    setState(() => _busy = true);
    try {
      await TimeZones.ready;
      final reminder = _reminder;
      await account.actions.createHabit(
        draft,
        type: _type.key,
        reminder: reminder == null
            ? null
            : NewReminder(
                localTime: reminder.localTime,
                daysOfWeek: reminder.days,
                enabled: reminder.enabled,
              ),
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.today);
      }
    } on HabitEditFailure catch (e) {
      // The same rules ran above; kept so a refusal is never silent.
      if (mounted) {
        setState(() => _errors = HabitFormErrors.fromProblems(l10n, e.problems));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A53: the picker; a pick is the person's own and stops the name suggestion.
  Future<void> _pickIcon() async {
    final picked = await pickHabitIcon(context, current: HabitIconCatalog.keyFor(_icon, _category));
    if (picked != null && mounted) {
      setState(() {
        _icon = picked;
        _iconPicked = true;
      });
    }
  }

  void _focusFirstError() {
    if (_errors.name != null) {
      _nameFocus.requestFocus();
    } else if (_errors.amount != null) {
      _target.amountFocus.requestFocus();
    } else if (_errors.unit != null) {
      _target.unitFocus.requestFocus();
    }
  }

  Future<void> _editSchedule(AccountContext account) async {
    final now = widget.clock();
    final calendar = await AccountCalendar.load(account.writer.db, deviceNow: now);
    if (calendar == null || !mounted) return;
    final choice = await context.push<FrequencyChoice>(
      Routes.frequency,
      extra: FrequencyRequest(
        habitName: _name.text,
        current: _frequency,
        today: calendar.today(now),
      ),
    );
    if (choice != null && mounted) {
      setState(() {
        _frequency = choice;
        _errors = HabitFormErrors(
          name: _errors.name,
          amount: _errors.amount,
          unit: _errors.unit,
          category: _errors.category,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final reminder = _reminder;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.newHabitTitle,
              subtitle: l10n.newHabitSubtitle,
              onBack: () => context.canPop() ? context.pop() : context.go(Routes.today),
            ),
            FieldLabel(l10n.newHabitName),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (name) => setState(() {
                if (_errors.name != null) _errors = _errors.without(name: true);
                if (!_iconPicked) _icon = HabitIconCatalog.suggest(name);
              }),
              decoration: InputDecoration(
                hintText: l10n.newHabitName,
                error: _errors.name == null ? null : FieldErrorText(_errors.name!),
              ),
            ),
            const SizedBox(height: HabitSpace.s24),
            FieldLabel(l10n.newHabitType),
            SegmentedTabs(
              labels: [for (final t in _types.all) format.typeLabel(t.rules)],
              selected: _types.all.indexOf(_type),
              onSelected: (i) => setState(() {
                // Typed text stays in the fields; only the messages for the old type go.
                _type = _types.all[i];
                _errors = _errors.without(target: true);
              }),
            ),
            if (_type.hasTargetInput) ...[
              const SizedBox(height: HabitSpace.s24),
              FieldLabel(l10n.newHabitTarget),
              _type.buildTarget(
                context,
                _target,
                amountError: _errors.amount,
                unitError: _errors.unit,
                onChanged: (_) {
                  if (_errors.amount != null || _errors.unit != null) {
                    setState(() => _errors = _errors.without(target: true));
                  }
                },
              ),
            ],
            const SizedBox(height: HabitSpace.s24),
            FieldLabel(l10n.newHabitCategory),
            SegmentedTabs(
              labels: [for (final c in _categories) format.category(c)],
              selected: _categories.indexOf(_category),
              onSelected: (i) => setState(() => _category = _categories[i]),
            ),
            if (_errors.category != null) ...[
              const SizedBox(height: HabitSpace.s8),
              FieldErrorText(_errors.category!),
            ],
            const SizedBox(height: HabitSpace.s24),
            SettingRow(
              key: const ValueKey('icon-row'),
              actionKey: const ValueKey('icon-row-edit'),
              icon: AppIcons.habit(_icon, category: _category),
              title: l10n.habitIconRow,
              summary: HabitIconCatalog.label(HabitIconCatalog.keyFor(_icon, _category)),
              action: l10n.setupEdit,
              onAction: _pickIcon,
            ),
            const SizedBox(height: HabitSpace.s16),
            SettingRow(
              icon: AppIcons.frequency,
              title: l10n.newHabitSchedule,
              summary: ScheduleText(context).summary(_frequency),
              action: l10n.setupEdit,
              onAction: () => _editSchedule(account),
              message: _errors.schedule,
            ),
            const SizedBox(height: HabitSpace.s16),
            SettingRow(
              icon: AppIcons.reminder,
              title: l10n.reminderRow,
              actionKey: const ValueKey('reminder-row-edit'),
              summary: reminder == null
                  ? l10n.reminderRowNone
                  : l10n.reminderRowSet(
                      DateFormat.jm(locale).format(
                        DateTime(2026, 1, 1, reminder.minuteOfDay ~/ 60, reminder.minuteOfDay % 60),
                      ),
                    ),
              action: l10n.setupEdit,
              onAction: () async {
                final draft = await context.push<ReminderDraft>(
                  Routes.reminderEditor,
                  extra: (_reminder, _name.text),
                );
                if (draft != null && mounted) setState(() => _reminder = draft);
              },
            ),
            const SizedBox(height: HabitSpace.s32),
            PrimaryButton(
              label: l10n.newHabitCreate,
              loading: _busy,
              onPressed: () => _create(account),
            ),
          ],
        ),
      ),
    );
  }
}
