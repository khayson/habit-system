import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/amount_entry_screen.dart';
import 'package:habit/screens/timer_screen.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 4.3b: screen 34, amount entry. The habit is synced first; the screen runs offline.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late AccountContext account;

  Future<String> seed(
    WidgetTester tester, {
    String type = 'quantity',
    Object target = '2.000',
    String? unit = 'L',
    Object? saved = '1.250',
    String name = 'Water',
    bool archive = false,
  }) async {
    useTallPhone(tester);
    server = FakeSyncServer();
    account = (await tester.runAsync(() => testAccount(server)))!;
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
      if (saved != null) await account.writer.setLogValue(habitId: id, value: saved);
      if (archive) await account.writer.archiveHabit(id);
    });
    await syncNow(tester, account);
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
    return id;
  }

  Future<void> open(WidgetTester tester, String id, {Object? extra}) async {
    await tester.pumpWidget(
      testApp(initial: '/habits/$id/add', initialExtra: extra, account: account),
    );
    await settle(tester);
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  Finder field() => find.byKey(const ValueKey('amount-field'));

  Future<void> add(WidgetTester tester) async {
    await tester.tap(find.textContaining(RegExp(r'^Add \d')));
    await settle(tester);
  }

  testWidgets('copy: progress from today and the target in force; the step prefilled', (
    tester,
  ) async {
    final id = await seed(tester);
    await open(tester, id);
    for (final t in [
      'Add progress',
      'Water · 1.25 / 2 L saved today',
      '0.25 L',
      'Custom amount in L',
      'After saving',
      '1.5 / 2 L',
      'Not complete yet',
      'Add 0.25 L',
      'Cancel · keep saved value',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.widget<TextField>(field()).controller!.text, '0.25');
    expect(find.text('Time it instead'), findsNothing, reason: 'quantity has no timer');
    expect(find.textContaining('XP'), findsNothing, reason: 'Phase 5');
    await tearDownApp(tester, account);
  });

  testWidgets('the stepper and the field follow each other; the target line updates', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final id = await seed(tester);
    await open(tester, id);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Amount to add')),
      isSemantics(
        label: 'Amount to add',
        value: '0.25 L',
        hasIncreaseAction: true,
        hasDecreaseAction: false,
      ),
      reason: 'minus would reach zero',
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(tester.widget<TextField>(field()).controller!.text, '0.5');
    expect(find.text('1.75 / 2 L'), findsOneWidget);
    await tester.enterText(field(), '0.75');
    await tester.pump();
    expect(find.text('0.75 L'), findsOneWidget);
    expect(find.text('2 / 2 L'), findsOneWidget);
    expect(find.text("Today's target is reached"), findsOneWidget);
    for (final control in [find.byTooltip('More'), find.byTooltip('Less')]) {
      expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    }
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('add: one log.increment with a thousandths delta and no base version, offline', (
    tester,
  ) async {
    final id = await seed(tester);
    await open(tester, id, extra: 500);
    expect(tester.widget<TextField>(field()).controller!.text, '0.5', reason: 'prefilled');
    await add(tester);
    final row = (await outbox(tester)).single;
    expect((row.operation, row.baseVersion), ('log.increment', null));
    expect(jsonDecode(row.payload), {'habit_id': id, 'delta': '0.500'});
    expect(find.byType(AmountEntryScreen), findsNothing, reason: 'saved: it closes');
    expect(
      server.sentMutationIds.expand((ids) => ids),
      isNot(contains(row.mutationId)),
      reason: 'offline: it never reached a server',
    );
    await tearDownApp(tester, account);
  });

  testWidgets('every error in words, the typed text kept, nothing written', (tester) async {
    final id = await seed(tester);
    await open(tester, id);
    for (final (typed, message) in [
      ('', 'Add an amount.'),
      ('abc', 'Use a number, such as 250 or 1.5.'),
      ('1.2345', 'Use up to 3 decimal places.'),
      ('0', 'Use a number above zero.'),
      ('9999999999', 'Use a smaller number.'),
    ]) {
      await tester.enterText(field(), typed);
      await tester.pump();
      await add(tester);
      expect(find.text(message), findsOneWidget, reason: typed);
      expect(tester.widget<TextField>(field()).controller!.text, typed);
    }
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('a day that cannot hold the amount: in words, nothing written', (tester) async {
    final id = await seed(tester, type: 'duration', target: 600, unit: null, saved: 25 * 3600 - 30);
    await open(tester, id);
    await add(tester);
    expect(find.text("Today can't hold that much."), findsOneWidget);
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('cancel and back write nothing', (tester) async {
    final id = await seed(tester);
    await open(tester, id);
    await tester.tap(find.text('Cancel · keep saved value'));
    await settle(tester);
    expect(find.byType(AmountEntryScreen), findsNothing);
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('duration: minutes in, whole seconds out; a timer is offered', (tester) async {
    final id = await seed(
      tester,
      type: 'duration',
      target: 600,
      unit: null,
      saved: 360,
      name: 'Yoga',
    );
    await open(tester, id);
    for (final t in [
      'Add time',
      'Yoga · 6 / 10 min saved today',
      '1 min',
      'Custom time in minutes',
      '7 / 10 min',
      'Add 1 min',
      'Time it instead',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.enterText(field(), '1.5');
    await tester.pump();
    await add(tester);
    expect(jsonDecode((await outbox(tester)).single.payload), {'habit_id': id, 'delta': 90});
    await tearDownApp(tester, account);
  });

  testWidgets('Time it instead starts the timer and replaces 34 with it', (tester) async {
    final id = await seed(
      tester,
      type: 'duration',
      target: 600,
      unit: null,
      saved: 360,
      name: 'Yoga',
    );
    await open(tester, id);
    await tester.tap(find.text('Time it instead'));
    await settle(tester);
    expect(find.byType(TimerScreen), findsOneWidget);
    expect(find.byType(AmountEntryScreen), findsNothing);
    final drafts = (await tester.runAsync(
      () => account.session.db.select(account.session.db.timerDrafts).get(),
    ))!;
    expect(drafts.single.habitId, id);
    expect(await outbox(tester), isEmpty, reason: 'a draft is local only');
    await tearDownApp(tester, account);
  });

  testWidgets('no form for a yes / no habit, an archived habit or an unknown one', (tester) async {
    final stretch = await seed(tester, type: 'binary', target: 1, unit: null, saved: null);
    await open(tester, stretch);
    expect(find.text('This habit is checked in with one tap on Today.'), findsOneWidget);
    expect(field(), findsNothing);
    await tearDownApp(tester, account);

    final archived = await seed(tester, archive: true);
    await open(tester, archived);
    expect(
      find.text('This habit is archived. Restore it from Archived routines to make changes.'),
      findsOneWidget,
    );
    expect(field(), findsNothing);
    await open(tester, '0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f');
    expect(find.text('This habit is no longer on this device.'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('at 200% text 34 renders without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final id = await seed(tester, type: 'duration', target: 600, unit: null, saved: 360);
    await open(tester, id);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
  });
}
