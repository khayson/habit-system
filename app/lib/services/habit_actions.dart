import '../data/account_calendar.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../domain/calendar/local_date.dart';
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
    final target = rules.parseTarget(item.habit.payload['target_value']) ?? 1;
    await writer.setLogValue(
      habitId: item.habit.id,
      value: rules.formatValue(item.complete ? 0 : target),
    );
    onLocalWrite();
  }

  /// The minimal editor (2b.2): a one-tap habit, daily, starting today in the account calendar.
  /// With a reminder (08's Reminder row, 3.2b) both are written in one transaction; the
  /// reminder follows the device's local time, as the design's row says.
  Future<String> createOneTapHabit({
    required String name,
    required String category,
    String? reminderTime,
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    bool reminderEnabled = true,
  }) async {
    final rules = types.all.firstWhere((r) => r.oneTap);
    final calendar = await AccountCalendar.load(writer.db, deviceNow: _clock());
    if (calendar == null) throw StateError('The account calendar is not known yet.');
    final id = await writer.db.transaction(() async {
      final habit = await writer.createHabit(
        name: name.trim(),
        type: rules.key,
        target: rules.formatValue(1),
        category: category,
        startLocalDate: calendar.today(_clock()),
      );
      if (reminderTime != null) {
        await writer.createReminder(
          habitId: habit,
          localTime: reminderTime,
          daysOfWeek: reminderDays,
          timezoneMode: 'device_zone',
          enabled: reminderEnabled,
        );
      }
      return habit;
    });
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
