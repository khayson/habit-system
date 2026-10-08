import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/notifications/notification_scheduler.dart';
import 'package:habit/providers/account_context.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_scheduler.dart';
import '../support/fake_sync_server.dart';

/// Phase 3.2b: screen 11 and 04's reminder block. Permission states come from the OS (the
/// fake); the OS prompt appears only on a tap of Allow, once; never after "Set up reminders
/// later" or a refusal.
void main() {
  setUpAll(loadTestZones);

  Future<(AccountContext, FakeNotificationScheduler)> open(
    WidgetTester tester,
    String location, {
    FakeNotificationScheduler? os,
  }) async {
    useTallPhone(tester);
    final scheduler = os ?? FakeNotificationScheduler();
    final account = (await tester.runAsync(
      () => testAccount(FakeSyncServer(), notifications: scheduler),
    ))!;
    await tester.pumpWidget(testApp(initial: location, account: account));
    await settle(tester);
    return (account, scheduler);
  }

  testWidgets('04: Allow prompts once; after a refusal it offers Settings, never a 2nd prompt', (
    tester,
  ) async {
    final (account, os) = await open(tester, '/setup');
    expect(find.text('Local reminders'), findsOneWidget);
    expect(find.text('Not allowed yet'), findsOneWidget);
    expect(find.text('Reminders work offline'), findsOneWidget);
    expect(find.text('Set up reminders later'), findsOneWidget);
    expect(os.requests, 0, reason: 'nothing asks on open');

    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(os.requests, 1);
    expect(find.text('Off in device settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await settle(tester);
    expect((os.requests, os.settingsOpened), (1, 1), reason: 'no second prompt');
    await tearDownApp(tester, account);
  });

  testWidgets('04: an allowed device says so and offers nothing to tap', (tester) async {
    final os = FakeNotificationScheduler()..osState = NotificationPermission.authorized;
    final (account, _) = await open(tester, '/setup', os: os);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Allow'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('opening 11 never prompts by itself', (tester) async {
    final (account, os) = await open(tester, '/reminders/edit');
    expect(find.text('Gentle reminders'), findsOneWidget);
    expect(find.text('Notifications are not allowed yet'), findsOneWidget);
    expect(os.requests, 0);
    await tearDownApp(tester, account);
  });

  testWidgets('11 denied: the device truth, Settings and when the next reminder is due', (
    tester,
  ) async {
    final os = FakeNotificationScheduler()..osState = NotificationPermission.denied;
    final (account, _) = await open(tester, '/reminders/edit', os: os);

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(
      find.text('Enable notifications in device settings before these reminders can appear.'),
      findsOneWidget,
    );
    expect(find.textContaining('Next reminder: '), findsOneWidget);
    expect(find.text('Ready when permission is allowed'), findsOneWidget);
    expect(
      find.text(
        'Local reminders do not depend on a network connection. Battery settings may delay delivery.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open device settings'));
    await settle(tester);
    expect((os.requests, os.settingsOpened), (0, 1));
    await tearDownApp(tester, account);
  });

  testWidgets('08 -> 11 -> 08: the draft comes back; Create writes habit and reminder together', (
    tester,
  ) async {
    final (account, _) = await open(tester, '/habits/new');
    await tester.enterText(find.byType(TextField).first, 'Evening stretch');
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('Gentle reminders'), findsOneWidget);
    expect(find.text('Evening stretch · notifications stay on your device.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^8:30\sPM$')), findsOneWidget);
    expect(find.text('Repeat every day'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Sunday, on'));
    await tester.tap(find.bySemanticsLabel('Saturday, on'));
    await settle(tester);
    expect(find.text('Repeat on weekdays'), findsOneWidget);
    await tester.tap(find.text('Save reminder'));
    await settle(tester);

    expect(find.textContaining(RegExp(r'^8:30\sPM · local device time$')), findsOneWidget);
    await tester.tap(find.text('Create habit'));
    await settle(tester);

    final rows = (await tester.runAsync(
      () => account.session.db.select(account.session.db.outbox).get(),
    ))!;
    expect(rows.map((r) => r.operation), ['habit.create', 'reminder.create']);
    final payload = jsonDecode(rows.last.payload) as Map<String, dynamic>;
    expect(payload['habit_id'], rows.first.entityId);
    expect(
      [
        payload['local_time'],
        payload['days_of_week'],
        payload['timezone_mode'],
        payload['enabled'],
      ],
      [
        '20:30',
        [1, 2, 3, 4, 5],
        'device_zone',
        true,
      ],
    );
    await tearDownApp(tester, account);
  });

  testWidgets('11 refuses a reminder with no days in plain words', (tester) async {
    final (account, _) = await open(tester, '/reminders/edit');
    for (final day in [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      await tester.tap(find.bySemanticsLabel('$day, on'));
    }
    await settle(tester);
    await tester.tap(find.text('Save reminder'));
    await settle(tester);
    expect(find.text('Choose at least one day.'), findsOneWidget);
    expect(find.text('Gentle reminders'), findsOneWidget, reason: 'still on 11');
    await tearDownApp(tester, account);
  });
}
