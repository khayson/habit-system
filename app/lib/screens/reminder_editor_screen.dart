import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../data/reminder_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/notification_scheduler.dart';
import '../providers/account_context.dart';
import '../services/habit_actions.dart';
import '../widgets/habit_ui.dart';
import 'widgets/notice_banner.dart';

/// A reminder as 08 and 11 edit it: a clock time on chosen ISO days (1 = Monday).
class ReminderDraft {
  final int minuteOfDay;
  final List<int> days;
  final bool enabled;

  const ReminderDraft({
    this.minuteOfDay = 20 * 60 + 30,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
  });

  String get localTime =>
      '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay % 60).toString().padLeft(2, '0')}';

  static ReminderDraft fromView(ReminderView view) {
    final parts = view.localTime.split(':');
    return ReminderDraft(
      minuteOfDay: int.parse(parts[0]) * 60 + int.parse(parts[1]),
      days: view.daysOfWeek,
      enabled: view.enabled,
    );
  }

  ReminderDraft copyWith({int? minuteOfDay, List<int>? days, bool? enabled}) => ReminderDraft(
    minuteOfDay: minuteOfDay ?? this.minuteOfDay,
    days: days ?? this.days,
    enabled: enabled ?? this.enabled,
  );
}

/// Screen 11: the reminder editor and the denial state. Two modes:
/// - draft (08's Reminder row, a new habit): the draft is returned on save and written with
///   the habit;
/// - live (12's Reminder row, a habit that exists, 3.2c): adds, edits, turns off or removes the
///   habit's reminder through LocalMutationService (offline; the replan watch picks it up).
/// Notifications stay on this device; the OS prompt appears only when the user taps Allow, and
/// after a refusal the screen shows the device's truth with a way to Settings and when the next
/// reminder is due. Saving never prompts.
class ReminderEditorScreen extends StatefulWidget {
  final ReminderDraft? draft;
  final String? habitName;
  final DateTime Function() clock;

  /// Live mode: the habit whose reminders are edited, and optionally which one.
  final String? habitId;
  final String? reminderId;

  const ReminderEditorScreen({
    super.key,
    this.draft,
    this.habitName,
    this.habitId,
    this.reminderId,
    this.clock = DateTime.now,
  });

  bool get live => habitId != null;

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> with WidgetsBindingObserver {
  late ReminderDraft _draft = widget.draft ?? const ReminderDraft();
  NotificationPermission? _permission;
  String? _error;

  /// Live mode: the reminder being edited (null: adding the habit's first), the habit's other
  /// live reminders, and the habit's name.
  ReminderView? _editing;
  List<ReminderView> _others = const [];
  String? _liveName;
  bool _loaded = false;

  /// L1: a write is running; Save and Remove ignore taps until it finishes. S7: after a
  /// successful write it stays set while 11 leaves.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      if (widget.live) _loadLive();
    });
  }

  Future<void> _loadLive() async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    final mine = [
      for (final r in await account.view.reminders())
        if (r.habitId == widget.habitId) r,
    ];
    final habits = await account.view.habits();
    final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;
    final asked = mine.where((r) => r.id == widget.reminderId).firstOrNull;
    if (!mounted) return;
    // L2: a reminder that is gone (removed here or on another device) never falls back to
    // editing another one: back to the habit's 12.
    if (widget.reminderId != null && asked == null) {
      context.go(Routes.habit(widget.habitId!));
      return;
    }
    final editing = asked ?? mine.firstOrNull;
    setState(() {
      _editing = editing;
      _others = [
        for (final r in mine)
          if (r.id != editing?.id) r,
      ];
      _liveName = habit?.payload['name'] as String?;
      if (editing != null) _draft = ReminderDraft.fromView(editing);
      _loaded = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the device settings: show what the OS says now.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    final state = await account.permission.state();
    if (mounted) setState(() => _permission = state);
  }

  Future<void> _allow() async {
    final account = context.read<AccountContext?>()!;
    final state = await account.permission.allow();
    if (mounted) setState(() => _permission = state);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.minuteOfDay ~/ 60, minute: _draft.minuteOfDay % 60),
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(minuteOfDay: picked.hour * 60 + picked.minute));
    }
  }

  Future<void> _save() async {
    if (_draft.days.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).reminderNeedsDay);
      return;
    }
    if (!widget.live) {
      context.pop(_draft);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final actions = context.read<AccountContext?>()!.actions;
    final editing = _editing;
    try {
      await _write(actions, editing);
    } catch (_) {
      // S7: cleared only on failure; after a success 11 is leaving and stays disabled.
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (mounted) _leave();
  }

  Future<void> _write(HabitActions actions, ReminderView? editing) async {
    if (editing == null) {
      await actions.addReminder(
        habitId: widget.habitId!,
        localTime: _draft.localTime,
        days: _draft.days,
        enabled: _draft.enabled,
      );
    } else {
      await actions.editReminder(
        reminderId: editing.id,
        localTime: _draft.localTime,
        days: _draft.days,
        enabled: _draft.enabled,
        timezoneMode: editing.timezoneMode,
        timezone: editing.timezone,
      );
    }
  }

  Future<void> _remove() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AccountContext?>()!.actions.removeReminder(_editing!.id);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (mounted) _leave();
  }

  /// Live mode: back to where 11 was opened from, or to the habit's 12 (a deep link).
  void _leave() => context.canPop() ? context.pop() : context.go(Routes.habit(widget.habitId!));

  String _time(BuildContext context, int minuteOfDay) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.jm(locale).format(DateTime(2026, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60));
  }

  String _repeat(AppLocalizations l10n, String locale) {
    final days = [..._draft.days]..sort();
    if (days.length == 7) return l10n.reminderEveryDay;
    if (days.join(',') == '1,2,3,4,5') return l10n.reminderWeekdays;
    // 5 January 2026 was a Monday.
    return l10n.reminderOnDays(
      days.map((d) => DateFormat.E(locale).format(DateTime(2026, 1, 4 + d))).join(', '),
    );
  }

  /// The next time this reminder is due, on the device clock (the denial state's next-due view).
  String? _nextDue(String locale) {
    final now = widget.clock();
    for (var i = 0; i < 8; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!_draft.days.contains(day.weekday)) continue;
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        _draft.minuteOfDay ~/ 60,
        _draft.minuteOfDay % 60,
      );
      if (at.isAfter(now)) {
        return '${DateFormat.MMMEd(locale).format(at)} · ${DateFormat.jm(locale).format(at)}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final permission = _permission;
    final allowed =
        permission == NotificationPermission.authorized ||
        permission == NotificationPermission.provisional;
    final name = (widget.live ? _liveName ?? '' : widget.habitName ?? '').trim();
    final next = _nextDue(locale);
    if (widget.live && !_loaded) return const Scaffold(body: SafeArea(child: SizedBox()));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.reminderEditorTitle,
              subtitle: l10n.reminderEditorSubtitle(name.isEmpty ? l10n.reminderNewHabit : name),
              onBack: () => widget.live ? _leave() : context.pop(),
            ),
            if (permission == NotificationPermission.denied) ...[
              NoticeBanner(
                tone: Tone.warning,
                title: l10n.reminderDeniedTitle,
                body: l10n.reminderDeniedBody,
                extra: next == null ? null : l10n.reminderNext(next),
                action: l10n.reminderOpenDeviceSettings,
                onAction: () => context.read<AccountContext?>()!.permission.openSettings(),
              ),
              const SizedBox(height: HabitSpace.s24),
            ] else if (permission == NotificationPermission.unknown) ...[
              NoticeBanner(
                tone: Tone.info,
                title: l10n.reminderAskTitle,
                body: l10n.reminderAskBody,
                action: l10n.remindersAllow,
                onAction: _allow,
              ),
              const SizedBox(height: HabitSpace.s24),
            ],
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: HabitSpace.s32,
                horizontal: HabitSpace.s16,
              ),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(HabitRadius.r24),
              ),
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.reminderChooseTime(_time(context, _draft.minuteOfDay)),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(HabitRadius.r12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s8),
                        child: Text(
                          _time(context, _draft.minuteOfDay),
                          textAlign: TextAlign.center,
                          style: text.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: HabitSpace.s16),
                  Text(_repeat(l10n, locale), style: text.bodyLarge?.copyWith(color: tokens.muted)),
                  const SizedBox(height: HabitSpace.s8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _Day(
                          letter: DateFormat.EEEEE(locale).format(DateTime(2026, 1, 4 + d)),
                          name: DateFormat.EEEE(locale).format(DateTime(2026, 1, 4 + d)),
                          on: _draft.days.contains(d),
                          onTap: () => setState(() {
                            final days = {..._draft.days};
                            days.contains(d) ? days.remove(d) : days.add(d);
                            _draft = _draft.copyWith(days: days.toList()..sort());
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s24),
            SurfaceCard(
              child: Row(
                children: [
                  const ExcludeSemantics(child: IconTile(icon: Icons.notifications_none)),
                  const SizedBox(width: HabitSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.reminderEnabled, style: text.titleMedium),
                        const SizedBox(height: HabitSpace.s4),
                        Text(
                          allowed ? l10n.reminderOnThisDevice : l10n.reminderReadyWhenAllowed,
                          style: text.bodySmall?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _draft.enabled,
                    onChanged: (on) => setState(() => _draft = _draft.copyWith(enabled: on)),
                  ),
                ],
              ),
            ),
            if (_others.isNotEmpty) ...[
              const SizedBox(height: HabitSpace.s16),
              _OtherReminders(
                times: [
                  for (final r in _others) _time(context, ReminderDraft.fromView(r).minuteOfDay),
                ],
                onOpen: (i) => context.pushReplacement(
                  Routes.habitReminder(widget.habitId!, reminderId: _others[i].id),
                ),
              ),
            ],
            const SizedBox(height: HabitSpace.s32),
            Text(l10n.reminderNote, style: text.bodyMedium?.copyWith(color: tokens.muted)),
            if (_error != null) ...[
              const SizedBox(height: HabitSpace.s12),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: text.bodyMedium?.copyWith(color: tokens.errorInk)),
              ),
            ],
            const SizedBox(height: HabitSpace.s32),
            PrimaryButton(label: l10n.reminderSave, loading: _saving, onPressed: _save),
            if (widget.live && _editing != null) ...[
              const SizedBox(height: HabitSpace.s16),
              // ASSUMPTION(A3.2c-remove): the design shows no removal; a quiet text button, no
              // dialog, neutral wording.
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.muted,
                    minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                  ),
                  child: Text(l10n.reminderRemove),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The design's "Other reminders" card: the habit's other reminders as times, each opening in
/// this screen.
class _OtherReminders extends StatelessWidget {
  final List<String> times;
  final ValueChanged<int> onOpen;

  const _OtherReminders({required this.times, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Row(
        children: [
          const ExcludeSemantics(child: IconTile(icon: Icons.schedule)),
          const SizedBox(width: HabitSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reminderOther, style: text.titleMedium),
                Wrap(
                  children: [
                    for (var i = 0; i < times.length; i++)
                      TextButton(
                        onPressed: () => onOpen(i),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                          padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s8),
                        ),
                        child: Semantics(
                          label: l10n.reminderEditAt(times[i]),
                          excludeSemantics: true,
                          child: Text(times[i]),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final String letter;
  final String name;
  final bool on;
  final VoidCallback onTap;

  const _Day({required this.letter, required this.name, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      toggled: on,
      label: l10n.reminderDayLabel(name, on ? l10n.reminderDayOn : l10n.reminderDayOff),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: HabitSize.minTarget,
          child: Center(
            child: Text(
              letter,
              style: text.titleMedium?.copyWith(
                color: on ? tokens.primary : tokens.muted,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                decoration: on ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
