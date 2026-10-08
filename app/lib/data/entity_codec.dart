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

  static const progressFields = {'habit_id', 'current', 'longest', 'unit', 'computed_through'};

  static const evaluationFields = {
    'id', 'habit_id', 'period_key', 'start_date', 'end_date', 'completed', 'protected', //
    'definition_version', 'timezone', 'revision',
  };

  /// A32 habit_progress. Decoding a wrong-typed known field throws (the item is then kept raw).
  static HabitProgressCompanion progressRow(
    Map<String, dynamic> p, {
    required String habitId,
    required int version,
  }) {
    return HabitProgressCompanion(
      habitId: Value(habitId),
      current: Value(_strictInt(p['current'])),
      longest: Value(_strictInt(p['longest'])),
      unit: Value(_str(p['unit'])),
      computedThrough: Value(_str(p['computed_through'])),
      version: Value(version),
      extra: Value(_extra(p, progressFields)),
    );
  }

  /// A32 period_evaluation (version = revision).
  static PeriodEvaluationsCompanion evaluationRow(
    Map<String, dynamic> p, {
    required String id,
    required int version,
  }) {
    return PeriodEvaluationsCompanion(
      id: Value(id),
      habitId: Value(_str(p['habit_id'])),
      periodKey: Value(_str(p['period_key'])),
      startDate: Value(_str(p['start_date'])),
      endDate: Value(_str(p['end_date'])),
      completed: Value(_strictBool(p['completed'])),
      protected: Value(_strictBool(p['protected'])),
      definitionVersion: Value(_int(p['definition_version'])),
      timezone: Value(_str(p['timezone'])),
      revision: Value(version),
      extra: Value(_extra(p, evaluationFields)),
    );
  }

  static const reminderFields = {
    'id', 'habit_id', 'local_time', 'days_of_week', 'timezone_mode', 'timezone', 'enabled', //
    'version', 'deleted_at',
  };

  /// Phase 3.2b reminder. Wrong-typed known fields throw (the item is then kept raw).
  static RemindersCompanion reminderRow(
    Map<String, dynamic> p, {
    required String id,
    required int version,
  }) {
    final days = p['days_of_week'];
    return RemindersCompanion(
      id: Value(id),
      habitId: Value(_str(p['habit_id'])),
      localTime: Value(_str(p['local_time'])),
      daysOfWeek: Value(days == null ? null : jsonEncode([for (final d in days as List) d as int])),
      timezoneMode: Value(_str(p['timezone_mode'])),
      timezone: Value(_str(p['timezone'])),
      enabled: Value(_strictBool(p['enabled'])),
      version: Value(version),
      deletedAt: Value(_str(p['deleted_at'])),
      extra: Value(_extra(p, reminderFields)),
    );
  }

  static Map<String, dynamic> reminderPayload(ConfirmedReminder r) => {
    ..._decodeMap(r.extra),
    'id': r.id,
    'habit_id': r.habitId,
    'local_time': r.localTime,
    'days_of_week': _decode(r.daysOfWeek),
    'timezone_mode': r.timezoneMode,
    'timezone': r.timezone,
    'enabled': r.enabled,
    'version': r.version,
    'deleted_at': r.deletedAt,
  };

  static Map<String, dynamic> progressPayload(ConfirmedProgress r) => {
    ..._decodeMap(r.extra),
    'habit_id': r.habitId,
    'current': r.current,
    'longest': r.longest,
    'unit': r.unit,
    'computed_through': r.computedThrough,
  };

  static Map<String, dynamic> evaluationPayload(ConfirmedEvaluation r) => {
    ..._decodeMap(r.extra),
    'id': r.id,
    'habit_id': r.habitId,
    'period_key': r.periodKey,
    'start_date': r.startDate,
    'end_date': r.endDate,
    'completed': r.completed,
    'protected': r.protected,
    'definition_version': r.definitionVersion,
    'timezone': r.timezone,
    'revision': r.revision,
  };

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

  /// Null stays null; any other non-int is a decode error (F2 keeps the item raw).
  static int? _strictInt(Object? v) => v == null ? null : v as int;
  static bool? _strictBool(Object? v) => v == null ? null : v as bool;
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
