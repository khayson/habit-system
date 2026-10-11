import 'calendar/local_date.dart';

/// Screen 10's result: a habit's frequency_type and frequency_config, in wire form (spec 05).
/// Weekdays are ISO (1 = Monday .. 7 = Sunday), always sorted.
class FrequencyChoice {
  final String type;
  final Map<String, dynamic> config;

  const FrequencyChoice(this.type, this.config);

  static const daily = FrequencyChoice(dailyType, <String, dynamic>{});

  static const dailyType = 'daily';
  static const weekdaysType = 'weekdays';
  static const weeklyCountType = 'weekly_count';
  static const intervalType = 'interval';
  static const knownTypes = [dailyType, weekdaysType, weeklyCountType, intervalType];

  factory FrequencyChoice.weekdays(Iterable<int> days) =>
      FrequencyChoice(weekdaysType, {'days': days.toSet().toList()..sort()});

  factory FrequencyChoice.weeklyCount(int count) =>
      FrequencyChoice(weeklyCountType, {'count': count});

  factory FrequencyChoice.interval(int everyNDays, LocalDate anchor) =>
      FrequencyChoice(intervalType, {'every_n_days': everyNDays, 'anchor_date': anchor.toString()});

  bool get known => knownTypes.contains(type);

  List<int> get days => config['days'] is List
      ? ((config['days'] as List).whereType<int>().toSet().toList()..sort())
      : const [];

  int? get count => config['count'] as int?;

  int? get everyNDays => config['every_n_days'] as int?;

  LocalDate? get anchor {
    final a = config['anchor_date'];
    if (a is! String) return null;
    try {
      return LocalDate.parse(a);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FrequencyChoice && other.type == type && _sameConfig(other.config, config);

  @override
  int get hashCode => Object.hash(type, config.length);

  static bool _sameConfig(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final x = a[key];
      final y = b[key];
      if (x is List && y is List) {
        if (x.join(',') != y.join(',')) return false;
      } else if (x != y) {
        return false;
      }
    }
    return true;
  }
}
