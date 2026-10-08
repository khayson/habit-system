import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/time_zones.dart';
import 'package:habit/data/timezone_view.dart';
import 'package:habit/providers/account_context.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 3.2a widget tests: Today due-ness (05), the library (07), the heatmap (12), history and
/// past check-ins (13) and screen 04. All from local data; the server is the fake.
void main() {
  setUpAll(loadTestZones);
  tearDown(() => DeviceZone.read = () async => 'America/Los_Angeles');

  // 28 May 2026 is a Thursday (testNow).
  Map<String, dynamic> habit(
    String suffix,
    String name, {
    String frequency = 'daily',
    Map<String, Object> config = const {},
    String start = '2026-05-01',
  }) => {
    'id': '01970000-0000-7000-8000-0000000000$suffix',
    'name': name,
    'type': 'binary',
    'target_value': 1,
    'unit': null,
    'category': 'health',
    'frequency_type': frequency,
    'frequency_config': config,
    'start_local_date': start,
    'archived_at': null,
    'version': 1,
    'definition_version': 1,
    'definitions': [
      {
        'version': 1,
        'effective_date': start,
        'type': 'binary',
        'target_value': 1,
        'unit': null,
        'category': 'health',
        'frequency_type': frequency,
        'frequency_config': config,
        'config': <String, Object>{},
      },
    ],
    'active_ranges': [
      {'starts_on': start, 'ends_before': null},
    ],
  };

  /// Out-of-band changes (another device, the engine) land while the screen is closed; it then
  /// reads them on open, as the app does on a return to the foreground.
  Future<void> offscreen(
    WidgetTester tester,
    AccountContext account,
    String location,
    Future<void> Function() change,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 3);
    await tester.runAsync(change);
    await tester.pumpWidget(testApp(initial: location, account: account));
    await settle(tester);
  }

  Future<AccountContext> accountWith(
    WidgetTester tester,
    FakeSyncServer server,
    List<Map<String, dynamic>> habits,
  ) async {
    server.extraBootstrapHabits.addAll(habits);
    final account = (await tester.runAsync(() => testAccount(server)))!;
    await syncNow(tester, account);
    return account;
  }

  Map<String, dynamic> evaluation(
    String habitId,
    String date, {
    bool completed = false,
    bool protected = false,
  }) => {
    'id': 'e-$date',
    'habit_id': habitId,
    'period_key': 'd:$date',
    'start_date': date,
    'end_date': date,
    'completed': completed,
    'protected': protected,
    'definition_version': 1,
    'timezone': 'America/Los_Angeles',
    'revision': 1,
  };

  group('Today (05)', () {
    testWidgets('lists what is due today, in creation order, weekly with n of m', (tester) async {
      useTallPhone(tester);
      final account = await accountWith(tester, FakeSyncServer(), [
        habit('a1', 'Water'),
        habit(
          'a2',
          'Run',
          frequency: 'weekdays',
          config: {
            'days': [1],
          },
        ),
        habit(
          'a3',
          'Pilates',
          frequency: 'weekly_count',
          config: {'count': 3},
          start: '2026-05-25',
        ),
        habit('a4', 'Read'),
      ]);
      await tester.pumpWidget(testApp(initial: '/today', account: account));
      await settle(tester);

      expect(find.text('Run'), findsNothing, reason: 'Mondays only; today is a Thursday');
      expect(find.text('0 of 3 habits complete'), findsOneWidget);
      expect(find.text('0 of 3 this week · counted on this device'), findsOneWidget);
      final water = tester.getTopLeft(find.text('Water')).dy;
      final pilates = tester.getTopLeft(find.text('Pilates')).dy;
      final read = tester.getTopLeft(find.text('Read')).dy;
      expect(water < pilates && pilates < read, isTrue, reason: 'creation order');
      expect(find.text('Create a habit'), findsNothing, reason: 'creation moved to 07');
      await tearDownApp(tester, account);
    });

    testWidgets('no copy anywhere threatens loss', (tester) async {
      final arb = File('lib/l10n/app_en.arb').readAsStringSync();
      final values = (jsonDecode(arb) as Map<String, dynamic>).entries
          .where((e) => !e.key.startsWith('@'))
          .map((e) => e.value as String);
      final threat = RegExp(
        r"at risk|don.t break|\blos(e|ing|t)\b|\bfail(ed)?\b",
        caseSensitive: false,
      );
      expect(values.where(threat.hasMatch).toList(), isEmpty);
    });

    testWidgets('ask-on-change shows once per zone; Not now is remembered', (tester) async {
      useTallPhone(tester);
      final account = await accountWith(tester, FakeSyncServer(), [habit('b1', 'Water')]);
      DeviceZone.read = () async => 'Europe/Paris';
      await tester.pumpWidget(testApp(initial: '/today', account: account));
      await settle(tester);
      const question = 'Your device is now in Paris. Use it for your days?';
      expect(find.text(question), findsNothing, reason: 'follow-device is off by default');

      await offscreen(
        tester,
        account,
        '/today',
        () => DeviceSettings(account.session.db).setFollowDevice(true),
      );
      expect(find.text(question), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.text(question), findsNothing);

      await tester.pumpWidget(const SizedBox());
      DeviceZone.read = () async => 'Asia/Tokyo';
      await tester.pumpWidget(testApp(initial: '/today', account: account));
      await settle(tester);
      expect(find.text('Your device is now in Tokyo. Use it for your days?'), findsOneWidget);

      await tester.tap(find.text('Use'));
      await settle(tester);
      expect(find.textContaining('Your device is now in'), findsNothing, reason: 'queued');
      final row = (await tester.runAsync(
        () => account.session.db.select(account.session.db.outbox).getSingle(),
      ))!;
      expect(row.operation, 'profile.set_timezone');
      expect(jsonDecode(row.payload), {'timezone': 'Asia/Tokyo'});
      await tearDownApp(tester, account);
    });
  });

  group('Library (07)', () {
    testWidgets('counts, filters and opens a habit', (tester) async {
      useTallPhone(tester);
      final account = await accountWith(tester, FakeSyncServer(), [
        habit('c1', 'Water'),
        habit(
          'c2',
          'Run',
          frequency: 'weekdays',
          config: {
            'days': [2, 6],
          },
        ),
      ]);
      await tester.pumpWidget(testApp(initial: '/habits', account: account));
      await settle(tester);

      expect(find.text('Your habits'), findsOneWidget);
      expect(find.text('2 active routines · 0 archived'), findsOneWidget);
      expect(find.text('Yes / no · daily'), findsOneWidget);
      expect(find.text('Yes / no · Tue, Sat'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wat');
      await settle(tester);
      expect(find.text('Run'), findsNothing);

      await tester.tap(find.text('Water'));
      await settle(tester);
      expect(find.text('Current streak'), findsOneWidget, reason: 'screen 12');
      await tearDownApp(tester, account);
    });
  });

  group('Habit detail (12)', () {
    testWidgets('offline from local data: symbols, text, labels, streak cards', (tester) async {
      useTallPhone(tester);
      final handle = tester.ensureSemantics();
      final server = FakeSyncServer();
      final id = habit('d1', 'Meditation')['id'] as String;
      final account = await accountWith(tester, server, [habit('d1', 'Meditation')]);
      server
        ..journalEntity(
          'period_evaluation',
          'e-2026-05-25',
          1,
          evaluation(id, '2026-05-25', protected: true),
        )
        ..journalEntity(
          'period_evaluation',
          'e-2026-05-26',
          1,
          evaluation(id, '2026-05-26', completed: true),
        )
        ..journalEntity(
          'period_evaluation',
          'e-2026-05-27',
          1,
          evaluation(id, '2026-05-27', completed: true),
        )
        ..journalEntity('period_evaluation', 'e-2026-05-24', 1, evaluation(id, '2026-05-24'))
        ..journalEntity('habit_progress', id, 1, {
          'habit_id': id,
          'current': 3,
          'longest': 21,
          'unit': 'days',
          'computed_through': '2026-05-27',
        });
      await syncNow(tester, account);
      await tester.pumpWidget(testApp(initial: '/habits/$id', account: account));
      await settle(tester);

      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('21 days'), findsOneWidget);
      expect(find.text('Best streak'), findsOneWidget);
      expect(find.text('May 2026'), findsOneWidget);
      for (final legend in ['Complete', 'Protected', 'Missed (–)', 'Not due (outline)']) {
        expect(find.text(legend), findsOneWidget);
      }
      expect(find.bySemanticsLabel('May 26, 2026, Complete'), findsOneWidget);
      expect(find.bySemanticsLabel('May 25, 2026, Protected'), findsOneWidget);
      expect(find.bySemanticsLabel('May 24, 2026, Missed'), findsOneWidget);
      expect(find.bySemanticsLabel('May 28, 2026, Pending, saved on this device'), findsOneWidget);
      expect(find.bySemanticsLabel('May 29, 2026, Upcoming'), findsOneWidget);
      expect(
        find.text('Some days are counted on this device and are confirmed after syncing.'),
        findsOneWidget,
        reason: 'today is worked out on this device',
      );
      expect(find.text('✱'), findsOneWidget, reason: 'protected has a symbol');
      expect(find.text('–'), findsOneWidget, reason: 'missed has a symbol');
      expect(
        find.text('Your streak includes 1 protected day.\nA missed day is a pause, not a failure.'),
        findsOneWidget,
      );
      handle.dispose();
      await tearDownApp(tester, account);
    });

    testWidgets('no progress yet; and an older streak says as of', (tester) async {
      useTallPhone(tester);
      final server = FakeSyncServer();
      final id = habit('d2', 'Stretch')['id'] as String;
      final account = await accountWith(tester, server, [habit('d2', 'Stretch')]);
      await tester.pumpWidget(testApp(initial: '/habits/$id', account: account));
      await settle(tester);
      expect(find.text('Not yet'), findsWidgets);
      expect(find.text('A missed day is a pause, not a failure.'), findsOneWidget);

      server.journalEntity('habit_progress', id, 1, {
        'habit_id': id,
        'current': 4,
        'longest': 4,
        'unit': 'days',
        'computed_through': '2026-05-20',
      });
      await offscreen(tester, account, '/habits/$id', () => account.sync.sync(force: true));
      expect(find.text('Current streak · as of May 20'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('older than the local window, offline: says it needs a connection', (tester) async {
      useTallPhone(tester);
      final id = habit('d3', 'Walk')['id'] as String;
      final account = await accountWith(tester, FakeSyncServer(), [
        habit('d3', 'Walk', start: '2025-01-01'),
      ]);
      await tester.pumpWidget(testApp(initial: '/habits/$id', account: account));
      await settle(tester);

      for (var i = 0; i < 15; i++) {
        await tester.fling(
          find.textContaining(RegExp(r'^[A-Z][a-z]+ 20\d\d$')).first,
          const Offset(300, 0),
          1000,
        );
        await settle(tester, rounds: 2);
      }
      expect(find.text('February 2025'), findsOneWidget);
      expect(find.text('Older history needs a connection'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    testWidgets('2x text scale keeps every status readable', (tester) async {
      useTallPhone(tester);
      final id = habit('d4', 'Stretch')['id'] as String;
      final account = await accountWith(tester, FakeSyncServer(), [habit('d4', 'Stretch')]);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2), size: Size(411, 1600)),
          child: testApp(initial: '/habits/$id', account: account),
        ),
      );
      await settle(tester);
      for (final line in [
        'Some days are counted on this device and are confirmed after syncing.',
        'Not due (outline)',
      ]) {
        await tester.scrollUntilVisible(find.text(line), 200);
        expect(find.text(line), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, account);
    });
  });

  group('History (13)', () {
    testWidgets('offline, a past check-in writes the backdate outbox row', (tester) async {
      useTallPhone(tester);
      final id = habit('f1', 'Stretch')['id'] as String;
      final account = await accountWith(tester, FakeSyncServer(), [habit('f1', 'Stretch')]);
      await tester.pumpWidget(
        testApp(initial: '/habits/$id/history?date=2026-05-20', account: account),
      );
      await settle(tester);
      expect(find.text('Your history'), findsOneWidget);
      expect(find.text('May 20, 2026'), findsOneWidget);

      await tester.tap(find.text('Save past check-in'));
      await settle(tester);

      final row = (await tester.runAsync(
        () => account.session.db.select(account.session.db.outbox).getSingle(),
      ))!;
      expect(row.localDateHint, '2026-05-20');
      expect(jsonDecode(row.payload), {
        'habit_id': id,
        'value': 1,
        'date_mode': 'backdate',
        'log_date': '2026-05-20',
      });
      expect(find.text('May 20 · Stretch'), findsOneWidget);
      expect(find.text('Done · waiting to sync'), findsOneWidget);
      await tearDownApp(tester, account);
    });

    for (final (date, message) in [
      ('2026-04-20', 'Past check-ins can go back 30 days.'),
      ('2026-04-30', 'This habit was not active on that date.'),
    ]) {
      testWidgets('refuses $date in plain words and writes nothing', (tester) async {
        useTallPhone(tester);
        final id = habit('f2', 'Stretch')['id'] as String;
        final account = await accountWith(tester, FakeSyncServer(), [habit('f2', 'Stretch')]);
        await tester.pumpWidget(
          testApp(initial: '/habits/$id/history?date=$date', account: account),
        );
        await settle(tester);

        await tester.tap(find.text('Save past check-in'));
        await settle(tester);

        expect(find.text(message), findsOneWidget);
        final rows = (await tester.runAsync(
          () => account.session.db.select(account.session.db.outbox).get(),
        ))!;
        expect(rows, isEmpty);
        await tearDownApp(tester, account);
      });
    }
  });

  group('Timezone (04)', () {
    testWidgets('edit: queued, then pending after the ack, then cancelled', (tester) async {
      useTallPhone(tester);
      final account = await accountWith(tester, FakeSyncServer(), [habit('g1', 'Water')]);
      await tester.pumpWidget(testApp(initial: '/setup', account: account));
      await settle(tester);
      expect(find.text('Los Angeles'), findsOneWidget);

      Future<void> choose(String search, String city) async {
        await tester.tap(find.text('Edit'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), search);
        await settle(tester);
        await tester.tap(find.textContaining(RegExp('^$city, UTC')));
        await settle(tester);
      }

      await choose('paris', 'Paris');
      expect(find.text('Paris · waiting to sync'), findsOneWidget);

      // The app's own debounced sync (2 s after the write) runs while frames pump.
      await settle(tester, rounds: 60);
      expect(
        find.textContaining(
          RegExp(r'^Paris · changes at the start of your next day \(12:00\sAM\)$'),
        ),
        findsOneWidget,
      );

      await choose('los_ang', 'Los Angeles');
      expect(find.text('Los Angeles · waiting to sync'), findsOneWidget);
      // The app's own debounced sync (2 s after the write) runs while frames pump.
      await settle(tester, rounds: 60);
      expect(find.textContaining('waiting to sync'), findsNothing);
      expect(find.textContaining('changes at the start'), findsNothing, reason: 'cancelled');
      await tearDownApp(tester, account);
    });

    testWidgets('follow device timezone is a per-device switch', (tester) async {
      useTallPhone(tester);
      final account = await accountWith(tester, FakeSyncServer(), [habit('g2', 'Water')]);
      await tester.pumpWidget(testApp(initial: '/setup', account: account));
      await settle(tester);

      Future<String?> setting() async => (await tester.runAsync(
        () => account.session.db
            .customSelect("SELECT value FROM local_settings WHERE key = 'follow_device_timezone'")
            .getSingleOrNull(),
      ))?.read<String>('value');

      expect(await setting(), isNull);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(await setting(), '1');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue, reason: 'shown at once');
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(await setting(), '0');
      await tearDownApp(tester, account);
    });
  });
}
