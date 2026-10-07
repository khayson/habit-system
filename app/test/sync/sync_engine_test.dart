import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/database_opener.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:habit/data/local_mutation_service.dart';
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

  test('F1: a write racing the claim is sent or queued, never lost', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    Future<LocalWrite>? racing;
    final engine = phone.engine(
      betweenSelectAndMark: () async {
        // A tap from outside the engine (root zone, not this transaction): it must wait for
        // the claim and must not edit a row being sent.
        racing ??= Zone.root.run(() => phone.writer.setLogValue(habitId: habit, value: 0));
      },
    );

    await engine.run();
    final write = await racing!;

    expect(write.coalesced, isFalse, reason: 'the claimed row was no longer pending');
    // The new row went out in a later round of the same run.
    expect(server.logs.values.single['value'], 0, reason: 'the latest tap reaches the server');
    expect((await phone.logs()).single.value, '0');
    expect(await phone.outbox(), isEmpty);
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

    phone.now = phone.now.add(const Duration(minutes: 1)); // past the backoff
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

    expect(await crashing.run(), SyncOutcome.failed);
    final rows = await phone.outbox();
    expect(rows.map((r) => (r.state, r.ackVersion)).toSet(), {
      (OutboxState.pending, null),
    }, reason: 'nothing applied; ready to resend');
    expect(jsonDecode((await phone.state()).lastError!)['code'], 'sync_failed');
    expect(server.logs.length, 1, reason: 'the server did commit');

    phone.now = phone.now.add(const Duration(minutes: 1));
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
    final outcome = await phone
        .engine(
          beforeApplyCommit: () async {
            if (crash) {
              crash = false;
              throw StateError('crash');
            }
          },
        )
        .run();
    expect(outcome, SyncOutcome.failed);
    expect((await phone.state()).cursor, cursorBefore);
    expect(await phone.logs(), isEmpty);

    phone.now = phone.now.add(const Duration(minutes: 1));
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

  test('F5: a background engine never refreshes; it reports and keeps the session', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.unauthorized));
    final background = SyncEngine(
      db: phone.db,
      transport: server,
      auth: const BackgroundAuthSession(),
      capabilities: const ['binary'],
      clock: () => phone.now,
    );

    expect(await background.run(), SyncOutcome.offline);
    expect(jsonDecode((await phone.state()).lastError!)['code'], 'reauth_needed');
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

  group('F6: backoff is enforced', () {
    test('no request before Retry-After, then normal service', () async {
      await phone.sync();
      server.failNextSync.add(
        const SyncTransportException(SyncFailure.rateLimited, retryAfter: Duration(seconds: 30)),
      );
      expect(await phone.sync(), SyncOutcome.rateLimited);
      final calls = server.syncCalls;

      expect(await phone.sync(), SyncOutcome.rateLimited);
      expect(await phone.sync(force: true), SyncOutcome.rateLimited, reason: 'never bypassed');
      expect(server.syncCalls, calls);

      phone.now = phone.now.add(const Duration(seconds: 31));
      expect(await phone.sync(), SyncOutcome.completed);
      expect((await phone.state()).nextSyncAt, isNull);
    });

    test('5xx and offline back off 30 s doubling to 15 min; success clears it', () async {
      await phone.sync();
      final waits = <int>[];
      for (var i = 0; i < 8; i++) {
        server.failNextSync.add(const SyncTransportException(SyncFailure.server));
        expect(await phone.sync(force: true), SyncOutcome.backoff);
        final state = await phone.state();
        waits.add(((state.backoffUntil! - phone.now.millisecondsSinceEpoch) / 1000).round());
        expect(state.consecutiveFailures, i + 1);
      }
      for (final (i, wait) in waits.indexed) {
        final base = [30, 60, 120, 240, 480, 900, 900, 900][i];
        expect(wait, inInclusiveRange(base * 0.8 - 1, min(900, base * 1.2) + 1), reason: 'try $i');
      }

      final calls = server.syncCalls;
      expect(await phone.sync(), SyncOutcome.backoff);
      expect(server.syncCalls, calls, reason: 'nothing sent inside the backoff');

      phone.now = phone.now.add(const Duration(minutes: 16));
      expect(await phone.sync(), SyncOutcome.completed);
      final state = await phone.state();
      expect((state.consecutiveFailures, state.backoffUntil), (0, null));
    });

    test('force (connectivity regained, Sync now) skips the failure backoff', () async {
      await phone.sync();
      server.failNextSync.add(const SyncTransportException(SyncFailure.network));
      expect(await phone.sync(), SyncOutcome.offline);
      expect(await phone.sync(), SyncOutcome.backoff);
      expect(await phone.sync(force: true), SyncOutcome.completed);
    });
  });

  test('F7: three whole-request 4xx pause sync; nothing is dropped; success resumes', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    const refused = SyncTransportException(SyncFailure.requestRejected, code: 'validation_failed');

    server.failNextSync.add(refused);
    expect(await phone.sync(force: true), SyncOutcome.backoff);
    server.failNextSync.add(refused);
    expect(await phone.sync(force: true), SyncOutcome.backoff);
    expect((await phone.state()).status, SyncStatus.active);
    server.failNextSync.add(refused);
    expect(await phone.sync(force: true), SyncOutcome.paused);

    var state = await phone.state();
    expect(
      (state.status, state.statusCode, state.requestRejections),
      (SyncStatus.paused, 'validation_failed', 3),
    );
    expect((await phone.outbox()).single.state, OutboxState.pending, reason: 'nothing dropped');

    expect(await phone.sync(force: true), SyncOutcome.completed);
    state = await phone.state();
    expect((state.status, state.statusCode, state.requestRejections), (SyncStatus.active, null, 0));
    expect(server.logs, hasLength(1));
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

  group('F2: undecodable server data never wedges the device', () {
    Map<String, dynamic> habitChange(String id, Object? version) => {
      'seq': 9,
      'entity': 'habit',
      'id': id,
      'operation': 'upsert',
      'version': version,
      'payload': {'id': id, 'name': 'Read', 'type': 'binary', 'version': version},
    };

    test('a null payload and a string version are kept raw; the rest applies', () async {
      await phone.sync();
      final page = SyncPage.fromJson({
        'acks': <Object>[],
        'changes': [
          {'seq': 7, 'entity': 'habit_log', 'id': 'log-null', 'version': 1, 'payload': null},
          habitChange('h-string', '2'),
          habitChange('h-ok', 1),
          'not even an object',
        ],
        'next_cursor': 'c:9',
        'has_more': false,
      });

      expect(await phone.engine(transport: _PageOnce(server, page)).run(), SyncOutcome.completed);

      expect((await phone.db.select(phone.db.habits).get()).map((h) => h.id), ['h-ok']);
      final opaque = await phone.db.select(phone.db.opaqueEntities).get();
      expect(opaque.map((o) => o.entityType).toSet(), {
        'undecodable:habit_log',
        'undecodable:habit',
        'undecodable:unknown',
      });
      expect(opaque.firstWhere((o) => o.entityId == 'h-string').payload, contains('"version":"2"'));
      expect((await phone.state()).cursor, 'c:9', reason: 'the cursor still advances');
    });

    test('a page without next_cursor applies its changes and keeps the cursor', () async {
      await phone.sync();
      final before = (await phone.state()).cursor;
      final page = SyncPage.fromJson({
        'acks': <Object>[],
        'changes': [habitChange('h-ok', 1)],
        'has_more': false,
      });

      expect(await phone.engine(transport: _PageOnce(server, page)).run(), SyncOutcome.completed);

      expect((await phone.db.select(phone.db.habits).get()).map((h) => h.id), ['h-ok']);
      final state = await phone.state();
      expect(state.cursor, before);
      expect(jsonDecode(state.lastError!)['code'], 'missing_next_cursor');

      expect(await phone.sync(), SyncOutcome.completed);
      expect((await phone.state()).lastError, isNull, reason: 'a good page clears it');
    });

    test('an unreadable ack counts as no ack; the row is resent and answered', () async {
      final habit = await phone.habit();
      await phone.sync();
      await phone.writer.setLogValue(habitId: habit, value: 1);
      final scripted = _ScriptedOnce(
        server,
        (m) => {'mutation_id': m['mutation_id'], 'status': 'accepted', 'version': 'one'},
      );

      expect(await phone.engine(transport: scripted).run(), SyncOutcome.completed);
      expect(server.logs.values.single['value'], 1);
      expect(await phone.outbox(), isEmpty);
    });

    test('a bootstrap whose last page has no sync_cursor fails the run, not loops', () async {
      final fresh = Device(server);
      await initAccountState(fresh.db, userId: 'u', deviceId: fresh.deviceId, user: server.user);
      final broken = _BootstrapWithoutCursor(server);

      expect(await fresh.engine(transport: broken).run(), SyncOutcome.failed);
      expect(broken.calls, 1);
      expect((await fresh.state()).cursor, isNull);
      await fresh.db.close();
    });
  });

  test('F3: concurrent run() calls on one engine share one request sequence', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    final engine = phone.engine();

    final outcomes = await Future.wait([engine.run(), engine.run(), engine.run()]);

    expect(outcomes, everyElement(SyncOutcome.completed));
    expect(server.bootstrapCalls, 2, reason: 'one bootstrap of two pages');
    expect(server.sentMutationIds.where((ids) => ids.isNotEmpty), hasLength(1));
  });

  test('F3: a run whose lease was taken over stops instead of racing', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    server.gate = Completer<void>();
    final slow = phone.engine(owner: 'slow');
    final first = slow.run();
    while (server.syncCalls < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // The slow engine's lease expires; another takes over.
    phone.now = phone.now.add(const Duration(minutes: 5));
    await phone.db.customStatement(
      "UPDATE sync_state SET lease_owner = 'other', lease_until = 9999999999999",
    );
    server.gate!.complete();

    expect(await first, SyncOutcome.busy);
    expect((await phone.state()).leaseOwner, 'other', reason: 'the new owner keeps its lease');
  });

  group('F4: base versions come from acks, never predictions', () {
    test('a no-op ack followed by another queued write is accepted', () async {
      final habit = await phone.habit();
      await phone.writer.setLogValue(habitId: habit, value: 1);
      await phone.sync(); // confirmed v1, value 1
      await phone.writer.setLogValue(habitId: habit, value: 1, at: DateTime.utc(2026, 5, 28, 18));
      server.gate = Completer<void>();
      final calls = server.syncCalls;
      final run = phone.sync();
      while (server.syncCalls == calls) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // The no-op is in flight; the next tap queues behind it.
      await phone.writer.setLogValue(habitId: habit, value: 0, at: DateTime.utc(2026, 5, 28, 19));
      server.gate!.complete();

      expect(await run, SyncOutcome.completed);
      expect(server.logs.values.single['value'], 0);
      expect(server.logs.values.single['version'], 2, reason: 'the no-op did not bump');
      expect(await phone.outbox(), isEmpty, reason: 'no false conflict');
    });

    test('three queued rows for one day converge', () async {
      final habit = await phone.habit();
      await phone.sync();
      Future<void> queue(int value, int hour) async {
        await phone.writer.setLogValue(
          habitId: habit,
          value: value,
          at: DateTime.utc(2026, 5, 28, hour),
        );
        // Mark it sent so the next write cannot coalesce into it.
        await phone.db.customStatement("UPDATE outbox SET state = 'in_flight'");
      }

      await queue(1, 16);
      await queue(0, 17);
      await queue(1, 18);
      expect((await phone.outbox()).map((r) => r.baseVersion), [0, 0, 0]);

      expect(await phone.sync(), SyncOutcome.completed); // recovers in-flight rows first
      final log = server.logs.values.single;
      expect((log['value'], log['version']), (1, 3));
      expect((await phone.logs()).single.version, 3);
      expect(await phone.outbox(), isEmpty);
      expect(
        server.sentMutationIds.where((ids) => ids.isNotEmpty).every((ids) => ids.length == 1),
        isTrue,
        reason: 'one row per habit-day per request',
      );
    });
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

/// Answers the next /sync with [page], then defers to the fake server.
class _PageOnce implements SyncTransport {
  _PageOnce(this.server, this.page);
  final FakeSyncServer server;
  final SyncPage page;
  bool used = false;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    if (used) {
      return server.sync(
        deviceId: deviceId,
        cursor: cursor,
        pullLimit: pullLimit,
        mutations: mutations,
        capabilities: capabilities,
      );
    }
    used = true;
    return page;
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}

/// A server whose single bootstrap page ends without a sync cursor.
class _BootstrapWithoutCursor implements SyncTransport {
  _BootstrapWithoutCursor(this.server);
  final FakeSyncServer server;
  int calls = 0;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) => throw StateError('not reached');

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) async {
    calls++;
    return BootstrapPage.fromJson({'habits': <Object>[], 'has_more': false});
  }
}
