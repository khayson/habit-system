import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../data/conflicts.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../domain/frequency_choice.dart';
import '../domain/habit_draft.dart';
import '../habit_types/habit_type_ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_form.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import '../widgets/schedule_text.dart';
import 'frequency_screen.dart';
import 'widgets/habit_icon_picker.dart';
import '../widgets/habit_icons.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_toast.dart';

/// Screen 09: edit a habit (A34). Starts from the latest definition with any unsent edit
/// (HabitView.editable), never the one in force; saves through habit.update, which the server
/// dates. Local data only: works offline.
class EditHabitScreen extends StatelessWidget {
  final String habitId;
  final DateTime Function() clock;

  const EditHabitScreen({super.key, required this.habitId, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey('${account.session.userId}/$habitId/edit'),
      create: (_) => StreamModel<HabitDetail?>(
        TimeZones.ready.then((_) => account.view.watchDetail(habitId, clock)),
      ),
      child: _Edit(habitId: habitId),
    );
  }
}

class _Edit extends StatefulWidget {
  final String habitId;

  const _Edit({required this.habitId});

  @override
  State<_Edit> createState() => _EditState();
}

class _EditState extends State<_Edit> {
  final _types = HabitTypeUiRegistry.builtins();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _target = TargetFields();
  HabitDraft? _start;
  late String _category;
  late FrequencyChoice _frequency;

  /// A53: the habit's icon key (kept as is, even one this app does not know).
  String? _icon;
  HabitFormErrors _errors = HabitFormErrors.none;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _target.dispose();
    super.dispose();
  }

  /// The form is filled once, from the first view of the habit; later changes to the habit
  /// (a sync) never overwrite what the person is typing.
  void _seed(HabitDraft draft, HabitTypeUi type) {
    if (_start != null) return;
    _start = draft;
    _name.text = draft.name;
    _category = draft.category;
    _frequency = FrequencyChoice(draft.frequencyType, draft.frequencyConfig);
    _icon = draft.icon;
    _target.set(type.initial(draft.targetValue, draft.unit));
  }

  /// A53: the picker.
  Future<void> _pickIcon() async {
    final picked = await pickHabitIcon(context, current: HabitIconCatalog.keyFor(_icon, _category));
    if (picked != null && mounted) {
      setState(() {
        _icon = picked;
      });
    }
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.habit(widget.habitId));

  Future<void> _save(AccountContext account, HabitTypeUi type) async {
    final l10n = AppLocalizations.of(context);
    final result = validateHabitForm(
      l10n: l10n,
      type: type,
      name: _name.text,
      category: _category,
      target: _target.value,
      frequency: _frequency,
      icon: _icon,
    );
    setState(() => _errors = result.errors);
    final draft = result.draft;
    if (draft == null) {
      if (_errors.name != null) {
        _nameFocus.requestFocus();
      } else if (_errors.amount != null) {
        _target.amountFocus.requestFocus();
      } else if (_errors.unit != null) {
        _target.unitFocus.requestFocus();
      }
      return;
    }
    // L1: a change pulled while the form was open is kept where the person did not edit.
    final current = context.read<StreamModel<HabitDetail?>>().value?.habit.editable;
    final toSave = current == null ? draft : HabitDraft.merged(_start!, current, draft, type.rules);
    setState(() => _busy = true);
    try {
      // Unchanged: the writer writes nothing; the screen just closes.
      await account.actions.updateHabit(widget.habitId, toSave);
      if (mounted) {
        // 6.7 review: the toast is the only sign it worked, so only when something changed.
        final changed = current == null || !toSave.sameAs(current, type.rules);
        final toast = AppToast.of(context);
        _leave();
        if (changed) toast.show(l10n.editSaved);
      }
    } on HabitEditFailure catch (e) {
      if (!mounted) return;
      switch (e.kind) {
        case HabitEditFailureKind.invalid:
          setState(() => _errors = HabitFormErrors.fromProblems(l10n, e.problems));
        case HabitEditFailureKind.needsAttention:
          // The app's place for changes that need a look: the sync queue (screen 18).
          context.push(Routes.queue);
        case HabitEditFailureKind.archived:
          _backToLibrary(l10n.editBlockedArchived);
        case HabitEditFailureKind.unknownHabit:
          _backToLibrary(l10n.editGone);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLibrary(String message) {
    final toast = AppToast.of(context);
    context.go(Routes.habits);
    toast.show(message, tone: ToastTone.info);
  }

  Future<void> _archive(AccountContext account) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        final text = Theme.of(sheet).textTheme;
        final tokens = HabitTokens.of(sheet);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              HabitSpace.margin,
              0,
              HabitSpace.margin,
              HabitSpace.margin,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(l10n.archiveTitle, style: text.titleLarge)),
                const SizedBox(height: HabitSpace.s8),
                Text(l10n.archiveBody, style: text.bodyLarge?.copyWith(color: tokens.muted)),
                const SizedBox(height: HabitSpace.s24),
                PrimaryButton(
                  label: l10n.archiveConfirm,
                  onPressed: () => Navigator.pop(sheet, true),
                ),
                const SizedBox(height: HabitSpace.s8),
                TextButton(
                  onPressed: () => Navigator.pop(sheet, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                  ),
                  child: Text(l10n.archiveNotNow),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await account.actions.archiveHabit(widget.habitId);
      if (mounted) context.go(Routes.habits);
    } on HabitEditFailure catch (e) {
      if (!mounted) return;
      if (e.kind == HabitEditFailureKind.needsAttention) {
        context.push(Routes.queue);
      } else {
        _backToLibrary(l10n.editGone);
      }
    }
  }

  Future<void> _chooseCategory(HabitFormat format) async {
    final l10n = AppLocalizations.of(context);
    // L3: the design's three, and always the habit's own value, even when it is another one.
    final options = [
      ...const ['health', 'mindfulness', 'learning'],
      if (!const ['health', 'mindfulness', 'learning'].contains(_start!.category)) _start!.category,
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: HabitSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: HabitSpace.margin),
                child: Semantics(
                  header: true,
                  child: Text(l10n.chooseCategory, style: Theme.of(sheet).textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: HabitSpace.s8),
              for (final c in options)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  child: ListTile(
                    selected: c == _category,
                    minTileHeight: HabitSize.control,
                    contentPadding: const EdgeInsets.symmetric(horizontal: HabitSpace.margin),
                    leading: AppIcon(
                      c == _category ? AppIcons.check : AppIcons.unselected,
                      size: c == _category ? 24 : 16,
                      color: HabitTokens.of(sheet).primary,
                    ),
                    title: Text(format.category(c, long: true)),
                    onTap: () => Navigator.pop(sheet, c),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _category = chosen);
  }

  Future<void> _editSchedule(HabitDetail detail) async {
    final choice = await context.push<FrequencyChoice>(
      Routes.frequency,
      extra: FrequencyRequest(habitName: _name.text, current: _frequency, today: detail.today),
    );
    if (choice != null && mounted) setState(() => _frequency = choice);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    final detail = context.watch<StreamModel<HabitDetail?>>().value;
    if (account == null || detail == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final format = HabitFormat(context);
    final habit = detail.habit;
    final type = _types.lookup(habit.payload['type'] as String?);
    final draft = habit.editable;
    final header = ScreenHeader(
      title: l10n.editTitle(_start?.name ?? detail.name),
      subtitle: l10n.editSubtitle,
      onBack: _leave,
    );
    if (draft == null || type == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              header,
              EditBlockedNote(habit: habit),
            ],
          ),
        ),
      );
    }
    _seed(draft, type);

    final pendingFrom = habit.pendingFrom;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            header,
            if (habit.definitionEditQueued) ...[
              InfoCard(title: l10n.editWaiting, tone: Tone.info, icon: AppIcons.sync),
              const SizedBox(height: HabitSpace.s16),
            ] else if (pendingFrom != null) ...[
              InfoCard(
                title: l10n.editStarts(format.dayMonth(pendingFrom)),
                tone: Tone.info,
                icon: AppIcons.startDate,
              ),
              const SizedBox(height: HabitSpace.s16),
            ],
            FieldLabel(l10n.newHabitName),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_errors.name != null) setState(() => _errors = _errors.without(name: true));
              },
              decoration: InputDecoration(
                error: _errors.name == null ? null : FieldErrorText(_errors.name!),
              ),
            ),
            if (type.hasTargetInput) ...[
              const SizedBox(height: HabitSpace.s24),
              FieldLabel(type.rules.takesUnit ? l10n.editTargetUnit : l10n.newHabitTarget),
              type.buildTarget(
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
            const SizedBox(height: HabitSpace.s16),
            Text(
              l10n.editTypeLine(format.typeLabel(type.rules)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: HabitSpace.s4),
            Text(
              l10n.editTypeNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: HabitTokens.of(context).muted),
            ),
            const SizedBox(height: HabitSpace.s24),
            SettingRow(
              icon: AppIcons.leaf,
              title: l10n.editCategory,
              summary: format.category(_category, long: true),
              action: l10n.setupEdit,
              onAction: () => _chooseCategory(format),
              message: _errors.category,
            ),
            const SizedBox(height: HabitSpace.s16),
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
              onAction: () => _editSchedule(detail),
              message: _errors.schedule,
            ),
            const SizedBox(height: HabitSpace.s16),
            SettingRow(
              icon: AppIcons.reminder,
              title: l10n.editReminders,
              summary: _reminderSummary(context, detail),
              action: l10n.setupEdit,
              onAction: () => context.push(Routes.habitReminder(widget.habitId)),
            ),
            const SizedBox(height: HabitSpace.s16),
            InfoCard(title: l10n.editHistoryTitle, body: l10n.editHistoryBody, tone: Tone.info),
            const SizedBox(height: HabitSpace.s24),
            PrimaryButton(
              label: l10n.editSave,
              loading: _busy,
              onPressed: () => _save(account, type),
            ),
            const SizedBox(height: HabitSpace.s16),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _archive(account),
                style: TextButton.styleFrom(
                  minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                ),
                child: Text(l10n.editArchive),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ASSUMPTION(4.2b-reminders-summary): the design shows times and a count; the row reads the
  // times, with the count in words when there is more than one.
  static String _reminderSummary(BuildContext context, HabitDetail detail) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String time(String hhmm) {
      final parts = hhmm.split(':');
      return DateFormat.jm(locale)
          .format(DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
    }

    final on = detail.reminders.where((r) => r.enabled).toList();
    if (detail.reminders.isNotEmpty && on.isEmpty) return l10n.reminderSummaryOff;
    return l10n.editRemindersSummary(on.length, on.map((r) => time(r.localTime)).join(' · '));
  }
}

/// Why a habit cannot be edited here, in words, with the way forward (09 and 12).
// ASSUMPTION(4.2b-blocked-note-copy): no design for these notes; the wording is ours.
class EditBlockedNote extends StatelessWidget {
  final HabitView habit;

  const EditBlockedNote({super.key, required this.habit});

  /// 4.3c: one reviewable change for this habit opens 19; otherwise the queue lists them.
  Future<void> _review(BuildContext context) async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    final open = await account.view.reviewableFor(habit.id);
    if (!context.mounted) return;
    context.push(open.length == 1 ? Routes.review(open.single) : Routes.queue);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (habit.editBlocked) {
      HabitEditBlock.unknownType => const UnknownTypeCard(),
      HabitEditBlock.needsAttention => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(title: l10n.editBlockedAttention, tone: Tone.warning, icon: AppIcons.alert),
          const SizedBox(height: HabitSpace.s8),
          TextButton(
            onPressed: () => _review(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
            ),
            child: Text(l10n.editReview),
          ),
        ],
      ),
      HabitEditBlock.archived => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(title: l10n.editBlockedArchived, tone: Tone.info, icon: AppIcons.archiveBox),
          const SizedBox(height: HabitSpace.s8),
          TextButton(
            onPressed: () => context.push(Routes.archivedHabits),
            style: TextButton.styleFrom(
              minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
            ),
            child: Text(l10n.archivedTitle),
          ),
        ],
      ),
      null => const SizedBox.shrink(),
    };
  }
}
