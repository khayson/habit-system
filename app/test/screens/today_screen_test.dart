import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Screen 05 and its empty state 23: local data only, honest about what is waiting to sync.
void main() {
  setUpAll(loadTestZones);

  testWidgets('loading, then the first-run empty state (23)', (tester) async {
    final account = (await tester.runAsync(() => testAccount(FakeSyncServer())))!;
    await tester.pumpWidget(testApp(initial: '/today', account: account));

    expect(find.text('Opening your habits…'), findsOneWidget);
    await settle(tester);

    expect(find.text('Your first step'), findsOneWidget);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('Create your first habit'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget, reason: 'status is text, never colour');
    await tearDownApp(tester, account);
  });

  testWidgets('a queued habit is labelled; a tap checks in and stays provisional', (tester) async {
    final account = (await tester.runAsync(() => testAccount(FakeSyncServer())))!;
    await tester.runAsync(
      () => account.actions.createOneTapHabit(name: 'Stretch', category: 'health'),
    );
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);

    expect(find.text('Good morning, Maya'), findsOneWidget, reason: '10:22 in Los Angeles');
    expect(find.text('Thursday, May 28, 2026'), findsOneWidget);
    expect(find.text('0 of 1 habits complete'), findsOneWidget);
    expect(find.text('New · waiting to sync'), findsOneWidget);
    expect(find.text('1 waiting'), findsOneWidget);

    await tester.tap(find.text('Stretch'));
    await settle(tester);

    expect(find.text('Done · waiting to sync'), findsOneWidget);
    expect(find.text('1 of 1 habits complete'), findsOneWidget);
    expect(find.text('Includes changes waiting to sync.'), findsOneWidget);
    expect(find.text('2 waiting'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('after sync the check-in is confirmed and the chip says Synced', (tester) async {
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
    });
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);
    await tester.tap(find.text('Stretch'));
    await settle(tester);

    await syncNow(tester, account);
    await settle(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Includes changes waiting to sync.'), findsNothing);
    expect(server.logs.values.single['value'], 1);
    await tearDownApp(tester, account);
  });

  testWidgets('a habit-day that needs a look opens the resolve sheet instead of queueing', (
    tester,
  ) async {
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      final habit = await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.sync.sync(force: true);
      await account.writer.setLogValue(habitId: habit, value: 1);
      await account.session.db.customStatement(
        "UPDATE outbox SET state = '${OutboxState.needsAttention}', "
        "last_error = '{\"code\":\"version_conflict\"}'",
      );
    });
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);

    expect(find.text('Needs a look · tap to review'), findsOneWidget);
    expect(find.text('Needs a look'), findsOneWidget, reason: 'the chip');

    await tester.tap(find.text('Stretch'));
    await settle(tester);

    expect(find.text('This check-in needs a look'), findsOneWidget);
    expect(find.text('It changed on another device first.'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => account.session.db.select(account.session.db.outbox).get(),
    ))!;
    expect(rows, hasLength(1), reason: 'the tap queued nothing behind it');

    await tester.tap(find.text('Discard my change'));
    await settle(tester);
    expect(find.text('Discard this change?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(find.text('Tap to check in'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a habit type this version does not know shows an update card', (tester) async {
    final server = FakeSyncServer()
      ..extraBootstrapHabits.add({
        'id': 'future-1',
        'name': 'Morning checklist',
        'type': 'checklist',
        'target_value': 3,
        'category': 'health',
        'frequency_type': 'daily',
        'frequency_config': <String, Object>{},
        'start_local_date': '2026-05-01',
        'archived_at': null,
        'version': 1,
      });
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await syncNow(tester, account);
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);

    expect(find.text('Morning checklist'), findsOneWidget);
    expect(find.text('Update the app to log this habit.'), findsOneWidget);
    await tester.tap(find.text('Morning checklist'));
    await settle(tester);
    final rows = (await tester.runAsync(
      () => account.session.db.select(account.session.db.outbox).get(),
    ))!;
    expect(rows, isEmpty, reason: 'nothing is written for an unknown type');
    final stored = (await tester.runAsync(
      () => account.session.db.select(account.session.db.habits).getSingle(),
    ))!;
    expect(EntityCodec.habitPayload(stored)['type'], 'checklist', reason: 'preserved (A21)');
    await tearDownApp(tester, account);
  });

  testWidgets('text scales without clipping the summary', (tester) async {
    final account = (await tester.runAsync(() => testAccount(FakeSyncServer())))!;
    await tester.runAsync(
      () => account.actions.createOneTapHabit(name: 'Stretch', category: 'health'),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: testApp(initial: '/today', account: account),
      ),
    );
    await settle(tester);

    expect(find.text('0 of 1 habits complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
  });
}
