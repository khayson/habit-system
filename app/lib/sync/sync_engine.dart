import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/entity_codec.dart';
import '../domain/calendar/day_resolver.dart';
import 'outbox_states.dart';
import 'sync_transport.dart';

enum SyncOutcome {
  /// Everything pushable was pushed and the journal is drained.
  completed,

  /// Another engine holds the lease on this database.
  busy,

  /// No network; try again when connectivity returns.
  offline,

  /// 5xx (or nothing more can be sent this run); try again later.
  backoff,

  /// 429; `sync_state.next_sync_at` holds the Retry-After instant.
  rateLimited,

  /// 401 and the single refresh failed; the session ended, the database was kept.
  loggedOut,
}

/// Foreground sync engine (spec 07, PHASE_2A_REVIEW §5, PHASE_2A1_REVIEW §5). Pure Dart.
///
/// - Single-flight: a lease row in sync_state, so two engines on one database file never run
///   together, whatever isolate or process they are in.
/// - The cursor advances only in the transaction that applies the acks and changes it covers
///   (invariant 8). A crash anywhere replays safely: server receipts dedupe re-sent mutations
///   and changes apply only when their version is >= the confirmed one.
class SyncEngine {
  static const int maxChunk = 100;
  static const int maxAttemptsBeforeSurfacing = 20;
  static const Duration surfaceAfter = Duration(hours: 24);

  final AppDatabase db;
  final SyncTransport transport;
  final AuthSession auth;
  final Clock clock;
  final Random random;
  final String ownerId;
  final Duration leaseDuration;
  final int pullLimit;
  final List<String> capabilities;

  /// Test hook: runs inside the apply transaction just before it commits.
  final Future<void> Function()? beforeApplyCommit;

  SyncEngine({
    required this.db,
    required this.transport,
    required this.auth,
    required this.capabilities,
    Clock? clock,
    Random? random,
    String? ownerId,
    this.leaseDuration = const Duration(seconds: 60),
    this.pullLimit = 200,
    this.beforeApplyCommit,
  }) : clock = clock ?? (() => DateTime.now().toUtc()),
       random = random ?? Random(),
       ownerId = ownerId ?? const Uuid().v4();

  Future<SyncOutcome> run() async {
    if (!await _acquireLease()) return SyncOutcome.busy;
    try {
      return await _runLocked();
    } finally {
      await _releaseLease();
    }
  }

  Future<SyncOutcome> _runLocked() async {
    await _recoverInFlight();
    var refreshed = false;
    var chunk = maxChunk;

    for (var round = 0; round < 1000; round++) {
      await _renewLease();
      final state = await _state();
      List<OutboxRow> rows = const [];
      try {
        if (state.cursor == null) {
          await _bootstrap(state.bootstrapCursor);
          continue;
        }
        rows = await _eligible(chunk);
        await _setState(rows, OutboxState.inFlight);
        final page = await transport.sync(
          deviceId: state.deviceId,
          cursor: state.cursor,
          pullLimit: pullLimit,
          mutations: rows.map(_wire).toList(),
          capabilities: capabilities,
        );
        await _apply(page, rows);
        if (!page.hasMore && (await _eligible(1)).isEmpty) {
          await _updateState(SyncStateCompanion(lastSyncedAt: Value(_now)));
          return SyncOutcome.completed;
        }
      } on SyncTransportException catch (e) {
        await _recoverInFlight();
        switch (e.kind) {
          case SyncFailure.cursorExpired:
            // 410: bootstrap again; the outbox is untouched and re-sends idempotently.
            await _updateState(
              const SyncStateCompanion(cursor: Value(null), bootstrapCursor: Value(null)),
            );
            continue;
          case SyncFailure.unauthorized:
            if (!refreshed) {
              refreshed = true;
              switch (await auth.refresh()) {
                case RefreshResult.refreshed:
                  continue;
                case RefreshResult.unavailable:
                  return SyncOutcome.offline;
                case RefreshResult.rejected:
                  break;
              }
            }
            await auth.logout();
            return SyncOutcome.loggedOut;
          case SyncFailure.payloadTooLarge:
            // HTTP 413: too many mutations in one request. Send fewer.
            if (chunk > 1) {
              chunk = max(1, chunk ~/ 2);
              continue;
            }
            return SyncOutcome.backoff;
          case SyncFailure.rateLimited:
            final wait = e.retryAfter ?? const Duration(seconds: 60);
            await _updateState(SyncStateCompanion(nextSyncAt: Value(_now + wait.inMilliseconds)));
            return SyncOutcome.rateLimited;
          case SyncFailure.server:
            return SyncOutcome.backoff;
          case SyncFailure.network:
            return SyncOutcome.offline;
        }
      }
    }
    return SyncOutcome.backoff;
  }

  // Bootstrap ---------------------------------------------------------------------------------

  Future<void> _bootstrap(String? resumeFrom) async {
    var cursor = resumeFrom;
    while (true) {
      final page = await transport.bootstrap(cursor: cursor, limit: pullLimit);
      await db.transaction(() async {
        if (page.user != null) await _applyUser(page.user!);
        for (final habit in page.habits) {
          await _upsertHabit(habit['id'] as String, habit['version'] as int, habit);
        }
        for (final log in page.logs) {
          await _upsertLog(log['id'] as String, log['version'] as int, log);
        }
        // ASSUMPTION(A2b-opaque-bootstrap): an unknown bootstrap collection is stored opaquely
        // with its key as the entity type, so a newer server's entities are never dropped.
        for (final MapEntry(key: type, value: items) in page.unknownCollections.entries) {
          for (final item in items) {
            final id = item['id'];
            if (id is! String) continue;
            await _storeOpaque(type, id, item['version'] as int? ?? 0, 'upsert', item);
          }
        }
        // Progress and the final sync cursor are saved with the page they belong to.
        await _updateState(
          page.hasMore
              ? SyncStateCompanion(bootstrapCursor: Value(page.nextCursor))
              : SyncStateCompanion(
                  cursor: Value(page.syncCursor),
                  bootstrapCursor: const Value(null),
                ),
        );
        await _prune();
        await _resumeWaiting();
      });
      if (!page.hasMore) return;
      cursor = page.nextCursor;
      await _renewLease();
    }
  }

  // Push selection -----------------------------------------------------------------------------

  /// Unacknowledged rows in order, at most [limit]. Ordering is per entity: a waiting, blocked or
  /// needs-attention row holds back later rows of the same entity (and logs of its habit), and
  /// nothing else.
  Future<List<OutboxRow>> _eligible(int limit) async {
    final rows =
        await (db.select(db.outbox)
              ..where(
                (o) => o.state.isIn([
                  OutboxState.pending,
                  OutboxState.blocked,
                  OutboxState.waiting,
                  OutboxState.needsAttention,
                ]),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();
    final now = _now;
    final held = <String>{};
    final result = <OutboxRow>[];
    for (final row in rows) {
      final key = '${row.entity}:${row.entityId}';
      final parentKey = row.entity == 'habit_log' ? 'habit:${row.habitId}' : null;
      final due =
          row.state == OutboxState.pending ||
          (row.state == OutboxState.blocked && (row.nextAttemptAt ?? 0) <= now);
      if (!due || held.contains(key) || (parentKey != null && held.contains(parentKey))) {
        held.add(key);
        continue;
      }
      result.add(row);
      if (result.length >= limit) break;
    }
    return result;
  }

  Map<String, Object?> _wire(OutboxRow row) => {
    'mutation_id': row.mutationId,
    'entity': row.entity,
    'entity_id': row.entityId,
    'operation': row.operation,
    'base_version': row.baseVersion,
    'occurred_at': row.occurredAt,
    'captured_timezone': row.capturedTimezone,
    'local_date_hint': row.localDateHint,
    'payload': jsonDecode(row.payload),
  };

  // Apply ---------------------------------------------------------------------------------------

  Future<void> _apply(SyncPage page, List<OutboxRow> sent) {
    return db.transaction(() async {
      final acks = {for (final ack in page.acks) ack['mutation_id']: ack};
      for (final row in sent) {
        final ack = acks[row.mutationId];
        if (ack == null) {
          await _setState([row], OutboxState.pending);
        } else {
          await _applyAck(row, ack);
        }
      }
      for (final change in page.changes) {
        await _applyChange(change);
      }
      // The cursor moves only together with the changes it covers (invariant 8).
      await _updateState(SyncStateCompanion(cursor: Value(page.nextCursor)));
      await _prune();
      await _resumeWaiting();
      // After every ack: a child's own dependency_pending ack must not outlive its parent's
      // rejection in the same batch.
      await _rejectOrphans();
      if (beforeApplyCommit != null) await beforeApplyCommit!();
    });
  }

  Future<void> _applyAck(OutboxRow row, Map<String, dynamic> ack) async {
    final status = ack['status'];
    final error = (ack['error'] as Map?)?.cast<String, dynamic>();

    if (status == 'accepted') {
      final canonical = ack['entity_id'] as String? ?? row.entityId;
      if (canonical != row.entityId) await _remap(row.entityId, canonical);
      await _update(
        row,
        OutboxCompanion(
          state: const Value(OutboxState.acked),
          ackVersion: Value(ack['version'] as int?),
          entityId: Value(canonical),
          lastError: const Value(null),
        ),
      );
      if (row.operation == 'habit.create') await _resumeChildren(canonical);
      return;
    }

    if (status == 'dependency_pending') {
      await _update(row, const OutboxCompanion(state: Value(OutboxState.waiting)));
      return;
    }

    if (status == 'rejected' && error?['retryable'] == true) {
      final attempts = row.attempts + 1;
      final firstFailed = row.firstFailedAt ?? _now;
      await _update(
        row,
        OutboxCompanion(
          state: const Value(OutboxState.blocked),
          attempts: Value(attempts),
          firstFailedAt: Value(firstFailed),
          nextAttemptAt: Value(_now + _backoff(attempts).inMilliseconds),
          surfaced: Value(
            attempts >= maxAttemptsBeforeSurfacing ||
                _now - firstFailed >= surfaceAfter.inMilliseconds,
          ),
          lastError: Value(jsonEncode(error)),
        ),
      );
      return;
    }

    // Conflict, permanent rejection (incl. ack-level payload_too_large) or a status this app
    // version does not know: keep the data for the user; never resubmit automatically.
    await _update(
      row,
      OutboxCompanion(
        state: const Value(OutboxState.needsAttention),
        lastError: Value(jsonEncode(error ?? {'code': 'unknown_status', 'status': status})),
      ),
    );
    final calendar = (error?['calendar'] as Map?)?.cast<String, dynamic>();
    if (error?['code'] == 'timezone_context_mismatch' && calendar != null) {
      await _updateState(
        SyncStateCompanion(
          calendarTimezone: Value(calendar['timezone'] as String?),
          calendarDayStartOffset: Value(calendar['day_start_offset_minutes'] as int? ?? 0),
          calendarEffectiveAt: Value(calendar['effective_at'] as String?),
        ),
      );
    }
  }

  /// Exponential backoff with jitter: 1 min doubling to 1 h.
  Duration _backoff(int attempts) {
    final base = min(3600, 60 * pow(2, min(attempts - 1, 10)).toInt());
    final jittered = (base * (0.8 + random.nextDouble() * 0.4)).round();
    return Duration(seconds: min(3600, jittered));
  }

  /// The server answered with another id (merge): move every local reference (A29).
  Future<void> _remap(String from, String to) async {
    await db.customUpdate(
      'UPDATE outbox SET entity_id = ? WHERE entity_id = ?',
      variables: [Variable(to), Variable(from)],
      updates: {db.outbox},
    );
    final children = await (db.select(db.outbox)..where((o) => o.habitId.equals(from))).get();
    for (final child in children) {
      final payload = (jsonDecode(child.payload) as Map).cast<String, Object?>();
      if (payload['habit_id'] == from) payload['habit_id'] = to;
      await _update(
        child,
        OutboxCompanion(habitId: Value(to), payload: Value(jsonEncode(payload))),
      );
    }
    for (final table in ['habits', 'habit_logs']) {
      await db.customUpdate(
        'UPDATE $table SET id = ? WHERE id = ? AND NOT EXISTS (SELECT 1 FROM $table WHERE id = ?)',
        variables: [Variable(to), Variable(from), Variable(to)],
        updates: {db.habits, db.habitLogs},
      );
    }
  }

  Future<void> _resumeChildren(String habitId) => db.customUpdate(
    'UPDATE outbox SET state = ? WHERE state = ? AND habit_id = ? AND entity = ?',
    variables: [
      const Variable(OutboxState.pending),
      const Variable(OutboxState.waiting),
      Variable(habitId),
      const Variable('habit_log'),
    ],
    updates: {db.outbox},
  );

  /// A habit whose create was rejected can never exist, so its unsent logs can never apply:
  /// mark them parent_rejected and keep their data for the user (PHASE_2A_REVIEW Q1).
  Future<void> _rejectOrphans() => db.customUpdate(
    '''UPDATE outbox SET state = ?, last_error = ?
       WHERE entity = 'habit_log' AND state IN (?, ?, ?)
         AND habit_id IN (SELECT entity_id FROM outbox WHERE operation = 'habit.create' AND state = ?)''',
    variables: [
      const Variable(OutboxState.needsAttention),
      Variable(
        jsonEncode({
          'code': 'parent_rejected',
          'message': 'The habit this belongs to was not accepted.',
        }),
      ),
      const Variable(OutboxState.pending),
      const Variable(OutboxState.waiting),
      const Variable(OutboxState.blocked),
      const Variable(OutboxState.needsAttention),
    ],
    updates: {db.outbox},
  );

  Future<void> _applyChange(Map<String, dynamic> change) async {
    final entity = change['entity'] as String;
    final id = change['id'] as String;
    final version = change['version'] as int;
    final payload = (change['payload'] as Map).cast<String, dynamic>();
    switch (entity) {
      case 'habit':
        await _upsertHabit(id, version, payload);
      case 'habit_log':
        await _upsertLog(id, version, payload);
      case 'user':
        await _applyUser(payload);
      default:
        // Unknown entity type: keep it opaque, never drop it (invariant 13).
        await _storeOpaque(entity, id, version, change['operation'] as String, payload);
    }
  }

  Future<void> _storeOpaque(
    String type,
    String id,
    int version,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final existing = await (db.select(
      db.opaqueEntities,
    )..where((o) => o.entityType.equals(type) & o.entityId.equals(id))).getSingleOrNull();
    if (existing != null && version < existing.version) return;
    await db
        .into(db.opaqueEntities)
        .insertOnConflictUpdate(
          OpaqueEntitiesCompanion.insert(
            entityType: type,
            entityId: id,
            version: version,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
  }

  /// Apply only if the incoming version is >= the confirmed one (bootstrap and pulls overlap).
  Future<void> _upsertHabit(String id, int version, Map<String, dynamic> payload) async {
    final existing = await (db.select(db.habits)..where((h) => h.id.equals(id))).getSingleOrNull();
    if (existing != null && version < existing.version) return;
    await db
        .into(db.habits)
        .insertOnConflictUpdate(EntityCodec.habitRow(payload, id: id, version: version));
  }

  /// Same rule; a delete is a tombstone row, also for ids this device never saw.
  Future<void> _upsertLog(String id, int version, Map<String, dynamic> payload) async {
    final existing = await (db.select(
      db.habitLogs,
    )..where((l) => l.id.equals(id))).getSingleOrNull();
    if (existing != null && version < existing.version) return;
    await db
        .into(db.habitLogs)
        .insertOnConflictUpdate(EntityCodec.logRow(payload, id: id, version: version));
  }

  Future<void> _applyUser(Map<String, dynamic> user) => _updateState(
    SyncStateCompanion(
      userPayload: Value(jsonEncode(user)),
      calendarTimezone: Value(user['timezone'] as String?),
      calendarDayStartOffset: Value(user['day_start_offset_minutes'] as int? ?? 0),
    ),
  );

  /// Acked rows can go once the confirmed row reflects them; unacknowledged rows never do.
  Future<void> _prune() async {
    await db.customUpdate(
      '''DELETE FROM outbox WHERE state = ? AND (
           (entity = 'habit' AND EXISTS (SELECT 1 FROM habits h WHERE h.id = outbox.entity_id AND h.version >= COALESCE(outbox.ack_version, 0)))
        OR (entity = 'habit_log' AND EXISTS (SELECT 1 FROM habit_logs l WHERE l.id = outbox.entity_id AND l.version >= COALESCE(outbox.ack_version, 0))))''',
      variables: [const Variable(OutboxState.acked)],
      updates: {db.outbox},
    );
  }

  /// A waiting log resumes once its habit is confirmed (pulled or bootstrapped).
  Future<void> _resumeWaiting() => db.customUpdate(
    'UPDATE outbox SET state = ? WHERE state = ? AND habit_id IN (SELECT id FROM habits)',
    variables: [const Variable(OutboxState.pending), const Variable(OutboxState.waiting)],
    updates: {db.outbox},
  );

  // State, lease, helpers ------------------------------------------------------------------------

  int get _now => clock().toUtc().millisecondsSinceEpoch;

  Future<SyncStateRow> _state() =>
      (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();

  Future<void> _updateState(SyncStateCompanion values) =>
      (db.update(db.syncState)..where((s) => s.id.equals(1))).write(values);

  Future<void> _update(OutboxRow row, OutboxCompanion values) =>
      (db.update(db.outbox)..where((o) => o.seq.equals(row.seq))).write(values);

  Future<void> _setState(List<OutboxRow> rows, String state) async {
    if (rows.isEmpty) return;
    await (db.update(db.outbox)..where((o) => o.seq.isIn(rows.map((r) => r.seq)))).write(
      OutboxCompanion(state: Value(state)),
    );
  }

  /// Rows a crashed run left in flight go back to pending (their re-send is deduped by receipts).
  Future<void> _recoverInFlight() => db.customUpdate(
    'UPDATE outbox SET state = ? WHERE state = ?',
    variables: [const Variable(OutboxState.pending), const Variable(OutboxState.inFlight)],
    updates: {db.outbox},
  );

  Future<bool> _acquireLease() async {
    final taken = await db.customUpdate(
      'UPDATE sync_state SET lease_owner = ?, lease_until = ? '
      'WHERE id = 1 AND (lease_owner IS NULL OR lease_until < ? OR lease_owner = ?)',
      variables: [
        Variable(ownerId),
        Variable(_now + leaseDuration.inMilliseconds),
        Variable(_now),
        Variable(ownerId),
      ],
      updates: {db.syncState},
    );
    return taken == 1;
  }

  Future<void> _renewLease() => db.customUpdate(
    'UPDATE sync_state SET lease_until = ? WHERE id = 1 AND lease_owner = ?',
    variables: [Variable(_now + leaseDuration.inMilliseconds), Variable(ownerId)],
    updates: {db.syncState},
  );

  Future<void> _releaseLease() => db.customUpdate(
    'UPDATE sync_state SET lease_owner = NULL, lease_until = NULL WHERE id = 1 AND lease_owner = ?',
    variables: [Variable(ownerId)],
    updates: {db.syncState},
  );
}

/// Creates the account's sync_state row on first sign-in (no-op afterwards). The server
/// calendar comes from the signed-in user (A5).
Future<void> initAccountState(
  AppDatabase db, {
  required String userId,
  required String deviceId,
  required Map<String, dynamic> user,
}) async {
  await db
      .into(db.syncState)
      .insert(
        SyncStateCompanion.insert(
          id: const Value(1),
          userId: userId,
          deviceId: deviceId,
          calendarTimezone: Value(user['timezone'] as String?),
          calendarDayStartOffset: Value(user['day_start_offset_minutes'] as int? ?? 0),
          userPayload: Value(jsonEncode(user)),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
