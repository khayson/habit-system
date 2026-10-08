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

  /// 401: the session is over (the ApiClient ended it). Database and outbox are kept.
  loggedOut,

  /// Three whole-request 4xx in a row: `sync_state.status` is `paused` (F7). Nothing was
  /// dropped; the engine keeps trying with backoff and the first success resumes.
  paused,

  /// Something unexpected (not a transport failure) stopped the run. Rows went back to pending
  /// and `sync_state.last_error` says what happened (F2).
  failed,
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
  static const int pauseAfterRejections = 3;

  /// After an offline outcome, the next unforced run waits this long (G2).
  static const Duration offlineFloor = Duration(seconds: 10);

  /// A sent row the server did not answer is retried; from this many attempts it backs off (F8).
  static const int blockAfterMissingAcks = 3;

  /// 410s answered by a fresh bootstrap within one run (F8).
  static const int maxRebootstrapsPerRun = 2;

  final AppDatabase db;
  final SyncTransport transport;
  final Clock clock;
  final Random random;
  final String ownerId;
  final Duration leaseDuration;
  final int pullLimit;
  final List<String> capabilities;

  /// Test hook: runs inside the apply transaction just before it commits.
  final Future<void> Function()? beforeApplyCommit;

  /// Test hook: runs inside the claim transaction, between selecting rows and marking them.
  final Future<void> Function()? betweenSelectAndMark;

  SyncEngine({
    required this.db,
    required this.transport,
    required this.capabilities,
    Clock? clock,
    Random? random,
    String? ownerId,
    this.leaseDuration = const Duration(seconds: 60),
    this.pullLimit = 200,
    this.beforeApplyCommit,
    this.betweenSelectAndMark,
  }) : clock = clock ?? (() => DateTime.now().toUtc()),
       random = random ?? Random(),
       ownerId = ownerId ?? const Uuid().v4();

  Future<SyncOutcome>? _running;

  /// Runs one sync. Concurrent callers on this engine share the run in progress (F3): a
  /// connectivity event, a resume and "Sync now" together make one request sequence.
  ///
  /// Backoff is enforced here (F6): nothing is sent before a 429's Retry-After, or before the
  /// backoff earned by consecutive 5xx, network or unexpected failures.
  /// ASSUMPTION(A2b-backoff-bypass): [force] skips the failure backoff (never Retry-After); only
  /// "connectivity regained" and the user's "Sync now" pass it.
  Future<SyncOutcome> run({bool force = false}) =>
      _running ??= _run(force).whenComplete(() => _running = null);

  Future<SyncOutcome> _run(bool force) async {
    final state = await _state();
    if ((state.nextSyncAt ?? 0) > _now) return SyncOutcome.rateLimited;
    if (!force && (state.backoffUntil ?? 0) > _now) return SyncOutcome.backoff;
    final outcome = await _leased();
    switch (outcome) {
      case SyncOutcome.completed:
        await _updateState(
          const SyncStateCompanion(
            consecutiveFailures: Value(0),
            backoffUntil: Value(null),
            nextSyncAt: Value(null),
            requestRejections: Value(0),
            status: Value(SyncStatus.active),
            statusCode: Value(null),
          ),
        );
      case SyncOutcome.offline:
        // G2: no network is not a server problem. A short fixed floor stops trigger storms
        // without making a weak-signal resume wait minutes; it never doubles.
        await _updateState(
          SyncStateCompanion(backoffUntil: Value(_now + offlineFloor.inMilliseconds)),
        );
      case SyncOutcome.backoff || SyncOutcome.failed || SyncOutcome.paused:
        await _recordFailure();
      case SyncOutcome.busy || SyncOutcome.rateLimited || SyncOutcome.loggedOut:
        break;
    }
    return outcome;
  }

  /// Server time minus device time, from every answer that carries `meta.server_time` (F10).
  /// The writer stamps events and shows "today" on the corrected clock.
  Future<void> _noteServerTime(DateTime? serverTime) async {
    if (serverTime == null) return;
    await _updateState(
      SyncStateCompanion(clockSkewMs: Value(serverTime.millisecondsSinceEpoch - _now)),
    );
  }

  /// Whole-request 4xx: keep every row and back off; after [pauseAfterRejections] in a row the
  /// status becomes paused with the server's code, for screen 18 (F7).
  Future<SyncOutcome> _countRejection(String code) async {
    final count = (await _state()).requestRejections + 1;
    final paused = count >= pauseAfterRejections;
    await _updateState(
      SyncStateCompanion(
        requestRejections: Value(count),
        status: paused ? const Value(SyncStatus.paused) : const Value.absent(),
        statusCode: paused ? Value(code) : const Value.absent(),
        lastError: Value(_error(code, 'The server refused the sync request.')),
      ),
    );
    return paused ? SyncOutcome.paused : SyncOutcome.backoff;
  }

  /// 30 s doubling to 15 min, with jitter; persisted so every trigger honours it (F6).
  Future<void> _recordFailure() async {
    final failures = (await _state()).consecutiveFailures + 1;
    final base = min(900, 30 * pow(2, min(failures - 1, 10)).toInt());
    final wait = min(900, (base * (0.8 + random.nextDouble() * 0.4)).round());
    await _updateState(
      SyncStateCompanion(
        consecutiveFailures: Value(failures),
        backoffUntil: Value(_now + wait * 1000),
      ),
    );
  }

  Future<SyncOutcome> _leased() async {
    if (!await _acquireLease()) return SyncOutcome.busy;
    try {
      return await _runLocked();
    } on _LeaseLost {
      // Another engine took over after our lease expired; it owns the outbox now.
      await _recoverInFlight();
      return SyncOutcome.busy;
    } on Object catch (e) {
      // Never let one bad answer wedge the device (F2): unsent rows go back to pending, the
      // cursor stays where the last committed page left it, and the failure is recorded.
      await _recoverInFlight();
      await _updateState(SyncStateCompanion(lastError: Value(_error('sync_failed', '$e'))));
      return SyncOutcome.failed;
    } finally {
      await _releaseLease();
    }
  }

  Future<SyncOutcome> _runLocked() async {
    await _recoverInFlight();
    var retriedRotation = false;
    var rebootstraps = 0;
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
        rows = await _claim(chunk);
        final page = await transport.sync(
          deviceId: state.deviceId,
          cursor: state.cursor,
          pullLimit: pullLimit,
          mutations: rows.map(_wire).toList(),
          capabilities: capabilities,
        );
        await _noteServerTime(page.serverTime);
        await _apply(page, rows);
        if (!page.hasMore && (await _eligible(1)).isEmpty) {
          await _updateState(
            SyncStateCompanion(
              lastSyncedAt: Value(_now),
              // A missing cursor stays reported until a page carries one again.
              lastError: page.nextCursor == null ? const Value.absent() : const Value(null),
            ),
          );
          return SyncOutcome.completed;
        }
      } on SyncTransportException catch (e) {
        await _noteServerTime(e.serverTime);
        await _recoverInFlight();
        switch (e.kind) {
          case SyncFailure.cursorExpired:
            // 410: bootstrap again; the outbox is untouched and re-sends idempotently. A server
            // that keeps answering 410 is not chased in a loop (F8).
            if (rebootstraps++ >= maxRebootstrapsPerRun) return SyncOutcome.backoff;
            await _updateState(
              const SyncStateCompanion(cursor: Value(null), bootstrapCursor: Value(null)),
            );
            continue;
          case SyncFailure.unauthorized:
            // G1: the ApiClient owns ending a session. The engine never refreshes or logs out;
            // it only retries once when the token was rotated while the request was in flight.
            if (e.tokenRotated && !retriedRotation) {
              retriedRotation = true;
              continue;
            }
            await _updateState(
              SyncStateCompanion(
                lastError: Value(_error('unauthenticated', 'The session has ended.')),
              ),
            );
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
          case SyncFailure.requestRejected:
            return _countRejection(e.code ?? 'request_rejected');
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
      await _noteServerTime(page.serverTime);
      await db.transaction(() async {
        await _renewLease();
        final user = page.user;
        if (user != null) await _guarded('user', user, () => _applyUser(user));
        for (final habit in page.habits) {
          await _guarded(
            'habit',
            habit,
            () => _upsertHabit(habit['id'] as String, habit['version'] as int, habit),
          );
        }
        for (final log in page.logs) {
          await _guarded(
            'habit_log',
            log,
            () => _upsertLog(log['id'] as String, log['version'] as int, log),
          );
        }
        // A31: new entity types arrive as {entity, id, version, payload} and are stored under
        // the same name a pull would use; they go through _applyChange like any change.
        for (final item in page.entities) {
          await _guarded(
            item['entity'],
            item,
            () => _applyChange({...item, 'operation': item['operation'] ?? 'upsert'}),
          );
        }
        // Any other unknown list is kept under `bootstrap:<key>`; nothing is dropped.
        for (final MapEntry(key: key, value: items) in page.unknownCollections.entries) {
          for (final item in items) {
            final id = item['id'];
            await _storeOpaque(
              'bootstrap:$key',
              id is String ? id : const Uuid().v4(),
              item['version'] is int ? item['version'] as int : 0,
              'upsert',
              item,
            );
          }
        }
        if (!page.hasMore && page.syncCursor == null) {
          // Without a sync cursor the snapshot cannot be followed: fail this run rather than
          // bootstrap in a loop.
          throw const FormatException('bootstrap: the last page has no sync_cursor');
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
  /// nothing else. At most ONE row per entity goes in a request (F4): the next one waits for this
  /// one's ack, which gives it its base version.
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
    final inRequest = <String>{};
    final result = <OutboxRow>[];
    for (final row in rows) {
      final key = _entityKey(row);
      final parentKey = row.entity == 'habit_log' ? 'habit:${row.habitId}' : null;
      final due =
          row.state == OutboxState.pending ||
          (row.state == OutboxState.blocked && (row.nextAttemptAt ?? 0) <= now);
      if (!due || held.contains(key) || (parentKey != null && held.contains(parentKey))) {
        held.add(key);
        continue;
      }
      // Later rows of this entity go in a later round; its logs may still ride along.
      if (!inRequest.add(key)) continue;
      result.add(row);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// A log is identified by its habit-day: its id may change on a merge, its day never does.
  static String _entityKey(OutboxRow row) => row.entity == 'habit_log'
      ? 'habit_log:${row.habitId}:${row.localDateHint}'
      : '${row.entity}:${row.entityId}';

  /// Selects the next rows and marks them in flight in ONE transaction (F1). A local write can
  /// only coalesce into a pending row, so once this commits nothing can change what is sent; a
  /// write that arrives later becomes a new row. The wire payload is built from these rows.
  Future<List<OutboxRow>> _claim(int limit) => db.transaction(() async {
    final rows = await _eligible(limit);
    if (betweenSelectAndMark != null) await betweenSelectAndMark!();
    await _setState(rows, OutboxState.inFlight);
    return rows;
  });

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
      // Commit only while this engine still owns the lease (F3); otherwise roll back.
      await _renewLease();
      final acks = {for (final ack in page.acks) ack['mutation_id']: ack};
      for (final row in sent) {
        final ack = acks[row.mutationId];
        if (ack == null) {
          await _noAck(row);
          continue;
        }
        try {
          await _applyAck(row, ack);
        } on Object catch (e) {
          if (!_isDecodeError(e)) rethrow;
          // An ack this version cannot read counts as no ack: the row is sent again and the
          // server's receipt answers it.
          await _noAck(row);
        }
      }
      for (final change in page.changes) {
        await _guarded(change['entity'], change, () => _applyChange(change));
      }
      // The cursor moves only together with the changes it covers (invariant 8). A page without
      // one is a server fault: keep the old cursor (its changes re-apply harmlessly) and record it.
      await _updateState(
        page.nextCursor != null
            ? SyncStateCompanion(cursor: Value(page.nextCursor))
            : SyncStateCompanion(
                lastError: Value(_error('missing_next_cursor', 'The server sent no cursor.')),
              ),
      );
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
      final version = ack['version'] as int?;
      if (canonical != row.entityId) await _remap(row.entityId, canonical);
      if (version != null) await _rebase(row, canonical, version);
      await _update(
        row,
        OutboxCompanion(
          state: const Value(OutboxState.acked),
          ackVersion: Value(version),
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

  /// A sent row without a (readable) ack is an attempt (F8): resent at once twice, then blocked
  /// with the usual backoff so it cannot spin.
  Future<void> _noAck(OutboxRow row) async {
    final attempts = row.attempts + 1;
    final block = attempts >= blockAfterMissingAcks;
    await _update(
      row,
      OutboxCompanion(
        state: Value(block ? OutboxState.blocked : OutboxState.pending),
        attempts: Value(attempts),
        firstFailedAt: Value(row.firstFailedAt ?? _now),
        nextAttemptAt: block
            ? Value(_now + _backoff(attempts).inMilliseconds)
            : const Value.absent(),
        lastError: Value(_error('missing_ack', 'The server did not answer this change.')),
      ),
    );
  }

  /// The client never predicts versions (F4): once a row is acked, the entity's later unsent
  /// rows are based on the version the server actually holds. An identical-state write is
  /// acked without a bump, and this keeps the next write from a false conflict.
  Future<void> _rebase(OutboxRow row, String entityId, int version) => db.customUpdate(
    '''UPDATE outbox SET base_version = ?
       WHERE seq > ? AND state IN (?, ?, ?) AND (
         (entity = 'habit_log' AND ? = 'habit_log' AND habit_id = ? AND local_date_hint = ?)
         OR (entity = ? AND entity <> 'habit_log' AND entity_id = ?))''',
    variables: [
      Variable(version),
      Variable(row.seq),
      const Variable(OutboxState.pending),
      const Variable(OutboxState.blocked),
      const Variable(OutboxState.waiting),
      Variable(row.entity),
      Variable(row.habitId),
      Variable(row.localDateHint),
      Variable(row.entity),
      Variable(entityId),
    ],
    updates: {db.outbox},
  );

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

  /// Applies one server item. If this app version cannot decode it, keeps it raw as
  /// `undecodable:<entity>` so nothing is dropped and the cursor can still advance (F2).
  Future<void> _guarded(
    Object? entity,
    Map<String, dynamic> raw,
    Future<void> Function() apply,
  ) async {
    try {
      await apply();
    } on Object catch (e) {
      if (!_isDecodeError(e)) rethrow;
      final id = raw['id'];
      await _storeOpaque(
        'undecodable:${entity is String ? entity : 'unknown'}',
        id is String ? id : const Uuid().v4(),
        0,
        'undecodable',
        raw,
      );
    }
  }

  static bool _isDecodeError(Object e) =>
      e is TypeError || e is FormatException || e is ArgumentError;

  static String _error(String code, String message) =>
      jsonEncode({'code': code, 'message': message});

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
            payload: jsonEncode(payload, toEncodable: (o) => '$o'),
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

  /// G3: a user payload may be partial (later phases journal XP or level alone). Only the
  /// calendar fields it carries are written, and it is merged into the stored payload, so a
  /// partial update never clears the calendar (which would stop every local write) or the name.
  Future<void> _applyUser(Map<String, dynamic> user) async {
    final stored = EntityCodec.decodeJson((await _state()).userPayload);
    final merged = {if (stored is Map) ...stored.cast<String, dynamic>(), ...user};
    final timezone = user['timezone'];
    final offset = user['day_start_offset_minutes'];
    await _updateState(
      SyncStateCompanion(
        userPayload: Value(jsonEncode(merged)),
        calendarTimezone: timezone is String ? Value(timezone) : const Value.absent(),
        calendarDayStartOffset: offset is int ? Value(offset) : const Value.absent(),
      ),
    );
  }

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

  /// Free or expired leases only: a crashed owner is recovered by expiry, never by its id (F3).
  Future<bool> _acquireLease() async {
    final taken = await db.customUpdate(
      'UPDATE sync_state SET lease_owner = ?, lease_until = ? '
      'WHERE id = 1 AND (lease_owner IS NULL OR lease_until < ?)',
      variables: [Variable(ownerId), Variable(_now + leaseDuration.inMilliseconds), Variable(_now)],
      updates: {db.syncState},
    );
    return taken == 1;
  }

  /// Extends the lease, or stops the run if another engine has taken it over.
  Future<void> _renewLease() async {
    final renewed = await db.customUpdate(
      'UPDATE sync_state SET lease_until = ? WHERE id = 1 AND lease_owner = ?',
      variables: [Variable(_now + leaseDuration.inMilliseconds), Variable(ownerId)],
      updates: {db.syncState},
    );
    if (renewed != 1) throw const _LeaseLost();
  }

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

class _LeaseLost implements Exception {
  const _LeaseLost();
}
