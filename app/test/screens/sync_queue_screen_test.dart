import 'package:flutter_test/flutter_test.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';
import '../support/fake_notification_scheduler.dart';

/// Screen 18: counts, the queued changes, offline and paused states, discard and try again.
void main() {
  setUpAll(loadTestZones);

  testWidgets('offline: queued changes stay listed with a plain explanation', (tester) async {
    final online = connectivityController();
    final account = (await tester.runAsync(
      () async => AccountContext(
        session: (await testAccount(FakeSyncServer())).session,
        transport: OfflineTransport(),
        refreshIfStale: () async {},
        notifications: FakeNotificationScheduler(),
        connectivity: online.stream,
        clock: () => testNow,
      ),
    ))!;
    await tester.runAsync(() async {
      final habit = await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.writer.setLogValue(habitId: habit, value: 1);
    });
    await syncNow(tester, account);
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);

    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Waiting for a connection'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'pending check-ins');
    expect(find.text('Pending check-ins'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget, reason: 'never synced');
    expect(find.text('Stretch · New habit'), findsOneWidget);
    expect(find.text('Stretch · Checked in'), findsOneWidget);
    expect(find.text('Queued'), findsNWidgets(2));
    await online.close();
    await tearDownApp(tester, account);
  });

  testWidgets('paused: the reason is shown and nothing is dropped', (tester) async {
    final account = (await tester.runAsync(() => testAccount(FakeSyncServer())))!;
    await tester.runAsync(() async {
      await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.session.db.customStatement(
        "UPDATE sync_state SET status = 'paused', status_code = 'validation_failed'",
      );
    });
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);

    expect(find.text('Sync paused'), findsOneWidget);
    expect(find.text('Sync is paused'), findsOneWidget);
    expect(find.textContaining('(validation_failed)'), findsOneWidget);
    expect(find.text('Stretch · New habit'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a change that needs a look can be discarded after confirming', (tester) async {
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      final habit = await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.sync.sync(force: true);
      await account.writer.setLogValue(habitId: habit, value: 1);
      await account.session.db.customStatement(
        "UPDATE outbox SET state = '${OutboxState.needsAttention}', "
        "last_error = '{\"code\":\"resource_deleted\"}'",
      );
    });
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);

    expect(find.text('Needs a look'), findsNWidgets(2), reason: 'chip and row');
    expect(find.text('It was removed on another device first.'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Stretch · Checked in'), findsOneWidget, reason: 'cancel keeps it');

    await tester.tap(find.text('Discard'));
    await settle(tester);
    await tester.tap(find.text('Discard').last);
    await settle(tester);

    expect(find.text('Stretch · Checked in'), findsNothing);
    expect(find.text('Everything is synced'), findsOneWidget);
    final record = (await tester.runAsync(
      () => account.session.db.select(account.session.db.discardedMutations).get(),
    ))!;
    expect(record, hasLength(1), reason: 'the discard is recorded');
    await tearDownApp(tester, account);
  });

  testWidgets('a profile edit that changed elsewhere first is described in words (3b)', (
    tester,
  ) async {
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      await account.writer.updateProfile(name: 'Maya Chen', city: 'Accra', countryCode: 'GH');
      server.bumpUserVersion();
      await account.sync.sync(force: true);
    });
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);

    expect(find.text('Your profile · Name and location'), findsOneWidget);
    expect(find.text('It changed on another device first.'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a change that is backing off can be tried again now', (tester) async {
    final server = FakeSyncServer();
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      final habit = await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.sync.sync(force: true);
      final write = await account.writer.setLogValue(habitId: habit, value: 1);
      server.serverErrorFor.add(write.mutationId);
      await account.sync.sync(force: true);
      server.serverErrorFor.clear();
    });
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);

    expect(find.text('Retrying later'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    await tester.tap(find.text('Sync now'));
    await settle(tester, rounds: 12);

    expect(find.text('Everything is synced'), findsOneWidget);
    expect(server.logs, hasLength(1));
    await tearDownApp(tester, account);
  });
}
