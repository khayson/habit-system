/// A business date (`DATE`): a calendar day with no time and no zone, stored as days since
/// 1970-01-01 so arithmetic never touches time zones or DST. Mirrors the PHP `LocalDate`.
class LocalDate implements Comparable<LocalDate> {
  final int epochDay;

  const LocalDate.fromEpochDay(this.epochDay);

  static final RegExp _format = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  factory LocalDate.parse(String value) {
    final m = _format.firstMatch(value);
    if (m == null) throw FormatException('Invalid local date: $value');
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    final utc = DateTime.utc(y, mo, d);
    if (utc.year != y || utc.month != mo || utc.day != d) {
      throw FormatException('Invalid local date: $value');
    }
    return LocalDate.fromEpochDay(utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay);
  }

  /// The calendar date of a UTC wall-clock reading (milliseconds since the epoch, no zone).
  factory LocalDate.ofWallClockMillis(int wallMillis) =>
      LocalDate.fromEpochDay((wallMillis / Duration.millisecondsPerDay).floor());

  DateTime get _utcMidnight =>
      DateTime.fromMillisecondsSinceEpoch(epochDay * Duration.millisecondsPerDay, isUtc: true);

  /// Wall-clock midnight of this date as milliseconds (no zone applied).
  int get midnightMillis => epochDay * Duration.millisecondsPerDay;

  LocalDate addDays(int days) => LocalDate.fromEpochDay(epochDay + days);

  /// 1 = Monday … 7 = Sunday.
  int get isoWeekday => _utcMidnight.weekday;

  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  bool isBefore(LocalDate other) => epochDay < other.epochDay;
  bool isAfter(LocalDate other) => epochDay > other.epochDay;

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) => other is LocalDate && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() {
    final d = _utcMidnight;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }
}
