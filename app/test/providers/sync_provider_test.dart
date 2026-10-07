import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/providers/sync_provider.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// The 2b.2 sync triggers, all through the single-flight engine.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late StreamController<bool> online;
  late int refreshes;
  late SyncProvider sync;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    online = StreamController<bool>();
    refreshes = 0;
    sync = SyncProvider(
      engine: phone.engine(),
      refreshIfStale: () async => refreshes++,
      connectivity: online.stream,
      debounce: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    sync.dispose();
    await online.close();
    await phone.db.close();
  });

  Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 120));

  test('a burst of local writes makes one sync after the debounce', () async {
    final habit = await phone.habit();
    for (var i = 0; i < 5; i++) {
      await phone.writer.setLogValue(habitId: habit, value: i.isEven ? 1 : 0);
      sync.scheduleAfterWrite();
    }
    expect(server.syncCalls, 0, reason: 'nothing before the debounce');

    await idle();

    expect(server.bootstrapCalls, 2, reason: 'one bootstrap');
    expect(server.sentMutationIds.where((ids) => ids.isNotEmpty), hasLength(1));
    expect(sync.lastOutcome, SyncOutcome.completed);
  });

  test('foreground refreshes an old token first, then syncs', () async {
    await sync.onForeground();
    expect(refreshes, 1);
    expect(sync.lastOutcome, SyncOutcome.completed);
  });

  test('connectivity regained syncs at once, skipping the failure backoff', () async {
    await phone.habit();
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.network));
    online.add(false);
    await sync.sync();
    expect(sync.offline, isTrue);

    online.add(true);
    await idle();

    expect(sync.lastOutcome, SyncOutcome.completed, reason: 'forced past the 30 s backoff');
    expect(sync.offline, isFalse);
    expect(server.habits, hasLength(1));
  });

  test('offline is what the last attempt found, not just the radio state', () async {
    online.add(true);
    server.failNextBootstrap.add(const SyncTransportException(SyncFailure.network));
    await sync.sync(force: true);
    expect(sync.offline, isTrue, reason: 'connected to Wi-Fi is not proof of a connection');
  });
}
