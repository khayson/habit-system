import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/archived_habits_screen.dart';
import 'package:habit/screens/create_habit_screen.dart';
import 'package:habit/screens/habit_detail_screen.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 4.2b: screen 22 and 07's link to it. Offline after the first sync.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late AccountContext account;

  /// Water (archived and synced), Tea (archived on this device, not sent) and Walk (active).
  Future<Map<String, String>> seed(WidgetTester tester, {bool archive = true}) async {
    useTallPhone(tester);
    server = FakeSyncServer();
    account = (await tester.runAsync(() => testAccount(server)))!;
    final ids = <String, String>{};
    await tester.runAsync(() async {
      for (final (name, category) in [
        ('Water', 'health'),
        ('Tea', 'mindfulness'),
        ('Walk', 'health'),
      ]) {
        ids[name] = await account.writer.createHabitUnchecked(
          name: name,
          type: 'binary',
          target: 1,
          category: category,
          startLocalDate: LocalDate.parse('2026-05-01'),
          backdate: true,
        );
      }
      if (archive) await account.writer.archiveHabit(ids['Water']!);
    });
    await syncNow(tester, account);
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
    if (archive) await tester.runAsync(() => account.writer.archiveHabit(ids['Tea']!));
    return ids;
  }

  Future<void> show(WidgetTester tester, String location) async {
    await tester.pumpWidget(testApp(initial: location, account: account));
    await settle(tester);
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  testWidgets('07: "N archived" is a 44 px link to 22', (tester) async {
    final handle = tester.ensureSemantics();
    await seed(tester);
    await show(tester, '/habits');
    expect(find.text('1 active routine · '), findsOneWidget);
    final link = find.widgetWithText(TextButton, '2 archived');
    expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(find.text('2 archived')),
      containsSemantics(isLink: true, hint: 'Opens Archived routines'),
    );
    await tester.tap(link);
    await settle(tester);
    expect(find.byType(ArchivedHabitsScreen), findsOneWidget);
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('07: with nothing archived there is no link', (tester) async {
    await seed(tester, archive: false);
    await show(tester, '/habits');
    expect(find.text('3 active routines · 0 archived'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '0 archived'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('22: two rows, the copy, an unsent archive without a date', (tester) async {
    final handle = tester.ensureSemantics();
    await seed(tester);
    await show(tester, '/habits/archived');
    for (final t in [
      'Archived routines',
      'Taking a pause keeps your past progress.',
      'Tea',
      'Water',
      'Archived · Mindfulness',
      'Archived 28 May · Health',
      'Restore from today',
      'A new active schedule begins today. Archived dates never become missed days.',
      'Start again, gently',
      'You can begin with a tiny routine. No streak needs to be perfect.',
      'Create a new habit →',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Walk'), findsNothing);
    for (final name in ['Tea', 'Water']) {
      final restore = find.bySemanticsLabel('Restore $name');
      expect(tester.getSemantics(restore), containsSemantics(isButton: true, hasTapAction: true));
      expect(tester.getSize(restore).height, greaterThanOrEqualTo(44));
    }
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('22: restore queues habit.restore and the row leaves at once', (tester) async {
    final ids = await seed(tester);
    await show(tester, '/habits/archived');
    await tester.tap(find.widgetWithText(TextButton, 'Restore').last);
    await settle(tester);
    final restore = (await outbox(tester)).last;
    expect((restore.operation, restore.entityId), ('habit.restore', ids['Water']));
    expect(jsonDecode(restore.payload), isEmpty);
    expect(find.text('Water'), findsNothing);
    expect(find.text('Tea'), findsOneWidget);
    expect(find.text('Restored. A new schedule begins today.'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('22 empty: just the two cards; the link opens 08', (tester) async {
    await seed(tester, archive: false);
    await show(tester, '/habits/archived');
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Restore from today'), findsOneWidget);
    expect(find.text('Start again, gently'), findsOneWidget);
    await tester.tap(find.text('Create a new habit →'));
    await settle(tester);
    expect(find.byType(CreateHabitScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('/habits/new and /habits/archived are matched before /habits/:id', (tester) async {
    await seed(tester, archive: false);
    await show(tester, '/habits/archived');
    expect(find.byType(ArchivedHabitsScreen), findsOneWidget);
    expect(find.byType(HabitDetailScreen), findsNothing);
    await show(tester, '/habits/new');
    expect(find.byType(CreateHabitScreen), findsOneWidget);
    expect(find.byType(HabitDetailScreen), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('at 200% text 22 and the 07 link render without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(tester);
    await show(tester, '/habits/archived');
    expect(tester.takeException(), isNull);
    await show(tester, '/habits');
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
  });
}
