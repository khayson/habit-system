import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/conflict_review_screen.dart';
import 'package:habit/screens/sync_queue_screen.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.3c: screen 19 in each variant, and its links. The phone is the app's account; the
/// tablet is a second device on the same fake server that changes things first.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  late AccountContext account;
  late Device tablet;
  late String habitId;
  final today = LocalDate.parse('2026-05-28');

  Future<void> seed(
    WidgetTester tester, {
    String name = 'Water',
    String type = 'quantity',
    Object target = '2.000',
    String? unit = 'L',
    Object saved = '1.000',
  }) async {
    useTallPhone(tester);
    server = FakeSyncServer();
    account = (await tester.runAsync(() => testAccount(server)))!;
    await tester.runAsync(() async {
      habitId = await account.writer.createHabitUnchecked(
        name: name,
        type: type,
        target: target,
        unit: unit,
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      );
      await account.writer.setLogValue(habitId: habitId, value: saved);
    });
    await syncNow(tester, account);
    tablet = (await tester.runAsync(
      () => Device(server, deviceId: '01970000-0000-7000-8000-00000000d002').init(),
    ))!;
    await tester.runAsync(() => tablet.sync(force: true));
    addTearDown(() => tablet.db.close());
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  Future<OutboxRow> attention(WidgetTester tester) async =>
      (await outbox(tester)).singleWhere((r) => r.state == OutboxState.needsAttention);

  /// The tablet changes the day first; the phone's own write then needs a look.
  Future<OutboxRow> staleValue(WidgetTester tester, {Object tabletValue = '1.750'}) async {
    await tester.runAsync(() async {
      await tablet.writer.setLogValue(habitId: habitId, value: tabletValue);
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: '1.500'));
    await syncNow(tester, account);
    return attention(tester);
  }

  Future<void> open(WidgetTester tester, String mutationId) async {
    await tester.pumpWidget(testApp(initial: '/sync/review/$mutationId', account: account));
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(text));
    await settle(tester);
  }

  testWidgets('stale value: the design copy, both cards with versions, read as groups', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await seed(tester);
    final row = await staleValue(tester);
    await open(tester, row.mutationId);
    for (final t in [
      'Review one change',
      'Both devices edited the same Water entry on 28 May.',
      'Your check-in is safe',
      'This absolute edit needs your choice. Quantity increments normally merge automatically.',
      'Your choice becomes a reviewed edit against the latest version. If it changes again, you will review it again.',
      'Keep synced value · 1.75 L',
      'Use my value · 1.5 L',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(
      find.bySemanticsLabel(
        RegExp(r'^On this device: 1\.5 L\. Edited at 10:22\sAM · based on version 1$'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Latest synced entry: 1.75 L. Edited on another device · version 2'),
      findsOneWidget,
    );
    for (final b in [find.text('Keep synced value · 1.75 L'), find.text('Use my value · 1.5 L')]) {
      expect(
        tester.getSize(find.ancestor(of: b, matching: find.byType(FilledButton))).height,
        greaterThanOrEqualTo(52),
      );
    }
    handle.dispose();
    await tearDownApp(tester, account);
  });

  testWidgets('L1 (4.3c review): never the discard-only variant while the habit loads', (
    tester,
  ) async {
    await seed(tester);
    final row = await staleValue(tester);
    await tester.pumpWidget(testApp(initial: '/sync/review/${row.mutationId}', account: account));
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      expect(find.text('Discard this change'), findsNothing, reason: 'frame $i');
    }
    await settle(tester);
    expect(find.text('Keep synced value · 1.75 L'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('keep synced removes the row, sends nothing, and says so', (tester) async {
    await seed(tester);
    final row = await staleValue(tester);
    await open(tester, row.mutationId);
    final sent = server.sentMutationIds.expand((i) => i).length;
    await tapText(tester, 'Keep synced value · 1.75 L');
    expect(await outbox(tester), isEmpty);
    expect(server.sentMutationIds.expand((i) => i).length, sent);
    expect(find.text('Kept the synced value.'), findsOneWidget);
    expect(find.byType(ConflictReviewScreen), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('use mine queues a new id on the server version in the old place', (tester) async {
    await seed(tester);
    final row = await staleValue(tester);
    await open(tester, row.mutationId);
    await tapText(tester, 'Use my value · 1.5 L');
    final fresh = (await outbox(tester)).single;
    expect(fresh.mutationId, isNot(row.mutationId));
    expect((fresh.seq, fresh.baseVersion, fresh.state), (row.seq, 2, OutboxState.pending));
    expect(find.text('Your choice is saved on this device and will sync.'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a second conflict returns the row to needs_attention and 19 shows it again', (
    tester,
  ) async {
    await seed(tester);
    final row = await staleValue(tester);
    await tester.runAsync(() => account.writer.useMine(row.mutationId));
    await tester.runAsync(() async {
      await tablet.sync(force: true);
      await tablet.writer.setLogValue(habitId: habitId, value: '1.900');
      await tablet.sync(force: true);
    });
    await syncNow(tester, account);
    final again = await attention(tester);
    await open(tester, again.mutationId);
    expect(find.text('Keep synced value · 1.9 L'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('a stale removal: Entry removed and Remove the entry', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.setLogValue(habitId: habitId, value: '1.750');
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.deleteLog(habitId: habitId, date: today));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.text('Entry removed'), findsOneWidget);
    expect(find.text('Keep synced value · 1.75 L'), findsOneWidget);
    expect(find.text('Remove the entry'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  Future<void> tabletDeletes(WidgetTester tester) => tester.runAsync(() async {
    await tablet.writer.deleteLog(habitId: habitId, date: today);
    await tablet.sync(force: true);
  });

  testWidgets('deleted day: Keep it deleted leaves it gone', (tester) async {
    await seed(tester);
    await tabletDeletes(tester);
    await tester.runAsync(() => account.writer.incrementLog(habitId: habitId, delta: '0.5'));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    for (final t in [
      'This Water entry was deleted on another device.',
      'The entry for this day was deleted on another device. Your change stays here until you choose.',
      'Deleted',
      'Keep it deleted',
      'Bring it back · 0.5 L',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('based on version'), findsNothing, reason: 'an increment has none');
    expect(find.textContaining(RegExp(r'^Added at 10:22\sAM$')), findsOneWidget);
    await tapText(tester, 'Keep it deleted');
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('deleted day: Bring it back queues a restore of the amount', (tester) async {
    await seed(tester);
    await tabletDeletes(tester);
    await tester.runAsync(() => account.writer.incrementLog(habitId: habitId, delta: '0.5'));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    await tapText(tester, 'Bring it back · 0.5 L');
    final fresh = (await outbox(tester)).single;
    expect((fresh.operation, jsonDecode(fresh.payload)['value']), ('log.set_value', '0.500'));
    await tearDownApp(tester, account);
  });

  testWidgets('both devices removed the entry: one Done', (tester) async {
    await seed(tester);
    await tabletDeletes(tester);
    await tester.runAsync(() => account.writer.deleteLog(habitId: habitId, date: today));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.text('Both devices removed this entry.'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tapText(tester, 'Done');
    expect(await outbox(tester), isEmpty);
    await tearDownApp(tester, account);
  });

  testWidgets('archived habit: Restore, then Save my check-in queues after the restore', (
    tester,
  ) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.archiveHabit(habitId);
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: '1.250'));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    for (final t in [
      'Water was archived on another device.',
      'Restore Water to save this check-in, or discard it.',
      'Archived',
      'Restore Water',
      'Discard this check-in',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tapText(tester, 'Restore Water');
    expect(find.text('Save my check-in · 1.25 L'), findsOneWidget, reason: 'updates in place');
    await tapText(tester, 'Save my check-in · 1.25 L');
    expect((await outbox(tester)).map((r) => r.operation), ['habit.restore', 'log.set_value']);
    await tearDownApp(tester, account);
  });

  testWidgets('archived habit: Discard this check-in asks first', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.archiveHabit(habitId);
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: '1.250'));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    await tapText(tester, 'Discard this check-in');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await settle(tester);
    expect(await outbox(tester), isEmpty);
    expect(find.text('Discarded this change.'), findsOneWidget, reason: 'note a');
    await tearDownApp(tester, account);
  });

  HabitDraft draft(String name, {Object target = '2.000'}) => HabitDraft(
    name: name,
    category: 'health',
    targetValue: target,
    unit: 'L',
    frequencyType: 'daily',
    frequencyConfig: const {},
  );

  testWidgets('note f: a first entry of the day reads "first entry of the day"', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.archiveHabit(habitId);
      await tablet.sync(force: true);
    });
    await tester.runAsync(
      () => account.writer.setLogValue(
        habitId: habitId,
        value: '0.500',
        logDate: LocalDate.parse('2026-05-27'),
      ),
    );
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.textContaining(RegExp(r'^Edited at .* · first entry of the day$')), findsOneWidget);
    expect(find.textContaining('based on version 0'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('stale habit edit: every differing field, both ways', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.updateHabit(habitId, draft('Water (tablet)'));
      await tablet.sync(force: true);
    });
    await tester.runAsync(
      () => account.writer.updateHabit(habitId, draft('Water (phone)', target: '2.500')),
    );
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    for (final t in [
      'Your edit is safe',
      'Name: Water (phone)',
      'Name: Water (tablet)',
      'Target: 2.5 L',
      'Target: 2 L',
      'Keep synced version',
      'Use my version',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('Fields that differ take the values you choose.'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('stale archive: the choice and the synced state', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await tablet.writer.updateHabit(habitId, draft('Water (tablet)'));
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.archiveHabit(habitId));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.text('Archive this habit'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Use my choice'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('kind other: the reason and Discard this change only', (tester) async {
    await seed(tester);
    server.forceErrorFor['log.set_value'] = {'code': 'not_found', 'message': 'x'};
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: '1.250'));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.text('Discard this change'), findsOneWidget);
    expect(find.textContaining('Use my'), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('a row that is gone: the line and a Back button, no blank screen', (tester) async {
    await seed(tester);
    await open(tester, '0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f');
    expect(find.byType(ConflictReviewScreen), findsOneWidget, reason: '/sync/review/:id is 19');
    expect(find.byType(SyncQueueScreen), findsNothing);
    expect(find.text('This change no longer needs a look.'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('yes / no reads Done and Not done', (tester) async {
    await seed(tester, name: 'Stretch', type: 'binary', target: 1, unit: null, saved: 1);
    await tester.runAsync(() async {
      await tablet.writer.setLogValue(habitId: habitId, value: 0);
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: 1));
    await syncNow(tester, account);
    final row = await attention(tester);
    await open(tester, row.mutationId);
    expect(find.text('Keep synced value · Not done'), findsOneWidget);
    expect(find.text('Use my value · Done'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('at 200% text with a long name nothing overflows', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(tester, name: 'Evening stretch and breathing practice');
    final row = await staleValue(tester);
    await open(tester, row.mutationId);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
  });

  testWidgets('the queue: Review opens 19; new wording for increments', (tester) async {
    await seed(tester);
    await tabletDeletes(tester);
    await tester.runAsync(() => account.writer.incrementLog(habitId: habitId, delta: '0.5'));
    await syncNow(tester, account);
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);
    expect(find.textContaining('Progress added'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(find.byType(ConflictReviewScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('the queue: a change that can only be discarded has no Review', (tester) async {
    await seed(tester);
    server.forceErrorFor['log.set_value'] = {'code': 'not_found', 'message': 'x'};
    await tester.runAsync(() => account.writer.setLogValue(habitId: habitId, value: '1.250'));
    await syncNow(tester, account);
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);
    expect(find.byType(SyncQueueScreen), findsOneWidget);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Discard'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('L2: a profile change refused with version_conflict shows Discard only', (
    tester,
  ) async {
    await seed(tester);
    server.forceErrorFor['profile.update'] = {'code': 'version_conflict', 'message': 'x'};
    await tester.runAsync(
      () => account.writer.updateProfile(name: 'Maya C', city: null, countryCode: null),
    );
    await syncNow(tester, account);
    await tester.pumpWidget(testApp(initial: '/sync', account: account));
    await settle(tester);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Discard'), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('Today: the sheet of a reviewable change opens 19', (tester) async {
    await seed(tester);
    await staleValue(tester);
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);
    await tester.tap(find.byTooltip('Needs a look · tap to review').first);
    await settle(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(find.byType(ConflictReviewScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  Future<void> staleEdit(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tablet.sync(force: true);
      await tablet.writer.updateHabit(habitId, draft('Water (tablet)'));
      await tablet.sync(force: true);
    });
    await tester.runAsync(() => account.writer.updateHabit(habitId, draft('Water (phone)')));
    await syncNow(tester, account);
  }

  testWidgets('blocked note: one reviewable row opens 19', (tester) async {
    await seed(tester);
    await staleEdit(tester);
    await tester.pumpWidget(testApp(initial: '/habits/$habitId/edit', account: account));
    await settle(tester);
    await tapText(tester, 'Review the change');
    expect(find.byType(ConflictReviewScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });

  testWidgets('blocked note: two reviewable rows open the queue', (tester) async {
    await seed(tester);
    await staleValue(tester); // a check-in that needs a look
    await staleEdit(tester); // then the habit edit: 09 is blocked
    expect(
      (await outbox(tester)).where((r) => r.state == OutboxState.needsAttention),
      hasLength(2),
    );
    await tester.pumpWidget(testApp(initial: '/habits/$habitId/edit', account: account));
    await settle(tester);
    await tapText(tester, 'Review the change');
    expect(find.byType(SyncQueueScreen), findsOneWidget);
    await tearDownApp(tester, account);
  });
}
