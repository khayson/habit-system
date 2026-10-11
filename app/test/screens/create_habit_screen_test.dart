import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/frequency_screen.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';

/// Phase 4.2b: screen 08 in full. Offline throughout: every sync attempt fails as no network,
/// and the habit is still created locally.
void main() {
  setUpAll(loadTestZones);

  final fixture = contractFixture('habit/habit_mutations.json');
  Map<String, dynamic> fixtureHabit(String caseName) =>
      ((fixture['cases'] as List).firstWhere((c) => c['name'] == caseName)
              as Map<String, dynamic>)['habit']
          as Map<String, dynamic>;

  late FakeSyncServer server;

  Future<AccountContext> open(WidgetTester tester) async {
    useTallPhone(tester);
    server = FakeSyncServer()
      ..failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.pumpWidget(testApp(initial: '/habits/new', account: account));
    await settle(tester);
    return account;
  }

  Future<List<Map<String, dynamic>>> creates(WidgetTester tester, AccountContext account) async {
    final rows = (await tester.runAsync(
      () => account.session.db.select(account.session.db.outbox).get(),
    ))!;
    return [
      for (final r in rows)
        if (r.operation == 'habit.create') jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }

  Future<void> create(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Create habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create habit'));
    await settle(tester);
  }

  Finder field(String key) => find.byKey(ValueKey(key));

  testWidgets('copy and the default: a yes / no habit, every day, no reminder', (tester) async {
    final handle = tester.ensureSemantics();
    final account = await open(tester);
    for (final t in [
      'A new routine',
      'Choose something small and specific.',
      'Habit type',
      'Yes / no',
      'Quantity',
      'Duration',
      'Category',
      'Health',
      'Mindful',
      'Learning',
      'Schedule',
      'Every day',
      'Reminder',
      'Not set',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Habit name'), findsWidgets, reason: 'the label (and the hint)');
    expect(find.text('Daily target'), findsNothing, reason: 'yes / no has no target field');
    expect(
      tester.getSemantics(find.text('Yes / no')),
      containsSemantics(label: 'Yes / no', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Quantity')),
      containsSemantics(label: 'Quantity', isButton: true, isSelected: false),
    );
    expect(
      tester.getSemantics(find.text('Edit').first),
      containsSemantics(label: 'Edit Schedule', isButton: true),
    );
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('a quantity habit: the payload matches the contract fixture', (tester) async {
    final account = await open(tester);
    await tester.enterText(find.byType(TextFormField), 'Water');
    await tester.tap(find.text('Quantity'));
    await tester.pump();
    expect(find.text('Daily target'), findsOneWidget);
    await tester.enterText(field('target-amount'), '2000');
    await tester.enterText(field('target-unit'), 'ml');
    await create(tester);

    final expected = fixtureHabit('update the target: a pending version from tomorrow');
    final payload = (await creates(tester, account)).single;
    for (final key in expected.keys) {
      expect(payload[key], expected[key], reason: key);
    }
    expect((payload['name'], payload['start_local_date']), ('Water', '2026-05-28'));
    expect(server.sentMutationIds, isEmpty, reason: 'offline: nothing reached a server');
    await tearDownApp(tester, account);
  });

  testWidgets('a yes / no habit: the payload matches the contract fixture', (tester) async {
    final account = await open(tester);
    await tester.enterText(find.byType(TextFormField), 'Stretch');
    await create(tester);
    final expected = fixtureHabit('update the name only');
    final payload = (await creates(tester, account)).single;
    for (final key in expected.keys) {
      expect(payload[key], expected[key], reason: key);
    }
    await tearDownApp(tester, account);
  });

  testWidgets('one calm message per field; typed text stays; the first is focused', (tester) async {
    final account = await open(tester);
    await tester.tap(find.text('Quantity'));
    await tester.pump();
    await tester.enterText(field('target-amount'), '1.2345');
    await create(tester);

    expect(find.text('This field is needed.'), findsOneWidget);
    expect(find.text('Use up to 3 decimal places.'), findsOneWidget);
    expect(find.text('Add a unit, such as ml or pages.'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNWidgets(3), reason: 'a symbol with each');
    expect(find.text('1.2345'), findsOneWidget, reason: 'typed text is kept');
    final name = tester.widget<EditableText>(
      find.descendant(of: find.byType(TextFormField), matching: find.byType(EditableText)),
    );
    expect(name.focusNode.hasFocus, isTrue, reason: 'the first field with a message');

    for (final (typed, message) in [
      ('abc', 'Use a number, such as 250 or 1.5.'),
      ('0', 'Use a number above zero.'),
      ('-3', 'Use a number above zero.'),
      ('', 'Add a daily target.'),
    ]) {
      await tester.enterText(field('target-amount'), typed);
      await create(tester);
      expect(find.text(message), findsOneWidget, reason: typed);
    }
    await tester.enterText(find.byType(TextFormField), 'x' * 101);
    await create(tester);
    expect(find.text('Use 100 characters or fewer.'), findsOneWidget);
    await tester.enterText(field('target-unit'), 'u' * 25);
    await create(tester);
    expect(find.text('Use 24 characters or fewer.'), findsOneWidget);

    expect(await creates(tester, account), isEmpty, reason: 'nothing written while invalid');
    await tearDownApp(tester, account);
  });

  testWidgets('a duration habit on chosen weekdays: 30 minutes is 1800 seconds', (tester) async {
    final account = await open(tester);
    await tester.enterText(find.byType(TextFormField), 'Pilates');
    await tester.tap(find.text('Duration'));
    await tester.pump();
    await tester.enterText(field('target-amount'), '30');

    await tester.tap(find.text('Edit').first);
    await settle(tester);
    expect(find.byType(FrequencyScreen), findsOneWidget);
    expect(find.text('Choose how often Pilates fits your week.'), findsOneWidget);
    await tester.tap(find.text('Specific weekdays'));
    await tester.pump();
    for (final day in ['Friday', 'Monday', 'Wednesday']) {
      await tester.tap(find.bySemanticsLabel(day));
      await tester.pump();
    }
    await tester.tap(find.text('Use this schedule'));
    await settle(tester);
    expect(find.text('Monday, Wednesday and Friday'), findsOneWidget);
    expect(find.text('30'), findsOneWidget, reason: 'the target survived the trip to 10');

    await create(tester);
    final payload = (await creates(tester, account)).single;
    expect(
      (payload['target_value'], payload['unit'], payload['frequency_type']),
      (1800, null, 'weekdays'),
    );
    expect(payload['target_value'], isA<int>());
    expect(payload['frequency_config'], {
      'days': [1, 3, 5],
    });
    await tearDownApp(tester, account);
  });

  testWidgets('at 200% text 08 renders without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final account = await open(tester);
    await tester.tap(find.text('Quantity'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await create(tester);
    expect(tester.takeException(), isNull, reason: 'with every message showing');
    await tearDownApp(tester, account);
  });
}
