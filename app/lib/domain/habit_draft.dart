import 'provisional_type_rules.dart';

/// A34: the editable state of a habit, as habit.update sends it (the six keys, never `type`).
/// Pure Dart: the edit form (4.2b) and LocalMutationService validate through [problems], so a
/// change the server would refuse is never queued.
class HabitDraft {
  final String name;
  final String category;
  final Object? targetValue;
  final String? unit;
  final String frequencyType;
  final Map<String, dynamic> frequencyConfig;

  const HabitDraft({
    required this.name,
    required this.category,
    required this.targetValue,
    required this.unit,
    required this.frequencyType,
    required this.frequencyConfig,
  });

  /// The editable fields of a habit entity or a queued payload (wire form).
  factory HabitDraft.fromWire(Map<String, dynamic> p) => HabitDraft(
    name: p['name'] as String? ?? '',
    category: p['category'] as String? ?? '',
    targetValue: p['target_value'],
    unit: p['unit'] as String?,
    frequencyType: p['frequency_type'] as String? ?? '',
    frequencyConfig: p['frequency_config'] is Map
        ? (p['frequency_config'] as Map).cast<String, dynamic>()
        : const {},
  );

  static const categories = ['health', 'mindfulness', 'learning', 'productivity', 'other'];
  static const nameMax = 100;
  static const unitMax = 24;

  /// The habit.update payload: all six keys, trimmed, never `type`.
  Map<String, Object?> toPayload() => {
    'name': name.trim(),
    'category': category,
    'target_value': targetValue,
    'unit': unit == null || unit!.trim().isEmpty ? null : unit!.trim(),
    'frequency_type': frequencyType,
    // The server stores weekdays sorted; so does the payload, so equal states compare equal.
    'frequency_config': frequencyType == 'weekdays' && frequencyConfig['days'] is List
        ? {
            ...frequencyConfig,
            'days': [...(frequencyConfig['days'] as List).whereType<int>()]..sort(),
          }
        : frequencyConfig,
  };

  /// Same editable state as [other], as the server would compare it (A34 identical update).
  bool sameAs(HabitDraft other, ProvisionalTypeRules? rules) {
    final a = toPayload();
    final b = other.toPayload();
    final targetsEqual = rules == null
        ? '${a['target_value']}' == '${b['target_value']}'
        : rules.parseTarget(a['target_value']) == rules.parseTarget(b['target_value']);
    return a['name'] == b['name'] &&
        a['category'] == b['category'] &&
        targetsEqual &&
        a['unit'] == b['unit'] &&
        a['frequency_type'] == b['frequency_type'] &&
        _sameConfig(
          a['frequency_config'] as Map<dynamic, dynamic>,
          b['frequency_config'] as Map<dynamic, dynamic>,
        );
  }

  /// What the server would refuse, by field; empty when the draft is valid. [rules] is the
  /// habit's type (null for a type this app does not know: nothing can be validated).
  List<HabitDraftProblem> problems(ProvisionalTypeRules? rules) {
    final out = <HabitDraftProblem>[];
    final trimmed = name.trim();
    if (trimmed.isEmpty) out.add(HabitDraftProblem.nameRequired);
    if (trimmed.length > nameMax) out.add(HabitDraftProblem.nameTooLong);
    if (!categories.contains(category)) out.add(HabitDraftProblem.category);
    if (rules == null) {
      out.add(HabitDraftProblem.unknownType);
      return out;
    }
    if (rules.parseTarget(targetValue) == null) out.add(HabitDraftProblem.target);
    final u = unit?.trim() ?? '';
    if (rules.takesUnit) {
      if (u.isEmpty) out.add(HabitDraftProblem.unitRequired);
      if (u.length > unitMax) out.add(HabitDraftProblem.unitTooLong);
    } else if (u.isNotEmpty) {
      out.add(HabitDraftProblem.unitNotAllowed);
    }
    final frequency = _frequencyProblem();
    if (frequency != null) out.add(frequency);
    return out;
  }

  HabitDraftProblem? _frequencyProblem() {
    final c = frequencyConfig;
    switch (frequencyType) {
      case 'daily':
        return null;
      case 'weekdays':
        final days = c['days'];
        if (days is! List || days.isEmpty) return HabitDraftProblem.weekdays;
        final ints = days.whereType<int>().toList();
        final valid =
            ints.length == days.length &&
            ints.every((d) => d >= 1 && d <= 7) &&
            ints.toSet().length == ints.length;
        return valid ? null : HabitDraftProblem.weekdays;
      case 'weekly_count':
        final count = c['count'];
        return count is int && count >= 1 && count <= 7 ? null : HabitDraftProblem.weeklyCount;
      case 'interval':
        final every = c['every_n_days'];
        final anchor = c['anchor_date'];
        final anchorValid =
            anchor is String &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(anchor) &&
            DateTime.tryParse(anchor) != null;
        if (every is! int || every < 1 || every > 365) return HabitDraftProblem.interval;
        return anchorValid ? null : HabitDraftProblem.intervalAnchor;
      default:
        return HabitDraftProblem.frequencyType;
    }
  }

  static bool _sameConfig(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final x = a[key];
      final y = b[key];
      if (x is List && y is List) {
        if (x.length != y.length) return false;
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return false;
        }
      } else if (x != y) {
        return false;
      }
    }
    return true;
  }
}

enum HabitDraftProblem {
  nameRequired,
  nameTooLong,
  category,
  unknownType,
  target,
  unitRequired,
  unitTooLong,
  unitNotAllowed,
  frequencyType,
  weekdays,
  weeklyCount,
  interval,
  intervalAnchor,
}
