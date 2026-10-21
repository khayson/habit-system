import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 5.2c (A46): the save screens wait for the ack of a save that completed the day and
/// open 35 / 06 only for an accepted ack with xp_delta above 0. Fake time: never a real 6 s.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late RewardingTransport transport;
  late AccountContext account;

  Future<String> seed(
    WidgetTester tester, {
    String type = 'quantity',
    Object target = '2.000',
    String? unit = 'L',
    String name = 'Water',
    StreamController<bool>? connectivity,
  }) async {
    useTallPhone(tester);
    server = FakeSyncServer();
    transport = RewardingTransport(server);
    account = (await tester.runAsync(
      () => testAccount(server, transport: transport, connectivity: connectivity?.stream),
    ))!;
    late String id;
    await tester.runAsync(() async {
      id = await account.writer.createHabitUnchecked(
        name: name,
        type: type,
        target: target,
        unit: unit,
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      );
    });
    await syncNow(tester, account);
    transport.calls = 0;
    return id;
  }

  Future<void> openAmount(WidgetTester tester, String id) async {
    await tester.pumpWidget(testApp(initial: '/habits/$id/add', account: account));
    await settle(tester);
  }

  /// The engine runs inside the widget zone here (the save screen asks for the sync): let real
  /// I/O and short fake timers both move, in steps well under the 6-second wait.
  Future<void> drive(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> save(WidgetTester tester, String amount) async {
    await tester.enterText(find.byKey(const ValueKey('amount-field')), amount);
    await tester.pump();
    await tester.tap(find.textContaining(RegExp(r'^Add \d')));
    await drive(tester);
  }

  bool onToday() => find.textContaining('habits complete').evaluate().isNotEmpty;

  testWidgets('35: an at-target save and an ack of +10 open the completion screen', (tester) async {
    final handle = tester.ensureSemantics();
    final id = await seed(tester);
    await openAmount(tester, id);

    await save(tester, '2');
    await drive(tester);

    expect(find.text('That counts.'), findsOneWidget);
    expect(find.text('Water complete'), findsOneWidget);
    expect(tester.getSemantics(find.text('Water complete')).flagsCollection.isHeader, isTrue);
    expect(find.text('2 L logged today'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('10 XP earned'), findsOneWidget);
    expect(find.text('Level 13'), findsOneWidget);
    expect(find.text('1,250 XP total'), findsOneWidget);
    expect(find.text('50 / 100 XP toward Level 14'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Level 13, 1,250 XP total, 50 of 100 XP toward Level 14'),
      findsOneWidget,
    );
    expect(find.text('Missed days never erase what you have learned.'), findsOneWidget);
    expect(find.text('Today'), findsNothing, reason: 'outside the shell: no bottom bar');

    await tester.tap(find.text('Back to today'));
    await drive(tester);
    expect(onToday(), isTrue);
    handle.dispose();
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  for (final (what, delta, status) in <(String, int?, String)>[
    ('an ack without xp_delta', null, 'accepted'),
    ('an ack of -10', -10, 'accepted'),
    ('an ack of 0', 0, 'accepted'),
    ('a conflict', null, 'conflict'),
  ]) {
    testWidgets('$what leaves as before', (tester) async {
      final id = await seed(tester);
      transport
        ..xpDelta = delta
        ..status = status;
      await openAmount(tester, id);

      await save(tester, '2');
      await settle(tester);

      expect(find.text('That counts.'), findsNothing);
      expect(onToday(), isTrue);
      await drive(tester, rounds: 40); // let a debounced background sync finish first
      await tearDownApp(tester, account);
    });
  }

  testWidgets('offline: leaves at once, no wait, no timers left', (tester) async {
    final online = connectivityController();
    final id = await seed(tester, connectivity: online);
    online.add(false);
    await tester.pump();
    await openAmount(tester, id);

    await save(tester, '2');

    expect(onToday(), isTrue);
    expect(find.text('Saved on this device. Confirming…'), findsNothing);
    expect(transport.calls, 0, reason: 'nothing forced; the debounce is the usual one');
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
    await online.close();
  });

  testWidgets('the 6-second timeout leaves; the line shows while waiting', (tester) async {
    final id = await seed(tester);
    transport.hold = Completer<void>();
    await openAmount(tester, id);

    await save(tester, '2'); // 2 s of fake time
    expect(find.text('Saved on this device. Confirming…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(onToday(), isFalse, reason: 'still waiting');
    await tester.pump(const Duration(seconds: 1));
    await drive(tester);

    expect(onToday(), isTrue);
    expect(find.text('That counts.'), findsNothing);
    transport.hold!.complete();
    await drive(tester);
    expect(find.text('That counts.'), findsNothing, reason: 'a late ack opens nothing');
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  testWidgets('while confirming, the preview keeps its text from the save (5.2c L2)', (
    tester,
  ) async {
    final id = await seed(tester);
    transport.hold = Completer<void>();
    await openAmount(tester, id);
    await tester.enterText(find.byKey(const ValueKey('amount-field')), '2');
    await tester.pump();
    expect(find.text('2 / 2 L'), findsOneWidget, reason: 'the preview before saving');

    await save(tester, '2'); // the local total is now 2 L underneath

    expect(find.text('Saved on this device. Confirming…'), findsOneWidget);
    expect(find.text('2 / 2 L'), findsOneWidget, reason: 'unchanged');
    expect(find.text('4 / 2 L'), findsNothing);
    transport.hold!.complete();
    await drive(tester, rounds: 40);
    await tearDownApp(tester, account);
  });

  testWidgets('Back during the wait leaves; the late ack then opens nothing', (tester) async {
    final id = await seed(tester);
    transport.hold = Completer<void>();
    await openAmount(tester, id);
    await save(tester, '2');

    await tester.tap(find.text('Cancel · keep saved value'));
    await settle(tester);
    expect(onToday(), isTrue);

    transport.hold!.complete();
    await drive(tester);
    await tester.pump(const Duration(seconds: 7));
    await drive(tester);
    expect(find.text('That counts.'), findsNothing);
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  testWidgets('a partial save leaves at once and forces no sync', (tester) async {
    final id = await seed(tester);
    await openAmount(tester, id);

    await save(tester, '0.5');

    expect(onToday(), isTrue);
    expect(transport.calls, 0, reason: 'only the usual 2-second debounce');
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  testWidgets('an add to a day already complete and synced leaves at once (5.2c L1)', (
    tester,
  ) async {
    final id = await seed(tester);
    await tester.runAsync(() => account.writer.setLogValue(habitId: id, value: '2.000'));
    await syncNow(tester, account);
    transport.calls = 0;
    await openAmount(tester, id);

    await save(tester, '0.5');

    expect(onToday(), isTrue);
    expect(find.text('That counts.'), findsNothing);
    expect(transport.calls, 0, reason: 'no forced sync: this ack cannot carry XP');
    await drive(tester, rounds: 40);
    await tearDownApp(tester, account);
  });

  testWidgets('reward_state arriving in a later response updates the card', (tester) async {
    final id = await seed(tester);
    transport.rewardLater = true;
    await openAmount(tester, id);

    await save(tester, '2');
    await drive(tester);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('1,250 XP total'), findsNothing, reason: 'not confirmed yet');

    // The next response carries the reward_state (another sync, as the app makes one).
    unawaited(account.sync.sync());
    await drive(tester);
    expect(find.text('1,250 XP total'), findsOneWidget);
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  testWidgets('06: a timer finish at the target opens the duration layout', (tester) async {
    final id = await seed(tester, type: 'duration', target: 600, unit: null, name: 'Meditation');
    await tester.runAsync(() async {
      await account.writer.startTimer(id);
      await account.writer.pauseTimer(id);
      // Ten minutes banked, paused (A36).
      await account.session.db.customStatement(
        "UPDATE timer_drafts SET elapsed_ms = 600000 WHERE habit_id = '$id'",
      );
    });
    await tester.pumpWidget(testApp(initial: '/habits/$id/timer', account: account));
    await settle(tester);

    await tester.tap(find.text('Save progress and finish'));
    await drive(tester, rounds: 40);

    expect(find.text('Meditation complete'), findsOneWidget);
    expect(find.text('10 min logged today'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });

  testWidgets('text scale 2.0 keeps the completion screen readable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final id = await seed(tester);
    await openAmount(tester, id);

    await save(tester, '2');
    await drive(tester);

    expect(find.text('Water complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Back to today'), 300);
    expect(tester.takeException(), isNull);
    await drive(tester, rounds: 40); // let a debounced background sync finish first
    await tearDownApp(tester, account);
  });
}

/// The fake server, with what the real one adds in 5.1: xp_delta on accepted log acks and a
/// reward_state change (A39, A43). Can hold a response, answer with a conflict, or send the
/// reward_state in the next response.
class RewardingTransport implements SyncTransport {
  RewardingTransport(this.server);

  final FakeSyncServer server;
  int? xpDelta = 10;
  String status = 'accepted';
  Completer<void>? hold;
  bool rewardLater = false;
  bool _rewardDue = false;
  int calls = 0;
  int _rewardVersion = 1;

  void _journalReward() => server.journalEntity('reward_state', 'user-1', ++_rewardVersion, {
    'xp': 1250,
    'level': 13,
    'progress_into_level': 50,
    'next_level_threshold': 1300,
    'freeze_balance': 2,
  });

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    calls++;
    if (hold != null) await hold!.future;
    final logs = mutations.where((m) => m['entity'] == 'habit_log').isNotEmpty;
    if (_rewardDue) {
      _journalReward();
      _rewardDue = false;
    }
    if (logs && status == 'accepted' && (xpDelta ?? 0) != 0 && !rewardLater) _journalReward();
    if (logs && rewardLater) _rewardDue = true;
    final page = await server.sync(
      deviceId: deviceId,
      cursor: cursor,
      pullLimit: pullLimit,
      mutations: mutations,
      capabilities: capabilities,
    );
    return SyncPage(
      acks: [
        for (final ack in page.acks)
          if (ack['entity'] == 'habit_log' && ack['status'] == 'accepted')
            status == 'conflict'
                ? {
                    'mutation_id': ack['mutation_id'],
                    'status': 'conflict',
                    'duplicate': false,
                    'entity': 'habit_log',
                    'entity_id': ack['entity_id'],
                    'error': {'code': 'version_conflict', 'message': 'x', 'current_version': 9},
                  }
                : {...ack, 'xp_delta': ?xpDelta}
          else
            ack,
      ],
      changes: page.changes,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      serverTime: page.serverTime,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}
