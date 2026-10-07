/// Type-specific rules the app needs for *provisional* progress (A21, invariant 14). This is the
/// only place the app knows habit type keys. It never evaluates streaks, XP, levels or freezes:
/// the server owns those (invariant 9).
///
/// Values are integer units, matching the server: binary 0/1, quantity thousandths, duration
/// whole seconds. Wire values that are malformed parse to null instead of throwing.
abstract interface class ProvisionalTypeRules {
  String get key;

  /// Wire value to units, or null when malformed (floats are never accepted).
  int? parseValue(Object? wire);

  /// Wire target to units, or null when it breaks the type's target rule.
  int? parseTarget(Object? wire);

  Object formatValue(int units);

  /// Local optimistic increment. Null when the delta is malformed or not positive.
  int? increment(int current, Object? delta);

  bool isComplete(int value, int target);
}

/// Registry of the types this app version understands. Unknown types return null so callers
/// can preserve and display them as "update the app" cards (A21 tolerant reader).
class ProvisionalTypeRegistry {
  final Map<String, ProvisionalTypeRules> _rules;

  ProvisionalTypeRegistry(Iterable<ProvisionalTypeRules> rules)
    : _rules = {for (final r in rules) r.key: r};

  factory ProvisionalTypeRegistry.builtins() =>
      ProvisionalTypeRegistry(const [BinaryRules(), QuantityRules(), DurationRules()]);

  ProvisionalTypeRules? lookup(String key) => _rules[key];

  Iterable<String> get keys => _rules.keys;
}

class BinaryRules implements ProvisionalTypeRules {
  const BinaryRules();

  @override
  String get key => 'binary';

  @override
  int? parseValue(Object? wire) => (wire == 0 || wire == 1) ? wire as int : null;

  @override
  int? parseTarget(Object? wire) => wire == 1 ? 1 : null;

  @override
  Object formatValue(int units) => units;

  /// Binary habits are set, never incremented.
  @override
  int? increment(int current, Object? delta) => null;

  @override
  bool isComplete(int value, int target) => value >= 1;
}

class QuantityRules implements ProvisionalTypeRules {
  const QuantityRules();

  static const int maxUnits = 999999999999;
  static final RegExp _decimal = RegExp(r'^(0|[1-9]\d{0,8})(?:\.(\d{1,3}))?$');

  @override
  String get key => 'quantity';

  @override
  int? parseValue(Object? wire) {
    if (wire is! String) return null;
    final match = _decimal.firstMatch(wire);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = int.parse((match.group(2) ?? '').padRight(3, '0'));
    return whole * 1000 + fraction;
  }

  @override
  int? parseTarget(Object? wire) {
    final units = parseValue(wire);
    return units == null || units <= 0 ? null : units;
  }

  @override
  Object formatValue(int units) => '${units ~/ 1000}.${(units % 1000).toString().padLeft(3, '0')}';

  @override
  int? increment(int current, Object? delta) {
    final d = parseValue(delta);
    if (d == null || d <= 0 || current + d > maxUnits) return null;
    return current + d;
  }

  @override
  bool isComplete(int value, int target) => value >= target;
}

class DurationRules implements ProvisionalTypeRules {
  const DurationRules();

  /// Mirrors the server: one habit-day holds at most 25 hours.
  static const int maxSeconds = 25 * 3600;

  @override
  String get key => 'duration';

  @override
  int? parseValue(Object? wire) => (wire is int && wire >= 0 && wire <= maxSeconds) ? wire : null;

  @override
  int? parseTarget(Object? wire) {
    final seconds = parseValue(wire);
    return seconds == null || seconds <= 0 ? null : seconds;
  }

  @override
  Object formatValue(int units) => units;

  @override
  int? increment(int current, Object? delta) {
    final d = parseValue(delta);
    if (d == null || d <= 0 || current + d > maxSeconds) return null;
    return current + d;
  }

  @override
  bool isComplete(int value, int target) => value >= target;
}
