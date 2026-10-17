import 'dart:ui' show Tristate;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/models/reward_pages.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/services/rewards_service.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 5.2b: screens 16 and 17, the auto-protect switch, and the ways in (Profile, 12).
void main() {
  setUpAll(loadTestZones);

  Future<AccountContext> account(WidgetTester tester, FakeRewards api) async {
    useTallPhone(tester);
    return (await tester.runAsync(() => testAccount(FakeSyncServer(), rewardsApi: api)))!;
  }

  Future<void> confirm(
    WidgetTester tester,
    AccountContext a, {
    int xp = 1250,
    int level = 13,
    int into = 50,
    int threshold = 1300,
    int freezes = 1,
  }) => tester.runAsync(
    () => a.session.db
        .into(a.session.db.rewardState)
        .insertOnConflictUpdate(
          RewardStateCompanion.insert(
            id: 'user-1',
            xp: Value(xp),
            level: Value(level),
            progressIntoLevel: Value(into),
            nextLevelThreshold: Value(threshold),
            freezeBalance: Value(freezes),
            version: 3,
          ),
        ),
  );

  group('16, Progress you earned', () {
    testWidgets('the confirmed level, XP and bar label; Recent XP with habit names', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final api = FakeRewards();
      final a = await account(tester, api);
      late String water;
      await tester.runAsync(() async {
        water = await a.actions.createOneTapHabit(name: 'Stretch', category: 'health');
        await a.writer.setLogValue(habitId: water, value: 1);
      });
      await confirm(tester, a);
      api.xp = [
        [
          xpEntry('x1', water, '2026-05-28', 10, 'completion'),
          xpEntry('x2', 'gone', '2026-05-27', -10, 'reversal'),
          xpEntry('x3', water, '2026-05-20', 10, 'streak_bonus'),
        ],
      ];
      await tester.pumpWidget(testApp(initial: '/rewards', account: a));
      await settle(tester);

      expect(find.text('Progress you earned'), findsOneWidget);
      expect(find.text('LEVEL 13'), findsOneWidget);
      expect(find.text('1,250 XP'), findsOneWidget);
      expect(find.text('50 / 100 XP toward Level 14'), findsOneWidget);
      expect(find.bySemanticsLabel('Stretch, Today · completed, +10 XP'), findsOneWidget);
      expect(
        find.bySemanticsLabel('A habit, Yesterday · Check-in changed, −10 XP'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Stretch, 20 May · XP update, +10 XP'), findsOneWidget);
      expect(find.textContaining('10 XP per completed habit per day.'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(
        await tester.runAsync(() => a.session.db.select(a.session.db.rewardState).get()),
        hasLength(1),
      );
      handle.dispose();
      await tearDownApp(tester, a);
    });

    testWidgets('no confirmed numbers: one neutral line, no zeros', (tester) async {
      final a = await account(tester, FakeRewards()..xp = [[]]);
      await tester.pumpWidget(testApp(initial: '/rewards', account: a));
      await settle(tester);

      expect(find.text('Your progress appears after the first sync.'), findsOneWidget);
      expect(find.text('0 XP'), findsNothing);
      expect(find.textContaining('LEVEL'), findsNothing);
      expect(find.text('Nothing here yet.'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('offline: the numbers stay and the list offers Try again', (tester) async {
      final api = FakeRewards()..fail = true;
      final a = await account(tester, api);
      await confirm(tester, a);
      await tester.pumpWidget(testApp(initial: '/rewards', account: a));
      await settle(tester);

      expect(find.text('1,250 XP'), findsOneWidget);
      expect(find.text('This could not be loaded right now.'), findsOneWidget);
      expect(find.textContaining('pending'), findsNothing);
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Try again')).height,
        greaterThanOrEqualTo(44),
      );

      api
        ..fail = false
        ..xp = [
          [xpEntry('x1', 'h', '2026-05-28', 10, 'completion')],
        ];
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'^A habit, Today · completed, \+10 XP$')),
        findsOneWidget,
      );
      await tearDownApp(tester, a);
    });

    testWidgets('Show more appends; a failed second page keeps the rows', (tester) async {
      final api = FakeRewards()
        ..xp = [
          [xpEntry('x1', 'h', '2026-05-28', 10, 'completion')],
          [xpEntry('x2', 'h', '2026-05-27', 10, 'completion')],
        ];
      final a = await account(tester, api);
      await tester.pumpWidget(testApp(initial: '/rewards', account: a));
      await settle(tester);

      api.failNext = true;
      await tester.tap(find.text('Show more'));
      await settle(tester);
      expect(find.text('More could not be loaded. The list above is unchanged.'), findsOneWidget);
      expect(find.textContaining('Today · completed'), findsOneWidget);

      await tester.tap(find.text('Show more'));
      await settle(tester);
      expect(find.textContaining('Yesterday · completed'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(api.cursors, [null, 'c1', 'c1']);
      await tearDownApp(tester, a);
    });

    testWidgets('text scale 2.0 keeps 16 readable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final a = await account(
        tester,
        FakeRewards()
          ..xp = [
            [xpEntry('x1', 'h', '2026-05-28', 10, 'completion')],
          ],
      );
      await confirm(tester, a, xp: 1250000, level: 1251, into: 0, threshold: 1250100);
      await tester.pumpWidget(testApp(initial: '/rewards', account: a));
      await settle(tester);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.textContaining('Repeated increments'), 300);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, a);
    });
  });

  group('17, A little breathing room', () {
    testWidgets('the wallet with the server cap and refill date; the history rows', (tester) async {
      final handle = tester.ensureSemantics();
      final api = FakeRewards();
      final a = await account(tester, api);
      late String habit;
      await tester.runAsync(() async {
        habit = await a.actions.createOneTapHabit(name: 'Meditation', category: 'health');
      });
      await confirm(tester, a);
      api.freezes = [
        [
          freezeEntry('f1', 'spend', -1, 'missed_period', habit, 'd:2026-05-20'),
          freezeEntry('f2', 'spend', -1, 'missed_period', habit, 'w:2026-05-11'),
          freezeEntry('f3', 'refund', 1, 'late_completion', habit, 'd:2026-05-19'),
          freezeEntry('f4', 'refund', 0, 'cap_reached', habit, 'd:2026-05-18'),
          freezeEntry('f5', 'grant', 0, 'cap_reached', null, null),
          freezeEntry('f6', 'grant', 1, 'monthly', null, null),
          freezeEntry('f7', 'grant', 2, 'signup', null, null),
          freezeEntry('f8', 'gift', 1, 'birthday', null, null),
        ],
      ];
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      expect(find.text('A little breathing room'), findsOneWidget);
      expect(find.text('1 / 2 freezes'), findsOneWidget);
      expect(find.text('Next refill: 1 June · up to 2 total'), findsOneWidget);
      for (final label in [
        'Meditation · 20 May, 1 freeze used · daily period protected, −1',
        'Meditation · 11 May, 1 freeze used · weekly period protected, −1',
        'Meditation · 19 May, 1 freeze returned · completed later, +1',
        'Meditation · 18 May, Completed later · your wallet was already full, 0',
        'Your wallet was already full, 28 May, 0',
        'Monthly refill, 28 May, +1',
        'Starting freezes, 28 May, +2',
        'Freeze update, 28 May, +1',
      ]) {
        await tester.scrollUntilVisible(find.bySemanticsLabel(label), 200);
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(find.text('Protection is not completion'), 200);
      expect(
        find.text(
          'No XP is awarded for a freeze. A real completion later can return the token once.',
        ),
        findsOneWidget,
      );
      handle.dispose();
      await tearDownApp(tester, a);
    });

    testWidgets('before GET /freezes answers, or when it fails: the balance alone', (tester) async {
      final a = await account(tester, FakeRewards()..fail = true);
      await confirm(tester, a, freezes: 2);
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      expect(find.text('2 freezes'), findsOneWidget);
      expect(find.textContaining('Next refill'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('a refill date in another year shows the year', (tester) async {
      final a = await account(tester, FakeRewards()..refill = '2027-01-01');
      await confirm(tester, a);
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      expect(find.text('Next refill: 1 January 2027 · up to 2 total'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('the switch row: one toggle target; tapping queues the change offline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final a = await account(tester, FakeRewards());
      await confirm(tester, a);
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      final row = find.bySemanticsLabel('Auto-protect missed periods');
      expect(row, findsOneWidget);
      final node = tester.getSemantics(row);
      expect(node.hint, 'After a scheduled day or week closes');
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
      expect(find.text('Turning it on protects periods that close from now on.'), findsOneWidget);

      await tester.tap(row);
      await settle(tester);

      expect(tester.getSemantics(row).flagsCollection.isToggled, Tristate.isTrue);
      expect(find.text('Saved on this device. It applies after syncing.'), findsOneWidget);
      final outbox = await tester.runAsync(() => a.session.db.select(a.session.db.outbox).get());
      expect(outbox!.single.operation, 'profile.set_auto_freeze');
      handle.dispose();
      await tearDownApp(tester, a);
    });

    testWidgets('a switch change that needs a look links to the queue', (tester) async {
      final a = await account(tester, FakeRewards());
      await tester.runAsync(() async {
        await a.writer.setAutoFreeze(true);
        await a.session.db.customStatement(
          "UPDATE outbox SET state = '${OutboxState.needsAttention}', "
          """last_error = '{"code":"version_conflict"}'""",
        );
      });
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      await tester.tap(find.text('This change needs a look in the sync queue.'));
      await settle(tester);
      expect(find.text('Your profile · Auto-protect turned on'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('text scale 2.0 keeps 17 readable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final a = await account(
        tester,
        FakeRewards()
          ..freezes = [
            [freezeEntry('f1', 'spend', -1, 'missed_period', 'h', 'd:2026-05-20')],
          ],
      );
      await confirm(tester, a);
      await tester.pumpWidget(testApp(initial: '/freezes', account: a));
      await settle(tester);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Protection is not completion'), 300);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, a);
    });
  });

  group('the ways in', () {
    testWidgets('Profile opens 16 and 17', (tester) async {
      final a = await account(tester, FakeRewards());
      await confirm(tester, a);
      await tester.pumpWidget(testApp(initial: '/profile', account: a));
      await settle(tester, rounds: 16);

      expect(find.text('Level 13 · 1,250 XP'), findsWidgets);
      await tester.scrollUntilVisible(find.text('XP and levels'), 200);
      await tester.tap(find.text('XP and levels'));
      await settle(tester);
      expect(find.text('Progress you earned'), findsOneWidget);
      expect(find.text('Profile'), findsWidgets, reason: 'the shell stays, Profile selected');

      await tester.tap(find.byTooltip('Back').first);
      await settle(tester, rounds: 16);
      await tester.scrollUntilVisible(find.text('Freezes'), 200);
      expect(find.text('1 freeze · auto-protect off'), findsOneWidget);
      await tester.tap(find.text('Freezes'));
      await settle(tester);
      expect(find.text('A little breathing room'), findsOneWidget);
      await tearDownApp(tester, a);
    });
  });
}

XpLedgerEntry xpEntry(String id, String habit, String date, int delta, String reason) =>
    XpLedgerEntry(
      id: id,
      delta: delta,
      reason: reason,
      habitId: habit,
      logDate: date,
      createdAt: DateTime.utc(2026, 5, 28, 17),
    );

FreezeLedgerEntry freezeEntry(
  String id,
  String kind,
  int delta,
  String reason,
  String? habit,
  String? period,
) => FreezeLedgerEntry(
  id: id,
  kind: kind,
  delta: delta,
  reason: reason,
  habitId: habit,
  periodKey: period,
  createdAt: DateTime.utc(2026, 5, 28, 17),
);

/// Pages served in order; the cursor of page i is "c{i}".
class FakeRewards implements RewardsService {
  List<List<XpLedgerEntry>> xp = [[]];
  List<List<FreezeLedgerEntry>> freezes = [[]];
  String refill = '2026-06-01';
  bool fail = false;
  bool failNext = false;
  final List<String?> cursors = [];

  int _index(String? cursor) => cursor == null ? 0 : int.parse(cursor.substring(1));

  void _maybeFail() {
    if (fail || failNext) {
      failNext = false;
      throw const AppException(kind: AppErrorKind.network, code: 'network', message: 'offline');
    }
  }

  @override
  Future<RewardsPage> fetchRewards({String? cursor, int limit = 20}) async {
    cursors.add(cursor);
    _maybeFail();
    final i = _index(cursor);
    return RewardsPage(ledger: xp[i], nextCursor: i + 1 < xp.length ? 'c${i + 1}' : null);
  }

  @override
  Future<FreezesPage> fetchFreezes({String? cursor, int limit = 20}) async {
    cursors.add(cursor);
    _maybeFail();
    final i = _index(cursor);
    return FreezesPage(
      freezeBalance: 1,
      cap: 2,
      autoFreeze: false,
      nextRefillOn: refill,
      ledger: freezes[i],
      nextCursor: i + 1 < freezes.length ? 'c${i + 1}' : null,
    );
  }
}
