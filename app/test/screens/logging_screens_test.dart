import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/amount_entry_screen.dart';
import 'package:habit/screens/timer_screen.dart';
import 'package:habit/screens/today_screen.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 4.3b: the Today cards for quantity and duration (05), 12's logging actions and the
/// timer screen (33 running, 36 paused). Offline after the first sync; a clock the test moves.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late AccountContext account;
  late DateTime now;
  late Map<String, String> ids;

  Future<void> seed(
    WidgetTester tester, {
    Object waterSaved = '1.250',
    Object yogaSaved = 360,
  }) async {
    useTallPhone(tester);
    now = testNow;
    server = FakeSyncServer();
    account = (await tester.runAsync(() => testAccount(server, clock: () => now)))!;
    ids = {};
    await tester.runAsync(() async {
      for (final (name, type, target, unit, saved) in [
        ('Water', 'quantity', '2.000' as Object, 'L', waterSaved),
        ('Meditation', 'duration', 600 as Object, null, yogaSaved),
        ('Stretch', 'binary', 1 as Object, null, null),
      ]) {
        final id = await account.writer.createHabitUnchecked(
          name: name,
          type: type,
          target: target,
          unit: unit,
          category: 'health',
          startLocalDate: LocalDate.parse('2026-05-01'),
          backdate: true,
        );
        ids[name] = id;
        if (saved != null) await account.writer.setLogValue(habitId: id, value: saved);
      }
    });
    await syncNow(tester, account);
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
  }

  Future<void> show(WidgetTester tester, String location) async {
    await tester.pumpWidget(testApp(initial: location, account: account, clock: () => now));
    await settle(tester);
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  Future<int> drafts(WidgetTester tester) async => (await tester.runAsync(
    () => account.session.db.select(account.session.db.timerDrafts).get(),
  ))!.length;

  Future<void> startTimer(WidgetTester tester, {bool pause = false}) async {
    await tester.runAsync(() async {
      await account.writer.startTimer(ids['Meditation']!);
      if (pause) {
        now = now.add(const Duration(seconds: 30));
        await account.writer.pauseTimer(ids['Meditation']!);
      }
    });
  }

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

  group('Today cards (05)', () {
    testWidgets('quantity: progress over the target in force; +step opens 34 with it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await seed(tester);
      await show(tester, '/today');
      expect(find.text('1.25 / 2 L'), findsOneWidget);
      final plus = find.text('+0.25 L');
      expect(plus, findsOneWidget);
      expect(
        tester.getSemantics(plus),
        isSemantics(label: 'Add 0.25 L', isButton: true, hasTapAction: true),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Water: 1\.25 of 2 L$')),
        findsOneWidget,
        reason: 'the card reads its progress in words',
      );
      expect(
        tester.getSize(find.ancestor(of: plus, matching: find.byType(TextButton))).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(plus);
      await settle(tester);
      expect(find.byType(AmountEntryScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('amount-field'))).controller!.text,
        '0.25',
      );
      expect(await outbox(tester), isEmpty, reason: 'one tap writes nothing');
      handle.dispose();
      await tearDownApp(tester, account);
    });

    testWidgets('done: "· done" and a check, no quick-add', (tester) async {
      await seed(tester, waterSaved: '2.000');
      await show(tester, '/today');
      expect(find.text('2 / 2 L · done'), findsOneWidget);
      expect(find.text('+0.25 L'), findsNothing);
      await tearDownApp(tester, account);
    });

    testWidgets('duration idle: +1 min opens 34 with one minute', (tester) async {
      await seed(tester);
      await show(tester, '/today');
      expect(find.text('6 / 10 min'), findsOneWidget);
      await tester.tap(find.text('+1 min'));
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('amount-field'))).controller!.text,
        '1',
      );
      await tearDownApp(tester, account);
    });

    testWidgets('a running timer ticks in its row only; Open timer opens it', (tester) async {
      await seed(tester);
      await startTimer(tester);
      await show(tester, '/today');
      expect(find.text('Timer running · 00:00'), findsOneWidget);
      final waterBefore = tester.widget(row('Water'));
      now = now.add(const Duration(seconds: 65));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Timer running · 01:05'), findsOneWidget);
      expect(
        identical(tester.widget(row('Water')), waterBefore),
        isTrue,
        reason: 'the list did not rebuild for the tick',
      );
      await tester.tap(find.text('Open timer'));
      await settle(tester);
      expect(find.byType(TimerScreen), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('a paused timer shows its banked time and does not tick', (tester) async {
      await seed(tester);
      await startTimer(tester, pause: true);
      await show(tester, '/today');
      expect(find.text('Timer paused · 00:30'), findsOneWidget);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Timer paused · 00:30'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('yes / no keeps its one-tap check; archived habits stay off Today', (tester) async {
      await seed(tester);
      await tester.runAsync(() => account.writer.archiveHabit(ids['Water']!));
      await show(tester, '/today');
      expect(find.byTooltip('Check in Stretch'), findsOneWidget);
      expect(find.text('Water'), findsNothing);
      await tearDownApp(tester, account);
    });

    testWidgets('at 200% text the cards render without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seed(tester);
      await startTimer(tester);
      await show(tester, '/today');
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, account);
    });
  });

  group('12: logging actions', () {
    testWidgets('Add progress opens 34; a duration habit starts its timer, then opens it', (
      tester,
    ) async {
      await seed(tester);
      await show(tester, '/habits/${ids['Water']}');
      expect(find.text('Start timer'), findsNothing, reason: 'quantity has no timer');
      await tester.tap(find.text('Add progress'));
      await settle(tester);
      expect(find.byType(AmountEntryScreen), findsOneWidget);

      await show(tester, '/habits/${ids['Meditation']}');
      await tester.tap(find.text('Start timer'));
      await settle(tester);
      expect(find.byType(TimerScreen), findsOneWidget);
      expect(await drafts(tester), 1);
      await show(tester, '/habits/${ids['Meditation']}');
      expect(find.text('Open timer'), findsOneWidget);
      await tearDownApp(tester, account);
    });
  });

  testWidgets('L2: Start timer on 12 for a habit archived after it opened says why', (
    tester,
  ) async {
    await seed(tester);
    await show(tester, '/habits/${ids['Meditation']}');
    await tester.runAsync(() => account.writer.archiveHabit(ids['Meditation']!));
    await tester.tap(find.text('Start timer'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('This habit is archived. Restore it to save this time.'), findsOneWidget);
    expect(await drafts(tester), 0);
    await tearDownApp(tester, account);
  });

  group('timer (33 running, 36 paused)', () {
    Future<void> openTimer(WidgetTester tester) =>
        show(tester, '/habits/${ids['Meditation']}/timer');

    testWidgets('running: the copy, the total today, one readable time value', (tester) async {
      final handle = tester.ensureSemantics();
      await seed(tester);
      await startTimer(tester);
      now = now.add(const Duration(seconds: 65));
      await openTimer(tester);
      for (final t in [
        'A moment to breathe',
        'Meditation · 10-minute daily target',
        '01:05 / 10:00',
        'Pause',
        '7 minutes today',
        'Keep going if you like. You can save partial time without pretending the habit is complete.',
        'Pause timer',
        'Save progress and finish',
        'The timer continues locally without network access.',
        'Discard timer',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('XP'), findsNothing);
      expect(find.bySemanticsLabel('1 minute of 10 minutes'), findsOneWidget);
      handle.dispose();
      await tearDownApp(tester, account);
    });

    testWidgets('pause and resume; the paused copy; the state survives a rebuilt screen', (
      tester,
    ) async {
      await seed(tester);
      await startTimer(tester);
      now = now.add(const Duration(seconds: 65));
      await openTimer(tester);
      await tester.tap(find.text('Pause timer'));
      await settle(tester);
      for (final t in [
        'Pause at your pace',
        'Meditation · your elapsed time is preserved',
        '01:05 / 10:00',
        'Resume',
        'Timer paused',
        '1 minute is saved in the draft. Nothing is logged until you finish and save.',
        'Resume timer',
        'Returning to Today keeps partial progress.',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      now = now.add(const Duration(minutes: 3));
      await openTimer(tester);
      expect(find.text('01:05 / 10:00'), findsOneWidget, reason: 'paused time does not grow');
      await tester.tap(find.text('Resume timer'));
      await settle(tester);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:10 / 10:00'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('finish: one increment of whole seconds, back on Today with a line', (
      tester,
    ) async {
      await seed(tester);
      await startTimer(tester);
      now = now.add(const Duration(seconds: 65, milliseconds: 700));
      await openTimer(tester);
      await tester.tap(find.text('Save progress and finish'));
      await settle(tester);
      final row = (await outbox(tester)).single;
      expect((row.operation, jsonDecode(row.payload)['delta']), ('log.increment', 65));
      expect(await drafts(tester), 0);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Saved 1 min.'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('finish with nothing elapsed: nothing written, the draft gone', (tester) async {
      await seed(tester);
      await startTimer(tester);
      await openTimer(tester);
      await tester.tap(find.text('Save progress and finish'));
      await settle(tester);
      expect(await outbox(tester), isEmpty);
      expect(await drafts(tester), 0);
      expect(find.text('Nothing to save yet.'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    for (final (label, setUp, message) in [
      (
        'too long',
        (WidgetTester t) async => now = now.add(const Duration(hours: 25, seconds: 1)),
        'This timer ran longer than a day can hold.',
      ),
      (
        'the day cannot hold it',
        (WidgetTester t) async {
          await t.runAsync(
            () => account.writer.setLogValue(habitId: ids['Meditation']!, value: 25 * 3600 - 10),
          );
          now = now.add(const Duration(seconds: 30));
        },
        "Today can't hold that much time.",
      ),
      (
        'archived',
        (WidgetTester t) async {
          now = now.add(const Duration(seconds: 30));
          await t.runAsync(() => account.writer.archiveHabit(ids['Meditation']!));
        },
        'This habit is archived. Restore it to save this time.',
      ),
    ]) {
      testWidgets('finish refused ($label): the words, Discard timer, and the draft stays', (
        tester,
      ) async {
        await seed(tester);
        await startTimer(tester);
        await setUp(tester);
        await openTimer(tester);
        await tester.tap(find.text('Save progress and finish'));
        await settle(tester);
        expect(find.text(message), findsOneWidget);
        expect(find.text('Discard timer'), findsOneWidget);
        expect(await drafts(tester), 1);
        expect((await outbox(tester)).where((r) => r.operation == 'log.increment'), isEmpty);
        await tearDownApp(tester, account);
      });
    }

    testWidgets('L2: archived after the screen opened: Pause works, Resume says why', (
      tester,
    ) async {
      await seed(tester);
      await startTimer(tester);
      now = now.add(const Duration(seconds: 40));
      await openTimer(tester);
      await tester.runAsync(() => account.writer.archiveHabit(ids['Meditation']!));
      await tester.tap(find.text('Pause timer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Pause at your pace'), findsOneWidget);
      final before = (await outbox(tester)).length;
      await tester.tap(find.text('Resume timer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('This habit is archived. Restore it to save this time.'), findsOneWidget);
      expect(find.text('Discard timer'), findsOneWidget);
      expect((await outbox(tester)).length, before, reason: 'nothing written');
      await tearDownApp(tester, account);
    });

    testWidgets('discard asks first; back keeps the draft', (tester) async {
      await seed(tester);
      await startTimer(tester);
      await openTimer(tester);
      await tester.tap(find.text('Discard timer'));
      await settle(tester);
      expect(find.text('Discard this timer?'), findsOneWidget);
      expect(find.text("The time so far won't be saved."), findsOneWidget);
      await tester.tap(find.text('Keep timer'));
      await settle(tester);
      expect(await drafts(tester), 1);

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(await drafts(tester), 1, reason: 'back leaves the draft as it is');

      await openTimer(tester);
      await tester.tap(find.text('Discard timer'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(await drafts(tester), 0);
      expect(await outbox(tester), isEmpty);
      await tearDownApp(tester, account);
    });

    testWidgets('at 200% text both states render without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seed(tester);
      await startTimer(tester);
      await openTimer(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Pause timer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Pause timer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, account);
    });
  });
}
