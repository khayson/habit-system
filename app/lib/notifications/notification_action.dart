import '../data/app_database.dart';
import '../data/local_mutation_service.dart';
import '../domain/calendar/local_date.dart';

/// A23 notification action: `log:{habit_id}:{operation}:{value}` plus the slot it belongs to
/// (local date + reminder id), e.g. `log:0197…:log.set_value:1|slot:2026-05-28:0197…`.
/// Pure Dart; Phase 3.2b ships the schema and its handler, the action buttons come in Phase 5.
class NotificationAction {
  static const operations = {'log.set_value'};

  final String habitId;
  final String operation;

  /// The wire value: an int, or a decimal string for quantities ("0.250").
  final Object value;
  final LocalDate slotDate;
  final String reminderId;

  const NotificationAction({
    required this.habitId,
    required this.operation,
    required this.value,
    required this.slotDate,
    required this.reminderId,
  });

  String build() => 'log:$habitId:$operation:$value|slot:$slotDate:$reminderId';

  static final _id = RegExp(r'^[0-9A-Za-z-]{1,64}$');
  static final _int = RegExp(r'^\d{1,12}$');
  static final _decimal = RegExp(r'^\d{1,12}\.\d{1,3}$');

  /// Null for anything that is not exactly the schema (unknown operation, malformed id, value
  /// or date): a stale or foreign payload is ignored, never guessed at.
  static NotificationAction? parse(String? payload) {
    if (payload == null) return null;
    final halves = payload.split('|');
    if (halves.length != 2) return null;
    final log = halves[0].split(':');
    final slot = halves[1].split(':');
    if (log.length != 4 || log[0] != 'log' || slot.length != 3 || slot[0] != 'slot') return null;
    final (habitId, operation, rawValue) = (log[1], log[2], log[3]);
    if (!_id.hasMatch(habitId) || !operations.contains(operation)) return null;
    final Object value;
    if (_int.hasMatch(rawValue)) {
      value = int.parse(rawValue);
    } else if (_decimal.hasMatch(rawValue)) {
      value = rawValue;
    } else {
      return null;
    }
    final LocalDate date;
    try {
      date = LocalDate.parse(slot[1]);
    } on FormatException {
      return null;
    }
    if (!_id.hasMatch(slot[2])) return null;
    return NotificationAction(
      habitId: habitId,
      operation: operation,
      value: value,
      slotDate: date,
      reminderId: slot[2],
    );
  }

  String get _doneKey => 'notification_action:$reminderId:$slotDate';

  /// Applies the action once per slot through [LocalMutationService] (outbox first). A second
  /// tap, a retried callback or another isolate finds the slot recorded and writes nothing.
  /// Returns whether it wrote.
  Future<bool> apply(LocalMutationService writer) {
    final db = writer.db;
    return db.transaction(() async {
      final done = await (db.select(
        db.localSettings,
      )..where((s) => s.key.equals(_doneKey))).getSingleOrNull();
      if (done != null) return false;
      await writer.setLogValue(habitId: habitId, value: value, logDate: slotDate);
      await db
          .into(db.localSettings)
          .insert(LocalSettingsCompanion.insert(key: _doneKey, value: '1'));
      return true;
    });
  }
}
