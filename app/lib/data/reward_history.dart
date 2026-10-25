import '../domain/calendar/local_date.dart';
import '../domain/habit_schedule.dart';
import '../domain/provisional_type_rules.dart';
import '../models/reward_pages.dart';
import 'account_calendar.dart';
import 'local_view.dart';

/// Which word a history row's date takes (screens 16 and 17).
enum DayWord { today, yesterday, date }

/// What an XP ledger row says (A40). Unknown reasons read as a neutral update (invariant 13).
enum XpRowKind { completion, changed, unknown }

/// One row of screen 16's Recent XP, worked out from the ledger and local data only. Nothing
/// here computes XP: [delta] is exactly the server's.
class XpRow {
  final String id;

  /// Null when the habit is not on this device ("A habit").
  final String? habitName;

  /// A53: the habit's icon key and category (its row shows the habit's own icon).
  final String? habitIcon;
  final String? habitCategory;
  final ProvisionalTypeRules? rules;
  final LocalDate? date;
  final DayWord dayWord;
  final XpRowKind kind;
  final int delta;

  /// The day's value and unit when its local log exists and meets the target; the screen
  /// formats them through the type rules (invariant 14).
  final Object? completedValue;
  final String? unit;

  const XpRow({
    required this.id,
    required this.habitName,
    this.habitIcon,
    this.habitCategory,
    required this.rules,
    required this.date,
    required this.dayWord,
    required this.kind,
    required this.delta,
    required this.completedValue,
    required this.unit,
  });

  bool get completedLocally => completedValue != null;
}

/// What a freeze ledger row says (A41). Unknown kinds or reasons read as a neutral update.
enum FreezeRowKind { spend, refund, refundAtCap, signupGrant, monthlyGrant, alreadyFull, unknown }

/// The period a spend or refund protected: d: is a day, w: a week, anything else a period.
enum PeriodWord { daily, weekly, other }

class FreezeRow {
  final String id;
  final FreezeRowKind kind;
  final int delta;
  final String? habitName;

  /// The protected period's first date (spend and refund), else the row's local date.
  final LocalDate? date;
  final PeriodWord period;

  const FreezeRow({
    required this.id,
    required this.kind,
    required this.delta,
    required this.habitName,
    required this.date,
    required this.period,
  });

  /// Rows about one habit's period, titled "{habit} · {date}".
  bool get aboutHabit =>
      kind == FreezeRowKind.spend ||
      kind == FreezeRowKind.refund ||
      kind == FreezeRowKind.refundAtCap;
}

/// Pure Dart (A23): turns ledger pages into rows with local habit names and day words. Reads
/// the local database only and never writes it.
class RewardHistory {
  final LocalView view;

  const RewardHistory(this.view);

  Future<List<XpRow>> xpRows(List<XpLedgerEntry> entries, DateTime deviceNow) async {
    final calendar = await AccountCalendar.load(view.db, deviceNow: deviceNow);
    final today = calendar?.today(deviceNow);
    final habits = {for (final h in await view.habits(deviceNow: deviceNow)) h.id: h};
    return [
      for (final e in entries)
        await () async {
          final habit = habits[e.habitId];
          final rules = view.types.lookup(habit?.payload['type'] as String? ?? '');
          final date = _date(e.logDate);
          final kind = switch (e.reason) {
            'completion' || 'recompletion' => XpRowKind.completion,
            'reversal' => XpRowKind.changed,
            _ => XpRowKind.unknown,
          };
          Object? completed;
          if (kind == XpRowKind.completion && habit != null && rules != null && date != null) {
            final log = await view.log(e.habitId, e.logDate);
            final target =
                HabitSchedule.fromWire(habit.payload).targetOn(date) ??
                habit.payload['target_value'];
            final v = rules.parseValue(log.value);
            final t = rules.parseTarget(target);
            if (!log.deleted && v != null && t != null && rules.isComplete(v, t)) {
              completed = log.value;
            }
          }
          return XpRow(
            id: e.id,
            habitName: habit?.payload['name'] as String?,
            habitIcon: habit?.icon,
            habitCategory: habit?.category,
            rules: rules,
            date: date,
            dayWord: _dayWord(date, today),
            kind: kind,
            delta: e.delta,
            completedValue: completed,
            unit: habit?.payload['unit'] as String?,
          );
        }(),
    ];
  }

  Future<List<FreezeRow>> freezeRows(List<FreezeLedgerEntry> entries, DateTime deviceNow) async {
    final calendar = await AccountCalendar.load(view.db, deviceNow: deviceNow);
    final names = {
      for (final h in await view.habits(deviceNow: deviceNow)) h.id: h.payload['name'] as String?,
    };
    return [
      for (final e in entries)
        () {
          final kind = switch ((e.kind, e.reason)) {
            ('spend', _) => FreezeRowKind.spend,
            ('refund', 'cap_reached') => FreezeRowKind.refundAtCap,
            ('refund', _) => FreezeRowKind.refund,
            ('grant', 'signup') => FreezeRowKind.signupGrant,
            ('grant', 'monthly') => FreezeRowKind.monthlyGrant,
            ('grant', 'cap_reached') => FreezeRowKind.alreadyFull,
            _ => FreezeRowKind.unknown,
          };
          final key = e.periodKey;
          final period = key == null
              ? PeriodWord.other
              : key.startsWith('d:')
              ? PeriodWord.daily
              : key.startsWith('w:')
              ? PeriodWord.weekly
              : PeriodWord.other;
          final periodDate = key != null && key.length > 2 ? _date(key.substring(2)) : null;
          return FreezeRow(
            id: e.id,
            kind: kind,
            delta: e.delta,
            habitName: e.habitId == null ? null : names[e.habitId],
            date: periodDate ?? calendar?.timeline.localDateAt(e.createdAt),
            period: period,
          );
        }(),
    ];
  }

  /// A wire date, or null for anything this app cannot read (invariant 13).
  static LocalDate? _date(String value) {
    try {
      return LocalDate.parse(value);
    } on Object {
      return null;
    }
  }

  static DayWord _dayWord(LocalDate? date, LocalDate? today) {
    if (date == null || today == null) return DayWord.date;
    if (date == today) return DayWord.today;
    if (date == today.addDays(-1)) return DayWord.yesterday;
    return DayWord.date;
  }
}
