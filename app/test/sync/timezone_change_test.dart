import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 3.2a, screen 04: profile.set_timezone through the writer, coalescing, the engine's
/// rebase-once rule, and entity_read_only never retried.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    await phone.sync();
  });

  tearDown(() => phone.db.close());

  Future<List<String>> entries() async => [
    for (final e in await phone.db.select(phone.db.calendarEntries).get()) e.timezone,
  ];

  test('queued, then acked: the pending entry arrives; the zone in force cancels it', () async {
    await phone.writer.setTimezone('Europe/Paris');
    final row = (await phone.outbox()).single;
    expect(
      (row.entity, row.entityId, row.operation, row.baseVersion),
      ('user', 'user-1', 'profile.set_timezone', 1),
    );
    expect(jsonDecode(row.payload), {'timezone': 'Europe/Paris'});

    await phone.sync();
    expect(await entries(), ['America/Los_Angeles', 'Europe/Paris']);
    expect(await phone.outbox(), isEmpty, reason: 'acked and reflected in the user: pruned');

    await phone.writer.setTimezone('America/Los_Angeles');
    expect((await phone.outbox()).last.baseVersion, 2, reason: 'the confirmed user version');
    await phone.sync();
    expect(await entries(), ['America/Los_Angeles']);
  });

  test('unsent changes coalesce: the latest choice wins', () async {
    await phone.writer.setTimezone('Europe/Paris');
    await phone.writer.setTimezone('Asia/Tokyo');

    final rows = await phone.outbox();
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.payload), {'timezone': 'Asia/Tokyo'});
  });

  test('a version_conflict rebases once, as a new mutation, and then succeeds', () async {
    server.bumpUserVersion(); // another device changed the profile; this one has not pulled
    await phone.writer.setTimezone('Europe/Paris');
    final first = (await phone.outbox()).single.mutationId;

    await phone.sync();

    expect(server.pendingZone, 'Europe/Paris');
    final sent = server.sentMutationIds.expand((ids) => ids).toList();
    expect(sent, hasLength(2));
    expect(sent.first, first);
    expect(sent.last, isNot(first), reason: 'the conflict has a receipt; a new id is needed');
    final rows = await phone.outbox();
    expect(rows.every((r) => r.state != OutboxState.needsAttention), isTrue);
  });

  test('a second conflict goes to needs-attention', () async {
    await phone.writer.setTimezone('Europe/Paris');

    await phone.engine(transport: _AlwaysStale(server)).run();

    final row = (await phone.outbox()).single;
    expect(row.state, OutboxState.needsAttention);
    expect(jsonDecode(row.lastError!)['code'], 'version_conflict');
    expect(server.pendingZone, isNull);
  });

  test('entity_read_only goes to needs-attention even when marked retryable', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);

    await phone.engine(transport: _ReadOnlyOnce(server)).run();

    final row = (await phone.outbox()).single;
    expect(row.state, OutboxState.needsAttention);
    expect(jsonDecode(row.lastError!)['code'], 'entity_read_only');
  });
}

/// Another device changes the profile before every push, so every base is stale.
class _AlwaysStale implements SyncTransport {
  _AlwaysStale(this.server);
  final FakeSyncServer server;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) {
    if (mutations.isNotEmpty) server.bumpUserVersion();
    return server.sync(
      deviceId: deviceId,
      cursor: cursor,
      pullLimit: pullLimit,
      mutations: mutations,
      capabilities: capabilities,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}

/// Answers the first push with entity_read_only (wrongly) marked retryable.
class _ReadOnlyOnce implements SyncTransport {
  _ReadOnlyOnce(this.server);
  final FakeSyncServer server;
  var _used = false;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    if (_used || mutations.isEmpty) {
      return server.sync(
        deviceId: deviceId,
        cursor: cursor,
        pullLimit: pullLimit,
        mutations: mutations,
        capabilities: capabilities,
      );
    }
    _used = true;
    return SyncPage(
      acks: [
        {
          'mutation_id': mutations.first['mutation_id'],
          'status': 'rejected',
          'duplicate': false,
          'entity': mutations.first['entity'],
          'entity_id': mutations.first['entity_id'],
          'error': {'code': 'entity_read_only', 'message': 'x', 'retryable': true},
        },
      ],
      changes: const [],
      nextCursor: cursor ?? 'c:0',
      hasMore: false,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}
