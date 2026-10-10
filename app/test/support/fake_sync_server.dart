import 'dart:async';
import 'dart:convert';

import 'package:habit/sync/sync_transport.dart';

/// A scriptable in-memory server implementing the /sync rules the engine depends on (spec 07,
/// A29): receipts with payload hashes, version checks, restore on the tombstone version, merged
/// ids, natural-key deletes, dependency_pending, a per-user journal and bootstrap pages.
/// Failure hooks script 401/410/413/429/5xx, per-mutation server_error and crash-after-commit.
class FakeSyncServer implements SyncTransport {
  FakeSyncServer({
    this.timezone = 'America/Los_Angeles',
    this.knownTypes = const {'binary', 'quantity', 'duration'},
    this.clock,
  });

  /// When set, answers carry `server_time` and events more than 5 minutes ahead of it are
  /// refused as `future_event`, like the real API.
  final DateTime Function()? clock;

  final String timezone;
  final Set<String> knownTypes;

  final Map<String, Map<String, dynamic>> habits = {};
  final Map<String, Map<String, dynamic>> logs = {};
  final Map<String, Map<String, dynamic>> reminders = {};
  final Map<String, ({String hash, Map<String, dynamic> ack})> receipts = {};
  final List<Map<String, dynamic>> journal = [];

  // Scripting.
  final List<SyncTransportException> failNextSync = [];
  final List<SyncTransportException> failNextBootstrap = [];
  final Set<String> serverErrorFor = {};
  bool crashAfterCommit = false;
  int? maxMutationsPerRequest;
  int expiredBelowSeq = 0;
  Completer<void>? gate;
  final List<Map<String, dynamic>> extraBootstrapHabits = [];
  final Map<String, List<Map<String, dynamic>>> extraBootstrapCollections = {};
  final List<Map<String, dynamic>> extraBootstrapEntities = [];
  final List<Map<String, dynamic>> extraChanges = [];

  // Observation.
  int syncCalls = 0;
  int bootstrapCalls = 0;
  final List<List<String>> sentMutationIds = [];

  int get seq => journal.length;

  /// The user entity version; profile.set_timezone bumps it (and so can a test, as another
  /// device would).
  int userVersion = 1;

  /// A pending zone change from profile.set_timezone, effective at [pendingAt].
  String? pendingZone;

  /// The start of the next local day in the fixed test calendar (28 May 2026, Los Angeles).
  static const pendingAt = '2026-05-29T07:00:00Z';

  /// False to act as a server before 3.2 (no calendar_history on the user).
  bool sendCalendarHistory = true;

  /// Phase 3b profile (profile.update) and photo state (the avatar endpoints bump these).
  String name = 'Maya';
  String? city;
  String? countryCode;
  int avatarVersion = 0;
  bool hasAvatar = false;

  /// False to act as a server before 3b (no profile or photo fields on the user).
  bool sendProfileFields = true;

  Map<String, dynamic> get user => {
    'id': 'user-1',
    'name': name,
    'email': 'maya@example.com',
    'timezone': timezone,
    'day_start_offset_minutes': 0,
    'xp': 0,
    'version': userVersion,
    if (sendProfileFields) ...{
      'city': city,
      'country_code': countryCode,
      'avatar_version': avatarVersion,
      'has_avatar': hasAvatar,
    },
    if (sendCalendarHistory)
      'calendar_history': [
        {
          'effective_at': '2026-01-01T00:00:00Z',
          'timezone': timezone,
          'day_start_offset_minutes': 0,
        },
        if (pendingZone != null)
          {'effective_at': pendingAt, 'timezone': pendingZone, 'day_start_offset_minutes': 0},
      ],
  };

  /// Another device changed the profile: the version this device holds is now stale.
  void bumpUserVersion() {
    userVersion++;
    _journal('user', 'user-1', 'upsert', userVersion, user);
  }

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    syncCalls++;
    if (gate != null) await gate!.future;
    if (failNextSync.isNotEmpty) throw failNextSync.removeAt(0);
    if (maxMutationsPerRequest != null && mutations.length > maxMutationsPerRequest!) {
      throw const SyncTransportException(SyncFailure.payloadTooLarge);
    }
    final after = _seqOf(cursor);
    sentMutationIds.add([for (final m in mutations) m['mutation_id'] as String]);

    final acks = [for (final m in mutations) _future(m) ?? apply(_deepCopy(m))];
    if (crashAfterCommit) {
      crashAfterCommit = false;
      throw const SyncTransportException(SyncFailure.network);
    }
    return _pull(after, pullLimit, acks);
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) async {
    bootstrapCalls++;
    if (failNextBootstrap.isNotEmpty) throw failNextBootstrap.removeAt(0);
    if (cursor == null) {
      return BootstrapPage(
        serverTime: clock?.call(),
        user: user,
        habits: [...habits.values, ...extraBootstrapHabits],
        hasMore: true,
        nextCursor: 'b:$seq',
        entities: extraBootstrapEntities,
        unknownCollections: extraBootstrapCollections,
      );
    }
    final snapshot = int.parse(cursor.substring(2));
    return BootstrapPage(
      serverTime: clock?.call(),
      logs: logs.values.toList(),
      hasMore: false,
      syncCursor: 'c:$snapshot',
    );
  }

  /// The real API refuses events more than 5 minutes ahead of its clock (DayResolver).
  Map<String, dynamic>? _future(Map<String, Object?> m) {
    final now = clock?.call();
    final at = DateTime.tryParse(m['occurred_at'] as String? ?? '');
    if (now == null || at == null || !at.isAfter(now.add(const Duration(minutes: 5)))) {
      return null;
    }
    return _failed(_deepCopy(m), 'rejected', {'code': 'future_event', 'message': 'x'});
  }

  /// Applies one mutation exactly as the server would (also used to act as another device).
  Map<String, dynamic> apply(Map<String, dynamic> m) {
    final id = m['mutation_id'] as String;
    final hash = jsonEncode(_canonical(m));
    final receipt = receipts[id];
    if (receipt != null) {
      if (receipt.hash != hash) {
        return _failed(m, 'rejected', {'code': 'idempotency_mismatch', 'message': 'x'});
      }
      return {...receipt.ack, 'duplicate': true};
    }
    if (serverErrorFor.contains(id)) {
      return _failed(m, 'rejected', {
        'code': 'server_error',
        'message': 'Something went wrong. Try again.',
        'retryable': true,
      });
    }

    final ack = switch (m['operation']) {
      'habit.create' => _habitCreate(m),
      'log.set_value' || 'log.set_binary' => _setValue(m),
      'log.delete' => _delete(m),
      'profile.set_timezone' => _setTimezone(m),
      'profile.update' => _profileUpdate(m),
      'reminder.create' || 'reminder.update' || 'reminder.delete' => _reminder(m),
      _ => _failed(m, 'rejected', {'code': 'unsupported_operation', 'message': 'x'}),
    };
    if (ack['status'] != 'dependency_pending') receipts[id] = (hash: hash, ack: ack);
    return ack;
  }

  /// A26: a zone other than the one in force becomes pending from the next day start; the zone
  /// in force cancels a pending change.
  Map<String, dynamic> _setTimezone(Map<String, dynamic> m) {
    if (m['base_version'] != userVersion) {
      return _failed(m, 'conflict', {
        'code': 'version_conflict',
        'message': 'x',
        'resource_id': 'user-1',
        'expected_version': m['base_version'],
        'current_version': userVersion,
        'current': user,
      });
    }
    final zone = (m['payload'] as Map)['timezone'] as String;
    pendingZone = zone == timezone ? null : zone;
    userVersion++;
    _journal('user', 'user-1', 'upsert', userVersion, user);
    return {
      'mutation_id': m['mutation_id'],
      'status': 'accepted',
      'duplicate': false,
      'entity': 'user',
      'entity_id': 'user-1',
      'version': userVersion,
    };
  }

  /// Phase 3b: profile.update as the real ProfileUpdate answers it (identical state: no bump).
  Map<String, dynamic> _profileUpdate(Map<String, dynamic> m) {
    if (m['base_version'] != userVersion) {
      return _failed(m, 'conflict', {
        'code': 'version_conflict',
        'message': 'x',
        'resource_id': 'user-1',
        'expected_version': m['base_version'],
        'current_version': userVersion,
        'current': user,
      });
    }
    final p = (m['payload'] as Map).cast<String, dynamic>();
    final changed = p['name'] != name || p['city'] != city || p['country_code'] != countryCode;
    if (changed) {
      name = p['name'] as String;
      city = p['city'] as String?;
      countryCode = p['country_code'] as String?;
      userVersion++;
      _journal('user', 'user-1', 'upsert', userVersion, user);
    }
    return {
      'mutation_id': m['mutation_id'],
      'status': 'accepted',
      'duplicate': false,
      'entity': 'user',
      'entity_id': 'user-1',
      'version': userVersion,
    };
  }

  /// A photo change through the avatar endpoints (another device, or this one's upload): bumps
  /// avatar_version and the user version and journals the user.
  void changeAvatar({required bool present}) {
    avatarVersion++;
    hasAvatar = present;
    userVersion++;
    _journal('user', 'user-1', 'upsert', userVersion, user);
  }

  /// Phase 3.2b reminders, as the real ReminderWrites answers them.
  Map<String, dynamic> _reminder(Map<String, dynamic> m) {
    final id = m['entity_id'] as String;
    final p = (m['payload'] as Map).cast<String, dynamic>();
    final existing = reminders[id];
    Map<String, dynamic> conflict(Map<String, dynamic> current) => current['deleted_at'] != null
        ? _failed(m, 'conflict', {
            'code': 'resource_deleted',
            'message': 'x',
            'entity': 'reminder',
            'resource_id': id,
            'current_version': current['version'],
          })
        : _failed(m, 'conflict', {
            'code': 'version_conflict',
            'message': 'x',
            'resource_id': id,
            'expected_version': m['base_version'],
            'current_version': current['version'],
            'current': current,
          });
    Map<String, dynamic> write(Map<String, dynamic> row, String op) {
      reminders[id] = row;
      _journal('reminder', id, op, row['version'] as int, row);
      return {
        'mutation_id': m['mutation_id'],
        'status': 'accepted',
        'duplicate': false,
        'entity': 'reminder',
        'entity_id': id,
        'version': row['version'],
      };
    }

    if (m['operation'] == 'reminder.create') {
      if (!habits.containsKey(p['habit_id'])) {
        return {
          'mutation_id': m['mutation_id'],
          'status': 'dependency_pending',
          'duplicate': false,
        };
      }
      if (existing != null) return conflict(existing);
      final days = [...(p['days_of_week'] as List).cast<int>()]..sort();
      return write({
        'id': id,
        'habit_id': p['habit_id'],
        'local_time': p['local_time'],
        'days_of_week': days,
        'timezone_mode': p['timezone_mode'],
        'timezone': p['timezone'],
        'enabled': p['enabled'] ?? true,
        'version': 1,
        'deleted_at': null,
      }, 'upsert');
    }
    if (existing == null) {
      return _failed(m, 'rejected', {'code': 'not_found', 'message': 'Not found.'});
    }
    if (existing['deleted_at'] != null || m['base_version'] != existing['version']) {
      return conflict(existing);
    }
    final next = (existing['version'] as int) + 1;
    if (m['operation'] == 'reminder.delete') {
      return write({...existing, 'version': next, 'deleted_at': '2026-05-28T17:22:00Z'}, 'delete');
    }
    final days = [...(p['days_of_week'] as List).cast<int>()]..sort();
    return write({
      ...existing,
      'local_time': p['local_time'],
      'days_of_week': days,
      'timezone_mode': p['timezone_mode'],
      'timezone': p['timezone'],
      'enabled': p['enabled'] ?? true,
      'version': next,
    }, 'upsert');
  }

  Map<String, dynamic> _habitCreate(Map<String, dynamic> m) {
    final id = m['entity_id'] as String;
    final p = (m['payload'] as Map).cast<String, dynamic>();
    if (!knownTypes.contains(p['type'])) {
      return _failed(m, 'rejected', {'code': 'unsupported_type', 'message': 'x'});
    }
    if (habits.containsKey(id)) {
      return _failed(m, 'conflict', {
        'code': 'version_conflict',
        'message': 'x',
        'resource_id': id,
        'expected_version': 0,
        'current_version': 1,
        'current': habits[id],
      });
    }
    habits[id] = {
      'id': id,
      'name': p['name'],
      'type': p['type'],
      'unit': p['unit'],
      'category': p['category'],
      'target_value': p['target_value'],
      'frequency_type': p['frequency_type'],
      'frequency_config': p['frequency_config'],
      'start_local_date': p['start_local_date'],
      'archived_at': null,
      'version': 1,
      'definition_version': 1,
      'definitions': [
        {
          'version': 1,
          'effective_date': p['start_local_date'],
          'type': p['type'],
          'target_value': p['target_value'],
          'unit': p['unit'],
          'category': p['category'],
          'frequency_type': p['frequency_type'],
          'frequency_config': p['frequency_config'],
          'config': <String, Object>{},
        },
      ],
      'active_ranges': [
        {'starts_on': p['start_local_date'], 'ends_before': null},
      ],
    };
    _journal('habit', id, 'upsert', 1, habits[id]!);
    return _accepted(m, id, 1);
  }

  Map<String, dynamic> _setValue(Map<String, dynamic> m) {
    final p = (m['payload'] as Map).cast<String, dynamic>();
    final habitId = p['habit_id'] as String;
    if (!habits.containsKey(habitId)) {
      return {'mutation_id': m['mutation_id'], 'status': 'dependency_pending', 'duplicate': false};
    }
    final date = m['local_date_hint'] as String;
    final base = m['base_version'] as int?;
    final existing = _byNaturalKey(habitId, date);

    if (existing != null && existing['deleted_at'] != null) {
      if (base != existing['version']) {
        return _failed(m, 'conflict', {
          'code': 'resource_deleted',
          'message': 'x',
          'entity': 'habit_log',
          'resource_id': existing['id'],
          'current_version': existing['version'],
        }, entityId: existing['id'] as String);
      }
      return _writeLog(
        existing['id'] as String,
        habitId,
        date,
        p['value'],
        (existing['version'] as int) + 1,
        m,
      );
    }
    if (existing != null) {
      if (jsonEncode(existing['value']) == jsonEncode(p['value'])) {
        return _accepted(m, existing['id'] as String, existing['version'] as int, date: date);
      }
      if (base != existing['version']) {
        return _failed(m, 'conflict', {
          'code': 'version_conflict',
          'message': 'x',
          'resource_id': existing['id'],
          'expected_version': base,
          'current_version': existing['version'],
          'current': existing,
        }, entityId: existing['id'] as String);
      }
      return _writeLog(
        existing['id'] as String,
        habitId,
        date,
        p['value'],
        (existing['version'] as int) + 1,
        m,
      );
    }
    if (base != 0) {
      return _failed(m, 'conflict', {
        'code': 'version_conflict',
        'message': 'x',
        'resource_id': m['entity_id'],
        'expected_version': base,
        'current_version': 0,
        'current': <String, Object>{},
      });
    }
    final id = logs.containsKey(m['entity_id'])
        ? 'srv-${logs.length + 1}'
        : m['entity_id'] as String;
    return _writeLog(id, habitId, date, p['value'], 1, m);
  }

  Map<String, dynamic> _writeLog(
    String id,
    String habitId,
    String date,
    Object? value,
    int version,
    Map<String, dynamic> m,
  ) {
    logs[id] = {
      'id': id,
      'habit_id': habitId,
      'log_date': date,
      'value': value,
      'detail': <String, Object>{},
      'occurred_at': m['occurred_at'],
      'completed_at': null,
      'resolved_timezone': timezone,
      'day_start_offset_minutes': 0,
      'definition_version': 1,
      'version': version,
      'deleted_at': null,
    };
    _journal('habit_log', id, 'upsert', version, logs[id]!);
    return _accepted(m, id, version, date: date);
  }

  Map<String, dynamic> _delete(Map<String, dynamic> m) {
    final p = (m['payload'] as Map).cast<String, dynamic>();
    final log =
        logs[m['entity_id']] ?? _byNaturalKey(p['habit_id'] as String?, p['log_date'] as String?);
    if (log == null) return _failed(m, 'rejected', {'code': 'not_found', 'message': 'Not found.'});
    final base = m['base_version'] as int?;
    if (log['deleted_at'] != null) {
      if (base == log['version']) {
        return _accepted(
          m,
          log['id'] as String,
          log['version'] as int,
          date: log['log_date'] as String,
        );
      }
      return _failed(m, 'conflict', {
        'code': 'resource_deleted',
        'message': 'x',
        'entity': 'habit_log',
        'resource_id': log['id'],
        'current_version': log['version'],
      }, entityId: log['id'] as String);
    }
    if (base != log['version']) {
      return _failed(m, 'conflict', {
        'code': 'version_conflict',
        'message': 'x',
        'resource_id': log['id'],
        'expected_version': base,
        'current_version': log['version'],
        'current': log,
      }, entityId: log['id'] as String);
    }
    final version = (log['version'] as int) + 1;
    log
      ..['version'] = version
      ..['deleted_at'] = '2026-05-28T17:22:00Z';
    _journal('habit_log', log['id'] as String, 'delete', version, log);
    return _accepted(m, log['id'] as String, version, date: log['log_date'] as String);
  }

  Map<String, dynamic>? _byNaturalKey(String? habitId, String? date) {
    for (final log in logs.values) {
      if (log['habit_id'] == habitId && log['log_date'] == date) return log;
    }
    return null;
  }

  void _journal(String entity, String id, String op, int version, Map<String, dynamic> payload) {
    journal.add({
      'seq': seq + 1,
      'entity': entity,
      'id': id,
      'operation': op,
      'version': version,
      'payload': _deepCopy(payload),
    });
  }

  /// Journals a (possibly partial) user entity, as later phases will for XP or level.
  void journalUser(Map<String, dynamic> payload) =>
      _journal('user', payload['id'] as String, 'upsert', seq + 1, payload);

  /// Journals any entity at a chosen version (A32 derived entities, deletes).
  void journalEntity(
    String entity,
    String id,
    int version,
    Map<String, dynamic> payload, {
    String operation = 'upsert',
  }) => _journal(entity, id, operation, version, payload);

  /// Journals a change for an entity type the app does not know.
  void journalOpaque(String entity, String id, Map<String, dynamic> payload) =>
      _journal(entity, id, 'upsert', 1, payload);

  SyncPage _pull(int after, int limit, List<Map<String, dynamic>> acks) {
    final pending = journal.where((c) => (c['seq'] as int) > after).toList();
    final page = pending.take(limit).toList();
    final last = page.isEmpty ? after : page.last['seq'] as int;
    return SyncPage(
      acks: acks,
      changes: page,
      nextCursor: 'c:$last',
      hasMore: pending.length > limit,
      serverTime: clock?.call(),
    );
  }

  int _seqOf(String? cursor) {
    if (cursor == null) return 0;
    final s = int.parse(cursor.substring(2));
    if (s < expiredBelowSeq || s > seq) {
      throw const SyncTransportException(SyncFailure.cursorExpired);
    }
    return s;
  }

  Map<String, dynamic> _accepted(Map<String, dynamic> m, String id, int version, {String? date}) =>
      {
        'mutation_id': m['mutation_id'],
        'status': 'accepted',
        'duplicate': false,
        'entity': m['entity'],
        'entity_id': id,
        'version': version,
        'resolved_date': ?date,
      };

  Map<String, dynamic> _failed(
    Map<String, dynamic> m,
    String status,
    Map<String, dynamic> error, {
    String? entityId,
  }) => {
    'mutation_id': m['mutation_id'],
    'status': status,
    'duplicate': false,
    'entity': m['entity'],
    'entity_id': entityId ?? m['entity_id'],
    'error': error,
  };

  static Object? _canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(v[k])};
    }
    if (v is List) return v.map(_canonical).toList();
    return v;
  }

  static Map<String, dynamic> _deepCopy(Map<String, Object?> m) =>
      (jsonDecode(jsonEncode(m)) as Map).cast<String, dynamic>();
}
