import '../data/account_calendar.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
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
  Future<String> createOneTapHabit({required String name, required String category}) async {
    final rules = types.all.firstWhere((r) => r.oneTap);
    final calendar = await AccountCalendar.load(writer.db, deviceNow: _clock());
    if (calendar == null) throw StateError('The account calendar is not known yet.');
    final id = await writer.createHabit(
      name: name.trim(),
      type: rules.key,
      target: rules.formatValue(1),
      category: category,
      startLocalDate: calendar.today(_clock()),
    );
    onLocalWrite();
    return id;
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
