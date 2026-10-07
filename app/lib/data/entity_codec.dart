import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Maps server entity payloads to confirmed rows and back. Known fields go to columns; anything
/// else is kept verbatim in `extra` and re-emitted untouched (invariant 13). Pure Dart.
abstract final class EntityCodec {
  static const habitFields = {
    'id', 'name', 'type', 'unit', 'category', 'target_value', 'frequency_type', //
    'frequency_config', 'start_local_date', 'archived_at', 'version', 'definition_version',
    'definitions', 'active_ranges',
  };

  static const logFields = {
    'id', 'habit_id', 'log_date', 'value', 'detail', 'occurred_at', 'completed_at', //
    'resolved_timezone', 'day_start_offset_minutes', 'definition_version', 'version', 'deleted_at',
  };

  static HabitsCompanion habitRow(
    Map<String, dynamic> p, {
    required String id,
    required int version,
  }) {
    return HabitsCompanion(
      id: Value(id),
      name: Value(_str(p['name'])),
      type: Value(_str(p['type'])),
      unit: Value(_str(p['unit'])),
      category: Value(_str(p['category'])),
      targetValue: Value(_json(p, 'target_value')),
      frequencyType: Value(_str(p['frequency_type'])),
      frequencyConfig: Value(_json(p, 'frequency_config')),
      startLocalDate: Value(_str(p['start_local_date'])),
      archivedAt: Value(_str(p['archived_at'])),
      version: Value(version),
      definitionVersion: Value(_int(p['definition_version'])),
      definitions: Value(_json(p, 'definitions')),
      activeRanges: Value(_json(p, 'active_ranges')),
      extra: Value(_extra(p, habitFields)),
    );
  }

  static HabitLogsCompanion logRow(
    Map<String, dynamic> p, {
    required String id,
    required int version,
  }) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: Value(_str(p['habit_id'])),
      logDate: Value(_str(p['log_date'])),
      value: Value(_json(p, 'value')),
      detail: Value(_json(p, 'detail')),
      occurredAt: Value(_str(p['occurred_at'])),
      completedAt: Value(_str(p['completed_at'])),
      resolvedTimezone: Value(_str(p['resolved_timezone'])),
      dayStartOffsetMinutes: Value(_int(p['day_start_offset_minutes'])),
      definitionVersion: Value(_int(p['definition_version'])),
      version: Value(version),
      deletedAt: Value(_str(p['deleted_at'])),
      extra: Value(_extra(p, logFields)),
    );
  }

  /// The entity as the server described it: known fields plus the preserved unknown ones.
  static Map<String, dynamic> habitPayload(ConfirmedHabit r) => {
    ..._decodeMap(r.extra),
    'id': r.id,
    'name': r.name,
    'type': r.type,
    'unit': r.unit,
    'category': r.category,
    'target_value': _decode(r.targetValue),
    'frequency_type': r.frequencyType,
    'frequency_config': _decode(r.frequencyConfig),
    'start_local_date': r.startLocalDate,
    'archived_at': r.archivedAt,
    'version': r.version,
    'definition_version': r.definitionVersion,
    'definitions': _decode(r.definitions),
    'active_ranges': _decode(r.activeRanges),
  };

  static Map<String, dynamic> logPayload(ConfirmedLog r) => {
    ..._decodeMap(r.extra),
    'id': r.id,
    'habit_id': r.habitId,
    'log_date': r.logDate,
    'value': _decode(r.value),
    'detail': _decode(r.detail),
    'occurred_at': r.occurredAt,
    'completed_at': r.completedAt,
    'resolved_timezone': r.resolvedTimezone,
    'day_start_offset_minutes': r.dayStartOffsetMinutes,
    'definition_version': r.definitionVersion,
    'version': r.version,
    'deleted_at': r.deletedAt,
  };

  static Object? decodeJson(String? text) => _decode(text);

  static String? _str(Object? v) => v is String ? v : null;
  static int? _int(Object? v) => v is int ? v : null;
  static String? _json(Map<String, dynamic> p, String key) =>
      p.containsKey(key) ? jsonEncode(p[key]) : null;
  static Object? _decode(String? text) => text == null ? null : jsonDecode(text);
  static Map<String, dynamic> _decodeMap(String text) =>
      (jsonDecode(text) as Map).cast<String, dynamic>();

  static String _extra(Map<String, dynamic> p, Set<String> known) => jsonEncode({
    for (final e in p.entries)
      if (!known.contains(e.key)) e.key: e.value,
  });
}
