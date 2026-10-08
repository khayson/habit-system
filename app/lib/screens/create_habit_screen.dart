import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../core/validation.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../widgets/habit_ui.dart';

import 'package:intl/intl.dart';

import 'reminder_editor_screen.dart';

/// Screen 08, minimal (Phase 2b.1 review §6): name, category, and a yes/no habit every day. Type,
/// target, schedule and reminder editing arrive with Phase 4 and screens 10/11. Creating writes
/// locally first (works offline) and returns to Today.
class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _category = 'health';
  bool _busy = false;
  ReminderDraft? _reminder;

  /// The design's three categories, mapped to the API's values.
  static const _categories = ['health', 'mindfulness', 'learning'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(AccountContext account) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await TimeZones.ready;
      final reminder = _reminder;
      await account.actions.createOneTapHabit(
        name: _name.text,
        category: _category,
        reminderTime: reminder?.localTime,
        reminderDays: reminder?.days ?? const [1, 2, 3, 4, 5, 6, 7],
        reminderEnabled: reminder?.enabled ?? true,
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.today);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(AppLocalizations l10n, String category) => switch (category) {
    'mindfulness' => l10n.categoryMindful,
    'learning' => l10n.categoryLearning,
    _ => l10n.categoryHealth,
  };

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
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
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(hintText: l10n.newHabitName),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return l10n.errorRequired;
                  if (value.length > Validation.habitNameMaxLength) {
                    return l10n.newHabitNameTooLong;
                  }
                  return null;
                },
              ),
              const SizedBox(height: HabitSpace.s24),
              FieldLabel(l10n.newHabitType),
              SurfaceCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: tokens.primary),
                    const SizedBox(width: HabitSpace.s12),
                    Text(l10n.newHabitTypeYesNo, style: text.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(height: HabitSpace.s24),
              FieldLabel(l10n.newHabitCategory),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final c in _categories)
                    ButtonSegment(value: c, label: Text(_label(l10n, c))),
                ],
                selected: {_category},
                onSelectionChanged: (s) => setState(() => _category = s.first),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.control)),
                ),
              ),
              const SizedBox(height: HabitSpace.s24),
              SurfaceCard(
                child: Row(
                  children: [
                    const IconTile(icon: Icons.calendar_today_outlined),
                    const SizedBox(width: HabitSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.newHabitSchedule, style: text.titleMedium ?? text.bodyLarge),
                          Text(
                            l10n.newHabitDaily,
                            style: text.bodySmall?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HabitSpace.s16),
              SurfaceCard(
                child: Row(
                  children: [
                    const ExcludeSemantics(child: IconTile(icon: Icons.notifications_none)),
                    const SizedBox(width: HabitSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.reminderRow, style: text.titleMedium ?? text.bodyLarge),
                          Text(
                            _reminder == null
                                ? l10n.reminderRowNone
                                : l10n.reminderRowSet(
                                    DateFormat.jm(Localizations.localeOf(context).toLanguageTag())
                                        .format(
                                          DateTime(
                                            2026,
                                            1,
                                            1,
                                            _reminder!.minuteOfDay ~/ 60,
                                            _reminder!.minuteOfDay % 60,
                                          ),
                                        ),
                                  ),
                            style: text.bodySmall?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final draft = await context.push<ReminderDraft>(
                          Routes.reminderEditor,
                          extra: (_reminder, _name.text),
                        );
                        if (draft != null && mounted) setState(() => _reminder = draft);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                      ),
                      child: Text(l10n.setupEdit),
                    ),
                  ],
                ),
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
      ),
    );
  }
}
