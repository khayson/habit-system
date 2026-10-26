import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/file_sharer.dart';
import 'package:habit/models/insights.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/insights_screen.dart';
import 'package:habit/services/insights_service.dart';

import '../support/app_harness.dart';
import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';

/// Phase 5.3b: screens 14 (Week) and 15 (Month) and the Insights tab, from the A47 fixture's
/// answers. The screen shows what the server sent and computes no rule.
void main() {
  setUpAll(loadTestZones);

  final cases = (contractFixture('insights/insights_responses.json')['cases'] as List)
      .cast<Map<String, dynamic>>();
  Map<String, dynamic> answer(String startsWith) => Map<String, dynamic>.from(
    cases.firstWhere((c) => (c['name'] as String).startsWith(startsWith))['expect'] as Map,
  );

  Future<AccountContext> account(WidgetTester tester, FakeInsights api) async {
    useTallPhone(tester);
    return (await tester.runAsync(() => testAccount(FakeSyncServer(), insightsApi: api)))!;
  }

  Future<void> open(WidgetTester tester, AccountContext a) async {
    await tester.pumpWidget(testApp(initial: '/insights', account: a));
    await settle(tester);
  }

  testWidgets('Week (14) as drawn, from the server answer', (tester) async {
    final handle = tester.ensureSemantics();
    final api = FakeInsights()..answers['week'] = answer('week');
    final a = await account(tester, api);
    late String pilates;
    await tester.runAsync(() async {
      pilates = await a.actions.createOneTapHabit(name: 'Pilates', category: 'health');
    });
    final week = answer('week');
    week['open_periods'] = [
      {'habit_id': pilates, 'completed': 2, 'target': 3},
      {'habit_id': 'gone', 'completed': 1, 'target': 2},
    ];
    api.answers['week'] = week;
    await open(tester, a);

    for (final t in [
      'A week of progress',
      '25–31 May · this week is still in progress.',
      '60%',
      '9 / 15 closed periods',
      '+120 XP',
      'Through 27 May',
      'Completed check-ins',
      'Today is still open',
      'Pilates',
      '2 of 3 distinct days this week',
      'A habit',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Pending'), findsNWidgets(2), reason: 'a word, not colour alone');
    expect(find.bySemanticsLabel('Monday, 3 of 5 completed'), findsOneWidget);
    expect(find.bySemanticsLabel('Today so far, 4 of 5 completed'), findsOneWidget);
    expect(find.bySemanticsLabel('Friday, not yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Consistency without pressure'), 200);
    expect(
      find.text(
        'Only closed, eligible periods count. Future days and archived routines are excluded.',
      ),
      findsOneWidget,
    );
    expect(api.calls, ['week']);
    handle.dispose();
    await tearDownApp(tester, a);
  });

  testWidgets('Month (15) as drawn; the choice is kept for the session', (tester) async {
    final handle = tester.ensureSemantics();
    final api = FakeInsights()
      ..answers['week'] = answer('week')
      ..answers['month'] = answer('month');
    final a = await account(tester, api);
    await open(tester, a);

    await tester.tap(find.text('Month'));
    await settle(tester);

    for (final t in [
      'Your consistency',
      'May · closed periods through 27 May.',
      '76%',
      '95 / 125 eligible periods',
      'By category',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final label in [
      'Health, 37 of 54, 69 percent',
      'Mindfulness, 22 of 27, 81 percent',
      'Learning, 21 of 25, 84 percent',
      'Productivity, 15 of 19, 79 percent',
    ]) {
      await tester.scrollUntilVisible(find.bySemanticsLabel(label), 200);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    await tester.scrollUntilVisible(
      find.text('Protected periods keep a streak, but do not count as completed habits.'),
      200,
    );

    await tester.pumpWidget(testApp(initial: '/insights', account: a));
    await settle(tester);
    expect(find.text('Your consistency'), findsOneWidget, reason: 'Month stays chosen');
    handle.dispose();
    await tearDownApp(tester, a);
    resetInsightsPeriodForTest();
  });

  testWidgets('nothing closed yet: no percentage and no through date, never 0%', (tester) async {
    final week = answer('timezone: Accra');
    final month = Map<String, dynamic>.from(answer('timezone: Los'))
      ..['window'] = {
        'start': '2026-06-01',
        'end': '2026-06-30',
        'today': '2026-06-01',
        'through': null,
      };
    final a = await account(
      tester,
      FakeInsights()
        ..answers['week'] = week
        ..answers['month'] = month,
    );
    await open(tester, a);

    expect(find.text('No closed periods yet'), findsOneWidget);
    expect(find.text('No closed days yet'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('1–7 Jun · this week is still in progress.'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await settle(tester);
    expect(find.text('June · no closed periods yet.'), findsOneWidget);
    expect(find.text('No closed periods yet'), findsOneWidget);
    await tearDownApp(tester, a);
    resetInsightsPeriodForTest();
  });

  testWidgets('offline with no last answer: a calm line', (tester) async {
    final a = await account(tester, FakeInsights()..fail = AppErrorKind.network);
    await open(tester, a);

    expect(
      find.text('Insights need a connection. They appear once your phone is back online.'),
      findsOneWidget,
    );
    expect(find.textContaining('failed'), findsNothing);
    await tearDownApp(tester, a);
  });

  testWidgets('offline with a last answer: it stays, with a short line', (tester) async {
    final api = FakeInsights()..answers['week'] = answer('week');
    final a = await account(tester, api);
    await open(tester, a);
    api.fail = AppErrorKind.timeout;

    await tester.pumpWidget(testApp(initial: '/insights', account: a));
    await settle(tester);

    expect(find.text('60%'), findsOneWidget);
    expect(find.text('These are the last numbers from this session.'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('an error offers Try again', (tester) async {
    final api = FakeInsights()
      ..answers['week'] = answer('week')
      ..fail = AppErrorKind.api;
    final a = await account(tester, api);
    await open(tester, a);
    expect(find.text('Insights could not be loaded right now.'), findsOneWidget);
    final retry = find.widgetWithText(TextButton, 'Try again');
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));

    api.fail = null;
    await tester.tap(retry);
    await settle(tester);
    expect(find.text('60%'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('check-ins waiting to sync are mentioned, and only then', (tester) async {
    final a = await account(tester, FakeInsights()..answers['week'] = answer('week'));
    await open(tester, a);
    expect(find.text("Check-ins waiting to sync aren't counted yet."), findsNothing);

    await tester.runAsync(() async {
      final habit = await a.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await a.writer.setLogValue(habitId: habit, value: 1);
    });
    await settle(tester);
    expect(find.text("Check-ins waiting to sync aren't counted yet."), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('when waiting check-ins sync, it fetches once more (5.3b L1)', (tester) async {
    final server = FakeSyncServer();
    final api = FakeInsights()..answers['week'] = answer('week');
    useTallPhone(tester);
    final a = (await tester.runAsync(() => testAccount(server, insightsApi: api)))!;
    await tester.runAsync(() async {
      final habit = await a.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await a.writer.setLogValue(habitId: habit, value: 1);
    });
    await open(tester, a);
    expect(find.text("Check-ins waiting to sync aren't counted yet."), findsOneWidget);
    expect(api.calls, ['week']);

    await syncNow(tester, a);
    await settle(tester);

    expect(find.text("Check-ins waiting to sync aren't counted yet."), findsNothing);
    expect(api.calls, ['week', 'week'], reason: 'the numbers now include them');
    await tearDownApp(tester, a);
  });

  testWidgets('a failed refresh with numbers shown says so, with Try again (5.3b L2)', (
    tester,
  ) async {
    final api = FakeInsights()..answers['week'] = answer('week');
    final a = await account(tester, api);
    await open(tester, a);
    api.fail = AppErrorKind.api;

    await tester.fling(find.text('A week of progress'), const Offset(0, 400), 1000);
    await settle(tester);

    expect(find.text('60%'), findsOneWidget, reason: 'the numbers stay');
    expect(find.text("Couldn't refresh right now."), findsOneWidget);
    final retry = find.widgetWithText(TextButton, 'Try again');
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
    api.fail = null;
    await tester.tap(retry);
    await settle(tester);
    expect(find.text("Couldn't refresh right now."), findsNothing);
    await tearDownApp(tester, a);
  });

  testWidgets('a category this app does not know reads Other', (tester) async {
    final month = answer('month')
      ..['by_category'] = [
        {'category': 'fitness', 'completed': 1, 'eligible': 2, 'percent': 50},
      ];
    final a = await account(
      tester,
      FakeInsights()
        ..answers['week'] = answer('week')
        ..answers['month'] = month,
    );
    final handle = tester.ensureSemantics();
    await open(tester, a);
    await tester.tap(find.text('Month'));
    await settle(tester);

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.bySemanticsLabel('Other, 1 of 2, 50 percent'), findsOneWidget);
    handle.dispose();
    await tearDownApp(tester, a);
    resetInsightsPeriodForTest();
  });

  testWidgets('the Insights tab is enabled, opens 14 and is selected there', (tester) async {
    final handle = tester.ensureSemantics();
    final a = await account(tester, FakeInsights()..answers['week'] = answer('week'));
    await tester.pumpWidget(testApp(initial: '/today', account: a));
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Insights'));
    await settle(tester);

    expect(find.text('A week of progress'), findsOneWidget);
    final tab = tester.getSemantics(find.bySemanticsLabel('Insights'));
    expect(tab.flagsCollection.isSelected, Tristate.isTrue);
    expect(tab.flagsCollection.isEnabled, Tristate.isTrue);
    expect(find.bySemanticsLabel(RegExp('later update')), findsNothing);
    handle.dispose();
    await tearDownApp(tester, a);
  });

  testWidgets('A56: the bars are per category, and Share progress hands an image to the sheet', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final a = await account(tester, FakeInsights()..answers['week'] = answer('week'));
    final sharer = _RecordingSharer();
    await tester.pumpWidget(testApp(initial: '/insights', account: a, fileSharer: sharer));
    await settle(tester);

    expect(find.text('By category'), findsOneWidget);
    expect(find.bySemanticsLabel('Health, 1 of 6, 17 percent'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget, reason: 'the percentage is written in the bar');
    expect(find.text('XP this week'), findsOneWidget);

    await tester.ensureVisible(find.text('Share progress'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Share progress'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single.$1, endsWith('.png'));
    expect(sharer.shared.single.$2, greaterThan(0), reason: 'a real image was written');
    expect(File(sharer.shared.single.$1).existsSync(), isFalse, reason: 'deleted afterwards');
    handle.dispose();
    await tearDownApp(tester, a);
  });

  for (final period in ['week', 'month']) {
    testWidgets('text scale 2.0 keeps the $period readable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final a = await account(
        tester,
        FakeInsights()
          ..answers['week'] = answer('week')
          ..answers['month'] = answer('month'),
      );
      await open(tester, a);
      if (period == 'month') {
        await tester.tap(find.text('Month'));
        await settle(tester);
      }

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text(
          period == 'week'
              ? 'Consistency without pressure'
              : 'Protected periods keep a streak, but do not count as completed habits.',
        ),
        300,
      );
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, a);
      resetInsightsPeriodForTest();
    });
  }
}

/// Records each shared path with the file's size at the moment it was shared.
class _RecordingSharer implements FileSharer {
  final List<(String, int)> shared = [];

  @override
  Future<Directory> temporaryRoot() async => Directory.systemTemp;

  @override
  Future<void> share(String path) async => shared.add((path, File(path).lengthSync()));
}

/// Answers from the fixture, kept per period like the real service.
class FakeInsights implements InsightsService {
  final Map<String, Map<String, dynamic>> answers = {};
  final Map<String, Insights> _last = {};
  final List<String> calls = [];
  AppErrorKind? fail;

  @override
  Insights? last(String period, {String? category}) => _last[period];

  @override
  Future<Insights> fetch(String period, {String? category}) async {
    calls.add(period);
    final kind = fail;
    if (kind != null) throw AppException(kind: kind, code: kind.name, message: 'x');
    return _last[period] = Insights.fromJson(answers[period]!);
  }
}
