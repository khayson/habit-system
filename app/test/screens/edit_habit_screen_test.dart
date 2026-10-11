import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/edit_habit_screen.dart';
import 'package:habit/screens/sync_queue_screen.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';

/// Phase 4.2b: screen 09 (edit), its entry on 12, and archive. The habit is synced first; the
/// screens then run offline (every sync attempt fails as no network).
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late AccountContext account;
  late String habitId;

  Future<void> seed(
    WidgetTester tester, {
    String type = 'quantity',
    Object target = '2000.000',
    String? unit = 'ml',
    String category = 'health',
    bool pendingVersion = false,
  }) async {
    useTallPhone(tester);
    server = FakeSyncServer(knownTypes: {'binary', 'quantity', 'duration', 'sleep_window'});
    account = (await tester.runAsync(() => testAccount(server)))!;
    habitId = (await tester.runAsync(
      () => account.writer.createHabitUnchecked(
        name: 'Water',
        type: type,
        target: target,
        unit: unit,
        category: category,
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      ),
    ))!;
    await syncNow(tester, account);
    if (pendingVersion) {
      // Another device raised the target; the server dated it tomorrow.
      server.serverEditHabit(habitId, (h) {
        final v1 = (h['definitions'] as List).first as Map<String, dynamic>;
        h['target_value'] = '2500.000';
        h['definition_version'] = 2;
        h['definitions'] = [
          v1,
          {...v1, 'version': 2, 'effective_date': '2026-05-29', 'target_value': '2500.000'},
        ];
      });
      await syncNow(tester, account);
    }
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
  }

  Future<void> show(WidgetTester tester, String location) async {
    await tester.pumpWidget(testApp(initial: location, account: account));
    await settle(tester);
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  Map<String, dynamic> payload(OutboxRow row) => jsonDecode(row.payload) as Map<String, dynamic>;

  Future<void> save(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await settle(tester);
  }

  Finder field(String key) => find.byKey(ValueKey(key));

  testWidgets('starts from the latest definition, with its copy and the dated note', (
    tester,
  ) async {
    await seed(tester, pendingVersion: true);
    await show(tester, '/habits/$habitId/edit');
    for (final t in [
      'Edit Water',
      'Adjust your routine without losing history.',
      'Target and unit',
      'Type: Quantity',
      "A habit's type can't be changed. Start a new habit to try a different one.",
      'Category',
      'Health',
      'Schedule',
      'Every day',
      'Reminders',
      'Not set',
      'History stays unchanged',
      'New targets apply from the next eligible period. Past check-ins keep their original target.',
      'New target starts May 29',
      'Archive this habit',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('2500'), findsOneWidget, reason: 'the latest target, not the 2000 in force');
    expect(find.text('ml'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('a target change: habit.update with the six keys of the fixture, then waiting', (
    tester,
  ) async {
    await seed(tester);
    await show(tester, '/habits/$habitId/edit');
    await tester.enterText(field('target-amount'), '2500');
    await save(tester);

    final row = (await outbox(tester)).single;
    final rules = (contractFixture('habit/habit_mutations.json')['rules'] as List).first as String;
    expect(row.operation, 'habit.update');
    final sent = payload(row);
    expect(sent.keys.toSet(), {
      'name',
      'category',
      'target_value',
      'unit',
      'frequency_type',
      'frequency_config',
    }, reason: rules);
    expect(
      (sent['name'], sent['target_value'], sent['unit'], sent['frequency_type']),
      ('Water', '2500.000', 'ml', 'daily'),
    );
    expect(find.text('Edit Water'), findsNothing, reason: 'saved: back on the habit');

    await show(tester, '/habits/$habitId/edit');
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('2500'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a rename alone is not a definition change: no waiting note', (tester) async {
    await seed(tester);
    await show(tester, '/habits/$habitId/edit');
    await tester.enterText(find.byType(TextFormField), 'Water daily');
    await save(tester);
    expect(payload((await outbox(tester)).single)['name'], 'Water daily');
    await show(tester, '/habits/$habitId/edit');
    expect(find.text('Edit Water daily'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('an unchanged save writes nothing and closes', (tester) async {
    await seed(tester);
    await show(tester, '/habits/$habitId/edit');
    await save(tester);
    expect(await outbox(tester), isEmpty);
    expect(find.byType(EditHabitScreen), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('messages per field; typed text stays; nothing written', (tester) async {
    await seed(tester);
    await show(tester, '/habits/$habitId/edit');
    await tester.enterText(find.byType(TextFormField), '  ');
    await tester.enterText(field('target-amount'), '1.2345');
    await tester.enterText(field('target-unit'), '');
    await save(tester);
    expect(find.text('This field is needed.'), findsOneWidget);
    expect(find.text('Use up to 3 decimal places.'), findsOneWidget);
    expect(find.text('Add a unit, such as ml or pages.'), findsOneWidget);
    expect(find.text('1.2345'), findsOneWidget);
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('L3: a productivity habit keeps its category through a rename', (tester) async {
    final handle = tester.ensureSemantics();
    await seed(tester, category: 'productivity');
    await show(tester, '/habits/$habitId/edit');
    expect(find.text('Productivity'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Edit Category'));
    await settle(tester);
    expect(find.text('Choose a category'), findsOneWidget);
    for (final c in ['Health', 'Mindfulness', 'Learning']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    expect(
      tester.getSemantics(
        find.ancestor(of: find.text('Productivity').last, matching: find.byType(ListTile)),
      ),
      containsSemantics(isSelected: true),
    );
    await tester.tap(find.text('Productivity').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), 'Inbox zero');
    await save(tester);
    final sent = payload((await outbox(tester)).single);
    expect((sent['name'], sent['category']), ('Inbox zero', 'productivity'));
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('L3: an "other" habit is offered "Other" in the chooser', (tester) async {
    await seed(tester, category: 'other');
    await show(tester, '/habits/$habitId/edit');
    await tester.tap(find.text('Edit').first);
    await settle(tester);
    expect(find.text('Other'), findsNWidgets(2), reason: 'the row and the chooser option');
    await tearDownApp(tester, account);
  });

  testWidgets('archive asks first, writes habit.archive, then opens the library', (tester) async {
    await seed(tester);
    await show(tester, '/habits/$habitId/edit');
    await tester.scrollUntilVisible(
      find.text('Archive this habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Archive this habit'));
    await settle(tester);
    expect(find.text('Archive this habit?'), findsOneWidget);
    expect(
      find.text(
        'Your history stays. It leaves Today and sends no reminders. '
        'You can restore it from Archived routines.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(await outbox(tester), isEmpty);

    await tester.tap(find.text('Archive this habit'));
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);
    final row = (await outbox(tester)).single;
    expect(row.operation, 'habit.archive');
    expect(payload(row), isEmpty);
    expect(find.text('Your habits'), findsOneWidget, reason: 'the library, not an archived detail');
    await tearDownApp(tester, account);
  });

  testWidgets('12: Edit opens 09', (tester) async {
    await seed(tester);
    await show(tester, '/habits/$habitId');
    final edit = find.text('Edit').first;
    expect(
      tester.getSize(find.ancestor(of: edit, matching: find.byType(TextButton))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(edit);
    await settle(tester);
    expect(find.byType(EditHabitScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a change that needs a look: no edit on 12 or 09, the reason and the way', (
    tester,
  ) async {
    await seed(tester);
    await tester.runAsync(() async {
      final d = (await account.view.habits()).single.editable!;
      await account.writer.updateHabit(
        habitId,
        HabitDraft(
          name: 'Water!',
          category: d.category,
          targetValue: d.targetValue,
          unit: d.unit,
          frequencyType: d.frequencyType,
          frequencyConfig: d.frequencyConfig,
        ),
      );
      await (account.session.db.update(account.session.db.outbox))
          .write(const OutboxCompanion(state: Value(OutboxState.needsAttention)));
    });
    await show(tester, '/habits/$habitId');
    const reason = 'A change to this habit needs a look before you can edit it.';
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Edit'), findsNothing);

    await show(tester, '/habits/$habitId/edit');
    expect(find.text(reason), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Review the change'));
    await settle(tester);
    expect(find.byType(SyncQueueScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('an unknown type: read-only, no edit controls anywhere', (tester) async {
    await seed(tester, type: 'sleep_window', target: 8, unit: null);
    await show(tester, '/habits/$habitId/edit');
    expect(find.text('This habit needs a newer version of the app'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Save changes'), findsNothing);
    await show(tester, '/habits/$habitId');
    expect(find.text('Edit'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('at 200% text 09 and its sheets render without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(tester, pendingVersion: true);
    await show(tester, '/habits/$habitId/edit');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Edit').first);
    await settle(tester);
    await tester.tap(find.text('Edit').first);
    await settle(tester);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the category chooser');
    await tester.tap(find.text('Health').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Archive this habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Archive this habit'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'the archive sheet');
    await tearDownApp(tester, account);
  });
}
