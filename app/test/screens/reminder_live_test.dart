import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/providers/account_context.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 3.2c (K1): screen 11 in live mode for a habit that exists, reached from 12's Reminder
/// row. Every change goes through LocalMutationService and lands in the outbox.
void main() {
  setUpAll(loadTestZones);

  Future<(AccountContext, FakeSyncServer, String)> habitOnDevice(WidgetTester tester) async {
    useTallPhone(tester);
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    final habit = (await tester.runAsync(
      () => account.actions.createOneTapHabit(name: 'Stretch', category: 'health'),
    ))!;
    await syncNow(tester, account);
    return (account, server, habit);
  }

  Future<List<OutboxRow>> reminderRows(WidgetTester tester, AccountContext account) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!
          .where((r) => r.entity == 'reminder')
          .toList();

  Map<String, dynamic> payload(OutboxRow row) =>
      (jsonDecode(row.payload) as Map).cast<String, dynamic>();

  Future<void> show(WidgetTester tester, AccountContext account, String location) async {
    await tester.pumpWidget(testApp(initial: location, account: account));
    await settle(tester);
  }

  testWidgets('12 shows None; 11 adds the first reminder with the defaults', (tester) async {
    final (account, _, habit) = await habitOnDevice(tester);
    await show(tester, account, '/habits/$habit');
    await tester.scrollUntilVisible(find.text('None'), 200);
    expect(find.text('Reminder'), findsOneWidget);

    await tester.tap(find.text('None'));
    await settle(tester);
    expect(find.text('Gentle reminders'), findsOneWidget);
    expect(find.text('Stretch · notifications stay on your device.'), findsOneWidget);
    expect(find.text('Remove reminder'), findsNothing, reason: 'nothing to remove yet');

    await tester.tap(find.text('Save reminder'));
    await settle(tester);

    final row = (await reminderRows(tester, account)).single;
    expect(row.operation, 'reminder.create');
    expect(
      [
        payload(row)['habit_id'],
        payload(row)['local_time'],
        payload(row)['days_of_week'],
        payload(row)['timezone_mode'],
        payload(row)['enabled'],
      ],
      [
        habit,
        '20:30',
        [1, 2, 3, 4, 5, 6, 7],
        'device_zone',
        true,
      ],
    );
    await tearDownApp(tester, account);
  });

  testWidgets('a synced reminder: edit sends an update on its version; off shows Off on 12', (
    tester,
  ) async {
    final (account, _, habit) = await habitOnDevice(tester);
    await tester.runAsync(
      () => account.writer.createReminder(
        habitId: habit,
        localTime: '08:00',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      ),
    );
    await syncNow(tester, account);
    await show(tester, account, '/habits/$habit/reminder');
    expect(find.textContaining(RegExp(r'^8:00\sAM$')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Sunday, on'));
    await tester.tap(find.byType(Switch));
    await settle(tester);
    await tester.tap(find.text('Save reminder'));
    await settle(tester);

    final row = (await reminderRows(tester, account)).single;
    expect((row.operation, row.baseVersion), ('reminder.update', 1));
    expect(
      [payload(row)['local_time'], payload(row)['days_of_week'], payload(row)['enabled']],
      [
        '08:00',
        [1, 2, 3, 4, 5, 6],
        false,
      ],
    );

    await tester.pumpWidget(const SizedBox());
    await show(tester, account, '/habits/$habit');
    await tester.scrollUntilVisible(find.text('Off'), 200);
    expect(find.text('Off'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('unsent: a create and a later edit coalesce into one create', (tester) async {
    final (account, _, habit) = await habitOnDevice(tester);
    await show(tester, account, '/habits/$habit/reminder');
    await tester.tap(find.text('Save reminder'));
    await settle(tester);

    await tester.pumpWidget(const SizedBox());
    await show(tester, account, '/habits/$habit/reminder');
    await tester.tap(find.bySemanticsLabel('Saturday, on'));
    await settle(tester);
    await tester.tap(find.text('Save reminder'));
    await settle(tester);

    final rows = await reminderRows(tester, account);
    expect(rows.map((r) => r.operation), ['reminder.create']);
    expect(payload(rows.single)['days_of_week'], [1, 2, 3, 4, 5, 7]);
    await tearDownApp(tester, account);
  });

  testWidgets('remove after a synced create is a delete on the acked version', (tester) async {
    final (account, _, habit) = await habitOnDevice(tester);
    await tester.runAsync(
      () =>
          account.writer.createReminder(habitId: habit, localTime: '08:00', daysOfWeek: [1, 2, 3]),
    );
    await syncNow(tester, account);
    await show(tester, account, '/habits/$habit/reminder');

    await tester.tap(find.text('Remove reminder'));
    await settle(tester);

    final row = (await reminderRows(tester, account)).single;
    expect((row.operation, row.baseVersion), ('reminder.delete', 1));
    await tester.pumpWidget(const SizedBox());
    await show(tester, account, '/habits/$habit');
    await tester.scrollUntilVisible(find.text('None'), 200);
    expect(find.text('None'), findsOneWidget, reason: 'removed on this device at once');
    await tearDownApp(tester, account);
  });

  testWidgets('several reminders: the first is edited, the rest are listed and open in 11', (
    tester,
  ) async {
    final (account, _, habit) = await habitOnDevice(tester);
    final ids = <String>[];
    for (final time in ['07:00', '12:30', '18:00']) {
      ids.add(
        (await tester.runAsync(
          () => account.writer.createReminder(
            habitId: habit,
            localTime: time,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          ),
        ))!,
      );
    }
    await syncNow(tester, account);
    await show(tester, account, '/habits/$habit/reminder');

    expect(find.textContaining(RegExp(r'^7:00\sAM$')), findsOneWidget, reason: 'the first by id');
    expect(find.text('Other reminders'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Edit the reminder at 12:30\sPM$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Edit the reminder at 6:00\sPM$')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Edit the reminder at 12:30\sPM$')));
    await settle(tester);
    expect(find.textContaining(RegExp(r'^12:30\sPM$')), findsOneWidget, reason: 'now editing it');
    expect(find.bySemanticsLabel(RegExp(r'^Edit the reminder at 7:00\sAM$')), findsOneWidget);
    await tearDownApp(tester, account);
  });
}
