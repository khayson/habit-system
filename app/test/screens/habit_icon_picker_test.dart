import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:habit/widgets/app_icons.dart';
import 'package:habit/widgets/habit_icon_catalog.g.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// A53: the Icon row on create and edit, the picker sheet (every Hugeicons glyph, searchable),
/// the name suggestion, and 6.7's answer: "Changes saved." after an edit.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;

  Future<AccountContext> account(WidgetTester tester, {bool offline = true}) async {
    useTallPhone(tester);
    server = FakeSyncServer();
    if (offline)
      server.failNextSync.addAll(
        List.filled(50, const SyncTransportException(SyncFailure.network)),
      );
    return (await tester.runAsync(() => testAccount(server)))!;
  }

  Future<void> open(WidgetTester tester, AccountContext a, String at) async {
    await tester.pumpWidget(testApp(initial: at, account: a));
    await settle(tester);
  }

  Future<List<Map<String, dynamic>>> sent(WidgetTester tester, AccountContext a, String op) async {
    final rows = (await tester.runAsync(() => a.session.db.select(a.session.db.outbox).get()))!;
    return [
      for (final r in rows)
        if (r.operation == op) jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }

  Finder iconRow() => find.byKey(const ValueKey('icon-row'));
  Finder cell(String key) => find.byKey(ValueKey('icon-cell-$key'));
  Finder rowGlyph(String key) =>
      find.descendant(of: iconRow(), matching: byAppIcon(habitIconGlyphs[key]!));

  Future<void> openPicker(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('icon-row-edit')));
    await tester.tap(find.byKey(const ValueKey('icon-row-edit')));
    await tester.pumpAndSettle();
  }

  testWidgets('create: the row shows the category default, then the name suggestion', (
    tester,
  ) async {
    final a = await account(tester);
    await open(tester, a, '/habits/new');
    expect(find.descendant(of: iconRow(), matching: find.text('Icon')), findsOneWidget);
    expect(rowGlyph('heart-check'), findsOneWidget, reason: "health's default");
    expect(find.descendant(of: iconRow(), matching: find.text('Heart health')), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Reading');
    await tester.pump();
    expect(rowGlyph('book-open-01'), findsOneWidget);
    expect(find.descendant(of: iconRow(), matching: find.text('Reading')), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, 'Drink water');
    await tester.pump();
    expect(rowGlyph('glass-water'), findsOneWidget, reason: 'the suggestion follows the name');
    await tearDownApp(tester, a);
  });

  testWidgets('create: a manual pick stops the suggestion and is sent', (tester) async {
    final a = await account(tester);
    await open(tester, a, '/habits/new');
    await tester.enterText(find.byType(TextFormField).first, 'Reading');
    await tester.pump();

    await openPicker(tester);
    await tester.enterText(find.byKey(const ValueKey('icon-search')), 'yoga');
    await tester.pumpAndSettle();
    expect(cell('yoga-01'), findsOneWidget);
    expect(cell('book-02'), findsNothing, reason: 'the search narrows the grid');
    await tester.tap(cell('yoga-01'));
    await tester.pumpAndSettle();
    expect(rowGlyph('yoga-01'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Drink water');
    await tester.pump();
    expect(rowGlyph('yoga-01'), findsOneWidget, reason: 'a pick is never replaced by the name');

    await tester.scrollUntilVisible(
      find.text('Create habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create habit'));
    await settle(tester);
    expect((await sent(tester, a, 'habit.create')).single['icon'], 'yoga-01');
    await tearDownApp(tester, a);
  });

  testWidgets('the sheet: suggested first, the selected cell marked by a check, 48 px cells, '
      'labels for TalkBack, and a calm line when nothing matches', (tester) async {
    final handle = tester.ensureSemantics();
    final a = await account(tester);
    await open(tester, a, '/habits/new');
    await tester.enterText(find.byType(TextFormField).first, 'Reading');
    await tester.pump();
    await openPicker(tester);

    expect(find.text('Choose an icon'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    final selected = cell('book-open-01');
    expect(selected, findsOneWidget);
    expect(find.descendant(of: selected, matching: byAppIcon(AppIcons.check)), findsOneWidget);
    expect(find.descendant(of: cell('book-02'), matching: byAppIcon(AppIcons.check)), findsNothing);
    final size = tester.getSize(selected);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(selected),
      isSemantics(label: 'Reading', isButton: true, isSelected: true),
    );
    expect(tester.getSemantics(cell('book-02')), isSemantics(label: 'Book', isSelected: false));

    await tester.enterText(find.byKey(const ValueKey('icon-search')), 'zzzqqq');
    await tester.pumpAndSettle();
    expect(find.text('No icon matches "zzzqqq".'), findsOneWidget);
    handle.dispose();
    await tearDownApp(tester, a);
  });

  testWidgets('the sheet at text scale 2.0: readable, searchable, no overflow', (tester) async {
    final a = await account(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, a, '/habits/new');
    await openPicker(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Choose an icon'), findsOneWidget);
    expect(find.byKey(const ValueKey('icon-search')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('icon-search')), 'book');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(cell('book-open-01'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('edit: an unknown key shows the category default and survives a name edit; '
      '"Changes saved." follows the save', (tester) async {
    final a = await account(tester, offline: false);
    final id = (await tester.runAsync(
      () => a.writer.createHabitUnchecked(
        name: 'Calm',
        type: 'binary',
        target: 1,
        category: 'mindfulness',
        icon: 'from-a-newer-app',
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      ),
    ))!;
    await syncNow(tester, a);
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));

    await open(tester, a, '/habits/$id/edit');
    expect(rowGlyph('yoga-03'), findsOneWidget, reason: "mindfulness's default");
    await tester.enterText(find.byType(TextFormField).first, 'Calm evening');
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    final update = (await sent(tester, a, 'habit.update')).single;
    expect(update['name'], 'Calm evening');
    expect(update['icon'], 'from-a-newer-app', reason: 'kept unchanged (invariant 13)');
    expect(find.text('Changes saved.'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  Future<(AccountContext, String)> readingHabit(WidgetTester tester) async {
    final a = await account(tester, offline: false);
    final id = (await tester.runAsync(
      () => a.writer.createHabitUnchecked(
        name: 'Reading',
        type: 'binary',
        target: 1,
        category: 'learning',
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      ),
    ))!;
    await syncNow(tester, a);
    server.failNextSync.addAll(List.filled(50, const SyncTransportException(SyncFailure.network)));
    return (a, id);
  }

  testWidgets('edit: an unchanged form saves nothing and says nothing', (tester) async {
    final (a, id) = await readingHabit(tester);
    await open(tester, a, '/habits/$id/edit');
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(await sent(tester, a, 'habit.update'), isEmpty);
    expect(find.text('Changes saved.'), findsNothing);
    await tearDownApp(tester, a);
  });

  testWidgets('edit: a picked icon is sent, then "Changes saved."', (tester) async {
    final (a, id) = await readingHabit(tester);
    await open(tester, a, '/habits/$id/edit');
    await openPicker(tester);
    await tester.enterText(find.byKey(const ValueKey('icon-search')), 'book open');
    await tester.pumpAndSettle();
    await tester.tap(cell('book-open-01'));
    await tester.pumpAndSettle();
    expect(rowGlyph('book-open-01'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect((await sent(tester, a, 'habit.update')).single['icon'], 'book-open-01');
    expect(find.text('Changes saved.'), findsOneWidget);
    await tearDownApp(tester, a);
  });
}
