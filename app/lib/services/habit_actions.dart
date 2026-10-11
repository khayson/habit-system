import '../data/account_calendar.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../domain/calendar/local_date.dart';
import '../domain/habit_draft.dart';
import '../domain/provisional_type_rules.dart';

/// What the screens ask for, in domain terms. Pure Dart: every write goes through
/// [LocalMutationService] (A23) and then asks for a debounced sync. No type keys here: behaviour
/// comes from the type rules (invariant 14).
class HabitActions {
  final LocalMutationService writer;
  final ProvisionalTypeRegistry types;
  final void Function() onLocalWrite;
  final DateTime Function() _clock;

  HabitActions(
    this.writer, {
    required this.onLocalWrite,
    ProvisionalTypeRegistry? types,
    DateTime Function()? clock,
  }) : types = types ?? ProvisionalTypeRegistry.builtins(),
       _clock = clock ?? DateTime.now;

  /// One-tap check-in or undo for today. Refused for a habit-day that needs the user's decision
  /// first, so nothing queues behind it (Phase 2b.1 review §6).
  Future<void> toggle(TodayItem item) async {
    final rules = item.rules;
    if (rules == null || !item.canToggle) {
      throw StateError('This habit-day cannot be toggled.');
    }
    // I2: the target in force on the habit-day, not the latest definition's.
    final date = LocalDate.parse(item.log.date);
    final target =
        rules.parseTarget(
          item.habit.schedule.targetOn(date) ?? item.habit.payload['target_value'],
        ) ??
        1;
    await writer.setLogValue(
      habitId: item.habit.id,
      value: rules.formatValue(item.complete ? 0 : target),
    );
    onLocalWrite();
  }

  /// The minimal editor (2b.2): a one-tap habit, daily, starting today in the account calendar.
  /// A thin wrapper over [createHabit] (I1). With a reminder (08's Reminder row, 3.2b) both are
  /// written in one transaction.
  Future<String> createOneTapHabit({
    required String name,
    required String category,
    String? reminderTime,
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    bool reminderEnabled = true,
  }) {
    final rules = types.all.firstWhere((r) => r.oneTap);
    return createHabit(
      HabitDraft(
        name: name,
        category: category,
        targetValue: rules.formatValue(1),
        unit: null,
        frequencyType: 'daily',
        frequencyConfig: const {},
      ),
      type: rules.key,
      reminder: reminderTime == null
          ? null
          : NewReminder(
              localTime: reminderTime,
              daysOfWeek: reminderDays,
              enabled: reminderEnabled,
            ),
    );
  }

  /// Screen 08 (I1): a habit of [type] from [draft], with an optional first reminder, in one
  /// transaction, starting today in the account calendar. Throws HabitEditFailure.invalid with
  /// the problems, writing nothing.
  Future<String> createHabit(
    HabitDraft draft, {
    required String type,
    NewReminder? reminder,
  }) async {
    final calendar = await AccountCalendar.load(writer.db, deviceNow: _clock());
    if (calendar == null) throw StateError('The account calendar is not known yet.');
    final id = await writer.createHabit(
      draft,
      type: type,
      reminder: reminder,
      startLocalDate: calendar.today(_clock()),
      types: types,
    );
    onLocalWrite();
    return id;
  }

  /// Screen 13: a past check-in on [date] (date_mode backdate). Throws DayResolutionException
  /// for a date the server would refuse, writing nothing.
  Future<void> setValueOn({
    required String habitId,
    required LocalDate date,
    required Object value,
  }) async {
    final calendar = await AccountCalendar.load(writer.db, deviceNow: _clock());
    if (calendar == null) throw StateError('The account calendar is not known yet.');
    if (date == calendar.today(_clock())) {
      await writer.setLogValue(habitId: habitId, value: value);
    } else {
      await writer.setLogValue(habitId: habitId, value: value, logDate: date);
    }
    onLocalWrite();
  }

  /// Screen 11 live mode (3.2c): the first reminder of a habit that exists. It follows the
  /// device's local time, like 08's.
  Future<void> addReminder({
    required String habitId,
    required String localTime,
    required List<int> days,
    bool enabled = true,
  }) async {
    await writer.createReminder(
      habitId: habitId,
      localTime: localTime,
      daysOfWeek: days,
      timezoneMode: 'device_zone',
      enabled: enabled,
    );
    onLocalWrite();
  }

  /// The whole desired state (absolute); unsent edits coalesce in the writer.
  Future<void> editReminder({
    required String reminderId,
    required String localTime,
    required List<int> days,
    required bool enabled,
    required String timezoneMode,
    String? timezone,
  }) async {
    await writer.updateReminder(
      reminderId: reminderId,
      localTime: localTime,
      daysOfWeek: days,
      timezoneMode: timezoneMode,
      timezone: timezone,
      enabled: enabled,
    );
    onLocalWrite();
  }

  Future<void> removeReminder(String reminderId) async {
    await writer.deleteReminder(reminderId);
    onLocalWrite();
  }

  /// Screen 34 (4.3b): adds [delta] (wire form) to today. Throws LogFailure without writing.
  Future<LocalWrite> addAmount(String habitId, Object delta) async {
    final write = await writer.incrementLog(habitId: habitId, delta: delta, types: types);
    onLocalWrite();
    return write;
  }

  // Timers (A36, screens 33 / 36). Local drafts: nothing to sync until finish.
  Future<TimerDraftView> startTimer(String habitId) => writer.startTimer(habitId);
  Future<TimerDraftView> pauseTimer(String habitId) => writer.pauseTimer(habitId);
  Future<TimerDraftView> resumeTimer(String habitId) => writer.resumeTimer(habitId);
  Future<void> discardTimer(String habitId) => writer.discardTimer(habitId);
  Stream<TimerDraftView?> watchTimer(String habitId) => writer.watchTimer(habitId);

  /// Finishing writes the increment (A36): a sync is asked for when something was written.
  Future<LocalWrite?> finishTimer(String habitId) async {
    final write = await writer.finishTimer(habitId, types: types);
    if (write != null) onLocalWrite();
    return write;
  }

  /// A34: habit.update (screen 09, 4.2b). Throws HabitEditFailure without writing.
  Future<void> updateHabit(String habitId, HabitDraft draft) async {
    await writer.updateHabit(habitId, draft, types: types);
    onLocalWrite();
  }

  /// A34: habit.archive (screens 07 / 09, 4.2b).
  Future<void> archiveHabit(String habitId) async {
    await writer.archiveHabit(habitId);
    onLocalWrite();
  }

  /// A34: habit.restore (screen 22, 4.2b).
  Future<void> restoreHabit(String habitId) async {
    await writer.restoreHabit(habitId);
    onLocalWrite();
  }

  /// Screen 20: profile.update (A20).
  Future<void> updateProfile({
    required String name,
    required String? city,
    required String? countryCode,
  }) async {
    await writer.updateProfile(name: name, city: city, countryCode: countryCode);
    onLocalWrite();
  }

  /// Screen 04: profile.set_timezone (applies from the start of the next day, A26).
  Future<void> setTimezone(String zone) async {
    await writer.setTimezone(zone);
    onLocalWrite();
  }

  Future<bool> discard(String mutationId) async {
    final done = await writer.discard(mutationId);
    if (done) onLocalWrite();
    return done;
  }

  Future<bool> retryNow(String mutationId) async {
    final done = await writer.retryNow(mutationId);
    if (done) onLocalWrite();
    return done;
  }
}
