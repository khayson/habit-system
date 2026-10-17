import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/conflicts.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 5.2b: profile.set_auto_freeze through the writer (A42), coalescing, the provisional
/// overlay on ProfileView, and the engine's rebase-once rule (A45).
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

  ProfileView view() => ProfileView(phone.db, filesRoot: '/files');

  test('one row on the user entity, on the confirmed version', () async {
    await phone.writer.setAutoFreeze(true);

    final row = (await phone.outbox()).single;
    expect(
      (row.entity, row.entityId, row.operation, row.baseVersion),
      ('user', 'user-1', 'profile.set_auto_freeze', 1),
    );
    expect(jsonDecode(row.payload), {'enabled': true});
  });

  test('unsent changes coalesce: the latest choice wins and keeps its base', () async {
    await phone.writer.setAutoFreeze(true);
    server.bumpUserVersion();
    await phone.writer.setAutoFreeze(false);

    final rows = await phone.outbox();
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.payload), {'enabled': false});
    expect(rows.single.baseVersion, 1);
  });

  test('the overlay shows the queued choice; after the ack the confirmed one', () async {
    expect((await view().load())!.autoFreeze, isFalse);

    await phone.writer.setAutoFreeze(true);
    final queued = (await view().load())!;
    expect(
      (queued.autoFreeze, queued.autoFreezeQueued, queued.autoFreezeNeedsAttention),
      (true, true, false),
    );
    final confirmed = jsonDecode((await phone.state()).userPayload!) as Map;
    expect(confirmed['auto_freeze'], isFalse, reason: 'the overlay never writes the confirmed row');

    await phone.sync();
    final synced = (await view().load())!;
    expect((synced.autoFreeze, synced.autoFreezeQueued), (true, false));
    expect(server.autoFreeze, isTrue);
  });

  test('a version_conflict rebases once, as a new mutation, on the named version (A45)', () async {
    server.bumpUserVersion(); // a photo or another device moved the user version
    await phone.writer.setAutoFreeze(true);
    final first = (await phone.outbox()).single.mutationId;

    await phone.sync();

    expect(server.autoFreeze, isTrue);
    final sent = server.sentMutationIds.expand((ids) => ids).toList();
    expect(sent, hasLength(2));
    expect(sent.first, first);
    expect(sent.last, isNot(first), reason: 'the conflict has a receipt; a new id is needed');
    expect((await phone.outbox()).every((r) => r.state != OutboxState.needsAttention), isTrue);
  });

  test('a second conflict goes to needs attention, discard only', () async {
    await phone.writer.setAutoFreeze(true);

    await phone.engine(transport: _AlwaysStale(server)).run();

    final row = (await phone.outbox()).single;
    expect(row.state, OutboxState.needsAttention);
    expect(jsonDecode(row.lastError!)['code'], 'version_conflict');
    expect(conflictKindOf('version_conflict', row.entity), ConflictKind.other);
    expect(reviewable(row), isFalse);
    expect(server.autoFreeze, isFalse);
    expect((await view().load())!.autoFreezeNeedsAttention, isTrue);
  });

  test('a profile edit and the switch queued together both apply, nothing for the user', () async {
    await phone.writer.updateProfile(name: 'Maya Chen', city: 'Accra', countryCode: 'GH');
    await phone.writer.setAutoFreeze(true);

    await phone.sync();

    expect((server.name, server.city, server.autoFreeze), ('Maya Chen', 'Accra', true));
    expect((await phone.outbox()).every((r) => r.state == OutboxState.acked), isTrue);
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
