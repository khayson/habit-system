import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/database_opener.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:path/path.dart' as p;

import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 2b.1 gate: the engine against a scripted server (PHASE_2A1_REVIEW §5).
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
  });

  tearDown(() => phone.db.close());

  test('bootstraps, pushes a create and a tick, and confirms them', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);

    expect(await phone.sync(), SyncOutcome.completed);

    expect(server.habits.keys, [habit]);
    expect(server.logs.values.single['log_date'], '2026-05-28');
    final log = await phone.view.log(habit, '2026-05-28');
    expect((log.value, log.provisional, log.confirmedVersion), (1, false, 1));
    expect(await phone.outbox(), isEmpty, reason: 'acked rows are pruned once confirmed');
    expect((await phone.state()).cursor, 'c:${server.seq}');
  });

  test('sends the server calendar zone as captured_timezone, never the device zone', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);

    final rows = await phone.outbox();
    expect(rows.map((r) => r.capturedTimezone).toSet(), {'America/Los_Angeles'});
    expect(rows.last.localDateHint, '2026-05-28');
  });

  test('duplicate retry gives one log (server committed, response lost)', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await phone.sync(); // bootstrap + create + tick
    await phone.writer.setLogValue(habitId: habit, value: 0, at: DateTime.utc(2026, 5, 28, 18));
    server.crashAfterCommit = true;

    expect(await phone.sync(), SyncOutcome.offline);
    expect((await phone.outbox()).single.state, OutboxState.pending);

    expect(await phone.sync(), SyncOutcome.completed);
    expect(server.logs.length, 1);
    expect(server.logs.values.single['value'], 0);
    expect(server.sentMutationIds[server.sentMutationIds.length - 2], server.sentMutationIds.last);
  });

  test('a crash between server commit and ack application replays safely', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    var crash = true;
    final crashing = phone.engine(
      beforeApplyCommit: () async {
        if (crash) {
          crash = false;
          throw StateError('app killed');
        }
      },
    );

    await expectLater(crashing.run(), throwsStateError);
    expect((await phone.outbox()).map((r) => r.state).toSet(), {
      OutboxState.inFlight,
    }, reason: 'nothing applied');
    expect(server.logs.length, 1, reason: 'the server did commit');

    expect(await phone.sync(), SyncOutcome.completed);
    expect(server.logs.length, 1);
    expect((await phone.logs()).single.version, 1);
    expect(await phone.outbox(), isEmpty);
  });

  test('an interrupted pull replays safely: the cursor only moves with its changes', () async {
    final habit = await phone.habit();
    await phone.sync();
    final cursorBefore = (await phone.state()).cursor;
    // Another device ticks; the pull of that change is interrupted mid-apply.
    server.apply(_tick(habit, 'other-log', 1, base: 0));
    var crash = true;
    await expectLater(
      phone
          .engine(
            beforeApplyCommit: () async {
              if (crash) {
                crash = false;
                throw StateError('crash');
              }
            },
          )
          .run(),
      throwsStateError,
    );
    expect((await phone.state()).cursor, cursorBefore);
    expect(await phone.logs(), isEmpty);

    await phone.sync();
    expect((await phone.logs()).single.id, 'other-log');
    expect((await phone.state()).cursor, 'c:${server.seq}');
  });

  test(
    'delete vs queued edit: resource_deleted keeps the edit for review, no resurrection',
    () async {
      final habit = await phone.habit();
      await phone.writer.setLogValue(habitId: habit, value: 1);
      await phone.sync();
      final logId = server.logs.keys.single;
      server.apply(_delete(logId, habit, '2026-05-28', base: 1)); // another device deletes

      await phone.writer.setLogValue(
        habitId: habit,
        value: 0,
        at: DateTime.utc(2026, 5, 28, 18),
      ); // based on v1
      await phone.sync();

      final row = (await phone.outbox()).single;
      expect(row.state, OutboxState.needsAttention);
      expect(jsonDecode(row.lastError!)['code'], 'resource_deleted');
      expect(jsonDecode(row.payload)['value'], 0, reason: 'user data kept');
      expect(server.logs[logId]!['deleted_at'], isNotNull);
      expect((await phone.logs()).single.deletedAt, isNotNull, reason: 'tombstone pulled');
    },
  );

  test(
    'restore: logging a deleted day again sends the tombstone version and restores the row',
    () async {
      final habit = await phone.habit();
      await phone.writer.setLogValue(habitId: habit, value: 1);
      await phone.sync();
      final logId = server.logs.keys.single;
      server.apply(_delete(logId, habit, '2026-05-28', base: 1));
      await phone.sync(); // pull the tombstone (v2)

      await phone.writer.setLogValue(habitId: habit, value: 1, at: DateTime.utc(2026, 5, 28, 19));
      expect((await phone.outbox()).single.baseVersion, 2);
      await phone.sync();

      expect(server.logs[logId]!['deleted_at'], isNull);
      final confirmed = (await phone.logs()).single;
      expect((confirmed.id, confirmed.version, confirmed.deletedAt), (logId, 3, null));
    },
  );

  test('merged ids: the canonical entity_id is remapped on every local reference', () async {
    final habit = await phone.habit();
    await phone.sync();
    // Offline: tick, then delete the same day. Both rows carry the phone's own log id.
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await phone.writer.deleteLog(habitId: habit, date: LocalDate.parse('2026-05-28'));
    final localId = (await phone.outbox()).first.entityId;
    // Meanwhile another device ticked the same day first.
    server.apply(_tick(habit, 'server-log', 1, base: 0));

    expect(await phone.sync(), SyncOutcome.completed);

    expect(await phone.outbox(), isEmpty);
    expect(server.logs.keys, ['server-log']);
    expect(
      server.logs['server-log']!['deleted_at'],
      isNotNull,
      reason: 'the delete followed the remap / natural key',
    );
    final confirmed = (await phone.logs()).single;
    expect(confirmed.id, 'server-log');
    expect(confirmed.id, isNot(localId));
  });

  test('server_error blocks only its own entity, backs off, then recovers', () async {
    final h1 = await phone.habit();
    final h2 = await phone.habit();
    await phone.sync();
    final w1 = await phone.writer.setLogValue(habitId: h1, value: 1);
    await phone.writer.setLogValue(habitId: h2, value: 1);
    await phone.writer.setLogValue(
      habitId: h1,
      value: 1,
      at: DateTime.utc(2026, 5, 27, 18),
    ); // another day of h1
    server.serverErrorFor.add(w1.mutationId);

    await phone.sync();

    final blocked = (await phone.outbox()).singleWhere((r) => r.mutationId == w1.mutationId);
    expect(blocked.state, OutboxState.blocked);
    expect(blocked.attempts, 1);
    final waitSeconds = (blocked.nextAttemptAt! - phone.now.millisecondsSinceEpoch) / 1000;
    expect(waitSeconds, inInclusiveRange(48, 72), reason: '1 min with jitter');
    expect(jsonDecode(blocked.lastError!)['retryable'], isTrue);
    expect(server.logs.length, 2, reason: 'h2 and the other h1 day went through');

    // Not due yet: nothing is re-sent.
    await phone.sync();
    expect(server.sentMutationIds.last, isNot(contains(w1.mutationId)));

    server.serverErrorFor.clear();
    phone.now = phone.now.add(const Duration(minutes: 2));
    await phone.sync();
    expect(await phone.outbox(), isEmpty);
    expect(server.logs.length, 3);
  });

  test('a retryable failure is surfaced after 20 attempts but keeps retrying', () async {
    final h = await phone.habit();
    await phone.sync();
    final w = await phone.writer.setLogValue(habitId: h, value: 1);
    server.serverErrorFor.add(w.mutationId);

    for (var i = 0; i < 20; i++) {
      await phone.sync();
      phone.now = phone.now.add(const Duration(hours: 2));
    }

    final row = (await phone.outbox()).single;
    expect((row.state, row.attempts, row.surfaced), (OutboxState.blocked, 20, true));
  });

  test('dependency_pending waits, resumes when its parent is accepted', () async {
    final habit = await phone.habit();
    final tick = await phone.writer.setLogValue(habitId: habit, value: 1);
    final createId = (await phone.outbox()).first.mutationId;
    server.serverErrorFor.add(createId);

    await phone.sync();
    final rows = await phone.outbox();
    expect(rows.map((r) => r.state).toList(), [OutboxState.blocked, OutboxState.waiting]);

    server.serverErrorFor.clear();
    phone.now = phone.now.add(const Duration(minutes: 5));
    await phone.sync();
    expect(await phone.outbox(), isEmpty);
    expect(server.receipts.containsKey(tick.mutationId), isTrue);
  });

  test('parent rejected: its waiting logs become parent_rejected and keep their data', () async {
    final habit = await phone.habit(type: 'checklist', target: 3); // the server rejects the type
    await phone.writer.setLogValue(habitId: habit, value: 2);

    await phone.sync();

    final rows = await phone.outbox();
    expect(rows.map((r) => r.state).toSet(), {OutboxState.needsAttention});
    expect(jsonDecode(rows[0].lastError!)['code'], 'unsupported_type');
    expect(jsonDecode(rows[1].lastError!)['code'], 'parent_rejected');
    expect(jsonDecode(rows[1].payload)['value'], 2);
    // Never auto-resubmitted.
    final sent = server.sentMutationIds.length;
    await phone.sync();
    expect(server.sentMutationIds.skip(sent).expand((ids) => ids), isEmpty);
  });

  test('410 re-bootstraps and keeps the outbox', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    // e.g. the journal was pruned or the database restored.
    server.failNextSync.add(const SyncTransportException(SyncFailure.cursorExpired));

    expect(await phone.sync(), SyncOutcome.completed);

    expect(server.bootstrapCalls, 4, reason: 'two bootstraps of two pages each');
    expect(server.logs.length, 1, reason: 'the queued tick survived the re-bootstrap');
    expect(await phone.outbox(), isEmpty);
  });

  test('401: one refresh, then success', () async {
    phone.auth.refreshResult = RefreshResult.refreshed;
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.unauthorized));

    expect(await phone.sync(), SyncOutcome.completed);
    expect(phone.auth.refreshCalls, 1);
    expect(phone.auth.loggedOut, isFalse);
  });

  test('401 twice: logs out but keeps the database and its outbox', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    phone.auth.refreshResult = RefreshResult.rejected;
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.unauthorized));

    expect(await phone.sync(), SyncOutcome.loggedOut);
    expect(phone.auth.loggedOut, isTrue);
    expect((await phone.outbox()).map((r) => r.state).toSet(), {OutboxState.pending});
  });

  test('401 with the refresh unanswered: offline, still signed in, outbox kept', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    phone.auth.refreshResult = RefreshResult.unavailable;
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.unauthorized));

    expect(await phone.sync(), SyncOutcome.offline);
    expect(phone.auth.loggedOut, isFalse);
    expect((await phone.outbox()).map((r) => r.state).toSet(), {OutboxState.pending});
  });

  test('429 honours Retry-After and leaves rows pending', () async {
    await phone.sync();
    final habit = await phone.habit();
    server.failNextSync.add(
      const SyncTransportException(SyncFailure.rateLimited, retryAfter: Duration(seconds: 30)),
    );

    expect(await phone.sync(), SyncOutcome.rateLimited);
    expect((await phone.state()).nextSyncAt, phone.now.millisecondsSinceEpoch + 30000);
    expect((await phone.outbox()).single.entityId, habit);
    expect((await phone.outbox()).single.state, OutboxState.pending);
  });

  test('HTTP 413 sends smaller chunks until everything is through', () async {
    await phone.sync();
    for (var i = 0; i < 70; i++) {
      await phone.habit();
    }
    server.maxMutationsPerRequest = 30;

    expect(await phone.sync(), SyncOutcome.completed);
    expect(server.habits.length, 70);
    expect(
      server.sentMutationIds.where((ids) => ids.isNotEmpty).every((ids) => ids.length <= 30),
      isTrue,
    );
  });

  test('ack-level payload_too_large is permanent for that mutation (not HTTP 413)', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    final scripted = _ScriptedOnce(
      server,
      (m) => {
        'mutation_id': m['mutation_id'],
        'status': 'rejected',
        'duplicate': false,
        'entity': m['entity'],
        'entity_id': m['entity_id'],
        'error': {'code': 'payload_too_large', 'message': 'This change is too large.'},
      },
    );

    await phone.engine(transport: scripted).run();
    final row = (await phone.outbox()).single;
    expect(row.state, OutboxState.needsAttention);
    expect(row.attempts, 0);
  });

  test('two engines on one database file run one at a time (lease)', () async {
    final dir = Directory.systemTemp.createTempSync('habit_lease_');
    final file = File(p.join(dir.path, 'account.sqlite'));
    final a = await Device(
      server,
      executor: NativeDatabase(file, setup: configureConnection),
    ).init();
    final b = Device(server, executor: NativeDatabase(file, setup: configureConnection));
    server.gate = Completer<void>();

    final first = a.engine(owner: 'engine-a').run();
    while (server.bootstrapCalls == 0 && server.syncCalls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Bootstrap does not wait on the gate; wait until engine A is blocked inside /sync.
    while (server.syncCalls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(await b.engine(owner: 'engine-b').run(), SyncOutcome.busy);

    server.gate!.complete();
    expect(await first, SyncOutcome.completed);
    expect(
      await b.engine(owner: 'engine-b').run(),
      SyncOutcome.completed,
      reason: 'the lease was released',
    );
    await a.db.close();
    await b.db.close();
  });

  test('unknown habit types, unknown fields and unknown entities survive a round trip', () async {
    final unknownHabit = {
      'id': 'future-habit',
      'name': 'Morning checklist',
      'type': 'checklist',
      'unit': null,
      'category': 'health',
      'target_value': 3,
      'frequency_type': 'daily',
      'frequency_config': <String, Object>{},
      'start_local_date': '2026-05-01',
      'archived_at': null,
      'version': 4,
      'definition_version': 2,
      'definitions': <Object>[],
      'active_ranges': <Object>[],
      'colour': 'teal',
      'reminder_hint': {
        'at': '07:30',
        'tags': ['a', 'b'],
      },
    };
    server.extraBootstrapHabits.add(unknownHabit);
    // A newer server's collection inside a bootstrap page, and a later change of an unknown type.
    server.extraBootstrapCollections['weekly_reviews'] = [
      {'id': 'wr-0', 'version': 1, 'week_start': '2026-05-18'},
    ];
    await phone.sync();
    server.journalOpaque('weekly_review', 'wr-1', {
      'id': 'wr-1',
      'week_start': '2026-05-25',
      'reflection': 'ok',
    });
    await phone.sync();

    final stored = await (phone.db.select(
      phone.db.habits,
    )..where((h) => h.id.equals('future-habit'))).getSingle();
    expect(
      EntityCodec.habitPayload(stored),
      unknownHabit,
      reason: 'unknown fields are re-emitted untouched',
    );
    final views = await phone.view.habits();
    expect(views.single.knownType, isFalse);
    final opaque = {
      for (final o in await phone.db.select(phone.db.opaqueEntities).get())
        '${o.entityType}/${o.entityId}': jsonDecode(o.payload),
    };
    expect(opaque.keys.toSet(), {'weekly_reviews/wr-0', 'weekly_review/wr-1'});
    expect((opaque['weekly_review/wr-1'] as Map)['reflection'], 'ok');
  });
}

Map<String, dynamic> _tick(String habitId, String logId, Object value, {required int base}) => {
  'mutation_id': 'other-${DateTime.now().microsecondsSinceEpoch}-$logId',
  'entity': 'habit_log',
  'entity_id': logId,
  'operation': 'log.set_value',
  'base_version': base,
  'occurred_at': '2026-05-28T17:00:00Z',
  'captured_timezone': 'America/Los_Angeles',
  'local_date_hint': '2026-05-28',
  'payload': {'habit_id': habitId, 'value': value},
};

Map<String, dynamic> _delete(String logId, String habitId, String date, {required int base}) => {
  'mutation_id': 'other-delete-${DateTime.now().microsecondsSinceEpoch}',
  'entity': 'habit_log',
  'entity_id': logId,
  'operation': 'log.delete',
  'base_version': base,
  'occurred_at': '2026-05-28T17:10:00Z',
  'payload': {'habit_id': habitId, 'log_date': date},
};

/// Answers the next /sync with a scripted ack per mutation, then defers to the real fake server.
class _ScriptedOnce implements SyncTransport {
  _ScriptedOnce(this.server, this.ack);
  final FakeSyncServer server;
  final Map<String, dynamic> Function(Map<String, Object?> mutation) ack;
  bool used = false;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    if (used || mutations.isEmpty) {
      return server.sync(
        deviceId: deviceId,
        cursor: cursor,
        pullLimit: pullLimit,
        mutations: mutations,
        capabilities: capabilities,
      );
    }
    used = true;
    return SyncPage(
      acks: [for (final m in mutations) ack(m)],
      changes: const [],
      nextCursor: cursor ?? 'c:0',
      hasMore: false,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}
