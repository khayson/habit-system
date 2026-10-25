import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/widgets/habit_swipe.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 6.6 (A51): swipe to archive or delete on Habits (07) and Archived routines (22), the
/// confirmation, the habit-detail entry and the screen-reader actions. Never on Today.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;

  setUp(() => server = FakeSyncServer());

  /// One synced habit with a check-in and a reminder, then an unsent check-in and a timer.
  Future<(AccountContext, String)> withStretch(WidgetTester tester) async {
    useTallPhone(tester);
    final account = (await tester.runAsync(() => testAccount(server)))!;
    final id = (await tester.runAsync(() async {
      final id = await account.writer.createHabitUnchecked(
        name: 'Stretch',
        type: 'duration',
        target: 600,
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-20'),
        backdate: true,
      );
      await account.writer.createReminder(habitId: id, localTime: '08:00', daysOfWeek: [1, 2, 3]);
      await account.sync.sync(force: true);
      await account.writer.setLogValue(habitId: id, value: 300);
      await account.writer.startTimer(id);
      return id;
    }))!;
    return (account, id);
  }

  Future<void> open(WidgetTester tester, AccountContext account, String at) async {
    await tester.pumpWidget(testApp(initial: at, account: account));
    await settle(tester);
  }

  Future<void> swipe(WidgetTester tester, String name, double fraction) async {
    final row = find.ancestor(of: find.text(name), matching: find.byType(HabitSwipe));
    final width = tester.getSize(row).width;
    await tester.drag(row, Offset(width * fraction, 0));
    await settle(tester);
  }

  Future<List<String>> operations(AccountContext a) async =>
      (await outboxOf(a)).map((r) => r.operation).toList();

  testWidgets('a far-end swipe right archives at once, and Undo restores', (tester) async {
    final (account, id) = await withStretch(tester);
    await open(tester, account, '/habits');

    await swipe(tester, 'Stretch', 0.9);

    expect(find.text('Archived Stretch.'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(HabitSwipe), matching: find.text('Stretch')),
      findsNothing,
    );
    expect(await tester.runAsync(() => operations(account)), contains('habit.archive'));

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Stretch'), findsOneWidget);
    expect(
      await tester.runAsync(() => operations(account)),
      containsAllInOrder(['habit.archive', 'habit.restore']),
    );
    await tearDownApp(tester, account);
  });

  testWidgets('a short swipe shows the action and springs back, doing nothing', (tester) async {
    final (account, _) = await withStretch(tester);
    await open(tester, account, '/habits');
    final before = await tester.runAsync(() => operations(account));

    final row = find.ancestor(of: find.text('Stretch'), matching: find.byType(HabitSwipe));
    final gesture = await tester.startGesture(tester.getCenter(row));
    // Past the drag slop first, then on to about 30 % of the row.
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveBy(Offset(tester.getSize(row).width * 0.3 - 24, 0));
    await tester.pump();
    expect(find.text('Archive'), findsOneWidget, reason: 'the action shows in words');
    await gesture.up();
    await settle(tester);

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Archived Stretch.'), findsNothing);
    expect(await tester.runAsync(() => operations(account)), before);

    await swipe(tester, 'Stretch', -0.3);
    expect(find.text('Delete Stretch?'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('a far-end swipe left only asks; Keep habit changes nothing', (tester) async {
    final (account, _) = await withStretch(tester);
    await open(tester, account, '/habits');
    final before = await tester.runAsync(() => operations(account));

    await swipe(tester, 'Stretch', -0.9);

    expect(find.text('Delete Stretch?'), findsOneWidget);
    expect(
      find.text(
        'This removes the habit, its check-ins, notes and reminders from all your devices. '
        'XP you earned stays.',
      ),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => operations(account)), before, reason: 'nothing yet');
    // Above everything: the bottom bar cannot be used while the question is open.
    expect(
      tester.getRect(find.byType(BottomSheet)).bottom,
      tester.getSize(find.byType(MaterialApp)).height,
      reason: 'the sheet reaches the bottom of the screen, over the bottom bar',
    );
    await tester.tap(find.text('Keep habit'));
    await settle(tester);
    expect(find.text('Delete Stretch?'), findsNothing);
    expect(find.text('Stretch'), findsOneWidget);
    expect(await tester.runAsync(() => operations(account)), before);
    await tearDownApp(tester, account);
  });

  testWidgets('Delete habit removes it, its check-ins, draft, reminders and unsent rows, '
      'and queues one habit.delete', (tester) async {
    final (account, id) = await withStretch(tester);
    await open(tester, account, '/habits');

    await swipe(tester, 'Stretch', -0.9);
    await tester.tap(find.text('Delete habit'));
    await settle(tester);

    expect(find.text('Deleted Stretch.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing, reason: 'a delete has no Undo');
    expect(find.text('Stretch'), findsNothing);
    final db = account.session.db;
    final left = (await tester.runAsync(
      () async => (
        (await db.select(db.habits).get()).length,
        (await db.select(db.habitLogs).get()).length,
        (await db.select(db.reminders).get()).length,
        (await db.select(db.timerDrafts).get()).length,
      ),
    ))!;
    expect(left, (0, 0, 0, 0));
    final outbox = (await tester.runAsync(() => outboxOf(account)))!;
    expect(outbox.map((r) => (r.operation, r.entityId, r.state)), [
      ('habit.delete', id, OutboxState.pending),
    ]);
    await tearDownApp(tester, account);
  });

  testWidgets('every swipeable row has Archive and Delete as screen-reader actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (account, _) = await withStretch(tester);
    await open(tester, account, '/habits');
    final row = find.ancestor(of: find.text('Stretch'), matching: find.byType(HabitSwipe));

    expect(
      tester.getSemantics(row),
      isSemantics(
        customActions: [
          const CustomSemanticsAction(label: 'Archive'),
          const CustomSemanticsAction(label: 'Delete'),
        ],
      ),
    );
    final node = tester.getSemantics(row);
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Delete')),
    );
    await settle(tester);
    expect(find.text('Delete Stretch?'), findsOneWidget);
    await tester.tap(find.text('Keep habit'));
    await settle(tester);
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('habit detail offers Delete habit at the end, then returns to Habits', (
    tester,
  ) async {
    final (account, id) = await withStretch(tester);
    await open(tester, account, '/habits/$id');

    await tester.scrollUntilVisible(find.text('Delete habit'), 300);
    await tester.tap(find.text('Delete habit'));
    await settle(tester);
    expect(find.text('Delete Stretch?'), findsOneWidget);
    await tester.tap(find.text('Delete habit').last);
    await settle(tester);

    expect(find.text('Deleted Stretch.'), findsOneWidget);
    expect(find.text('Your habits'), findsOneWidget, reason: 'back on 07');
    await tearDownApp(tester, account);
  });

  testWidgets('on Archived routines a swipe right restores with Undo and a swipe left asks', (
    tester,
  ) async {
    final (account, id) = await withStretch(tester);
    await tester.runAsync(() => account.actions.archiveHabit(id));
    await open(tester, account, '/habits/archived');

    await swipe(tester, 'Stretch', -0.9);
    expect(find.text('Delete Stretch?'), findsOneWidget);
    await tester.tap(find.text('Keep habit'));
    await settle(tester);

    await swipe(tester, 'Stretch', 0.9);
    expect(find.text('Restored Stretch.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('Today has no swipe', (tester) async {
    final (account, _) = await withStretch(tester);
    await open(tester, account, '/today');
    expect(find.byType(HabitSwipe), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('a habit deleted on another device leaves the list after a sync', (tester) async {
    final (account, id) = await withStretch(tester);
    // Another device's delete, straight to the server.
    await tester.runAsync(
      () => server.sync(
        deviceId: '01970000-0000-7000-8000-00000000d0ff',
        cursor: null,
        pullLimit: 100,
        capabilities: const [],
        mutations: [
          {
            'mutation_id': '01970000-0000-7000-8000-0000000000de',
            'entity': 'habit',
            'entity_id': id,
            'operation': 'habit.delete',
            'base_version': server.habits[id]!['version'],
            'occurred_at': '2026-05-28T17:22:00Z',
            'captured_timezone': 'America/Los_Angeles',
            'local_date_hint': null,
            'payload': <String, Object?>{},
          },
        ],
      ),
    );
    await open(tester, account, '/habits');
    expect(find.text('Stretch'), findsOneWidget);

    // Like the other screen tests, sync with no screen mounted, then look again.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => account.sync.sync(force: true));
    await open(tester, account, '/habits');
    expect(find.text('Stretch'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('text scale 2.0 keeps the confirmation readable down to Delete habit', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (account, _) = await withStretch(tester);
    await open(tester, account, '/habits');

    await swipe(tester, 'Stretch', -0.9);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Delete habit'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
  });
}

Future<List<OutboxRow>> outboxOf(AccountContext a) {
  final db = a.session.db;
  return (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();
}
