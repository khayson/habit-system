import 'package:flutter_test/flutter_test.dart';
import 'package:habit/sync/ack_watch.dart';
import 'package:habit/sync/sync_engine.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 5.2c (A46): the engine's ack watch. Summaries are published after the apply
/// transaction commits; a screen waits for one mutation's ack, with a timeout, and can cancel.
void main() {
  setUpAll(Device.loadZones);

  group('ack_xp_delta_wire', () {
    final fixture = contractFixture('sync/ack_xp_delta_wire.json');

    test('declares the Dart suite', () => expect(fixture['suites'], ['dart']));

    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final ack = materialize(c['ack']) as Map<String, dynamic>;
        final summary = AckSummary.fromAck(ack)!;
        final expected = c['expect'] as Map<String, dynamic>;
        expect(
          (summary.mutationId, summary.status, summary.xpDelta),
          (ack['mutation_id'], expected['status'], expected['xp_delta']),
        );
      });
    }
  });

  test('a non-final status is not a summary', () {
    expect(AckSummary.fromAck({'mutation_id': 'm', 'status': 'dependency_pending'}), isNull);
    expect(AckSummary.fromAck({'status': 'accepted'}), isNull, reason: 'no mutation id');
  });

  test('a known ack answers at once; an unknown one when it is published', () async {
    final watch = AckWatch();
    watch.publish(const AckSummary('m1', 'accepted', 10));
    expect((await watch.waitFor('m1', const Duration(seconds: 6)).result)?.xpDelta, 10);

    final wait = watch.waitFor('m2', const Duration(seconds: 6));
    watch.publish(const AckSummary('m2', 'conflict', null));
    expect((await wait.result)?.status, 'conflict');
  });

  // testWidgets runs on fake time and fails if a timer is left pending.
  testWidgets('the timeout answers null; a cancelled wait never completes later', (tester) async {
    final watch = AckWatch();
    AckSummary? timedOut = const AckSummary('x', 'x', null);
    watch.waitFor('m1', const Duration(seconds: 6)).result.then((s) => timedOut = s);
    await tester.pump(const Duration(seconds: 5));
    expect(timedOut?.mutationId, 'x', reason: 'still waiting');
    await tester.pump(const Duration(seconds: 1));
    expect(timedOut, isNull);

    var completed = false;
    final cancelled = watch.waitFor('m2', const Duration(seconds: 6));
    cancelled.result.then((_) => completed = true);
    cancelled.cancel();
    watch.publish(const AckSummary('m2', 'accepted', 10));
    await tester.pump(const Duration(seconds: 10));
    expect(completed, isFalse);
  });

  test('keeps the last 50 summaries', () async {
    final watch = AckWatch();
    for (var i = 0; i < 51; i++) {
      watch.publish(AckSummary('m$i', 'accepted', i));
    }
    expect(watch.known('m0'), isNull, reason: 'evicted');
    expect(watch.known('m1')?.xpDelta, 1);
    expect(watch.known('m50')?.xpDelta, 50);
  });

  group('the engine', () {
    late FakeSyncServer server;
    late Device phone;

    setUp(() async {
      server = FakeSyncServer();
      phone = await Device(server).init();
      await phone.sync();
    });

    tearDown(() => phone.db.close());

    test('publishes after the apply transaction commits', () async {
      final watch = AckWatch();
      final habit = await phone.habit();
      await phone.engine(ackWatch: watch).run();
      final write = await phone.writer.setLogValue(habitId: habit, value: 1);

      await phone.engine(ackWatch: watch).run();

      expect(watch.known(write.mutationId)?.status, 'accepted');
    });

    test('a transaction that rolls back publishes nothing', () async {
      final watch = AckWatch();
      final habit = await phone.habit();
      await phone.engine(ackWatch: watch).run();
      final write = await phone.writer.setLogValue(habitId: habit, value: 1);

      final outcome = await phone
          .engine(ackWatch: watch, beforeApplyCommit: () async => throw StateError('lease lost'))
          .run();

      expect(outcome, SyncOutcome.failed);

      expect(watch.known(write.mutationId), isNull);
    });
  });
}
