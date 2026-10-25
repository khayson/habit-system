import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/widgets/app_icons.dart';
import 'package:habit/widgets/habit_icon_glyphs.g.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// A53: every place a habit is listed shows the habit's own icon, not its type's. A reading
/// habit counted in pages shows the book, not the water drop.
void main() {
  setUpAll(loadTestZones);

  late FakeSyncServer server;
  setUp(() => server = FakeSyncServer());

  /// Reading (quantity, chose the open book), Water (quantity, no icon: health's default) and
  /// Calm (yes/no, a key from a newer app: mindfulness's default, kept on the habit).
  Future<(AccountContext, Map<String, String>)> withHabits(WidgetTester tester) async {
    useTallPhone(tester);
    final account = (await tester.runAsync(() => testAccount(server)))!;
    final ids = (await tester.runAsync(() async {
      final start = LocalDate.parse('2026-05-20');
      final reading = await account.writer.createHabitUnchecked(
        name: 'Reading',
        type: 'quantity',
        target: '20.000',
        unit: 'pages',
        category: 'learning',
        icon: 'book-open-01',
        startLocalDate: start,
        backdate: true,
      );
      final water = await account.writer.createHabitUnchecked(
        name: 'Water',
        type: 'quantity',
        target: '2000.000',
        unit: 'mL',
        category: 'health',
        startLocalDate: start,
        backdate: true,
      );
      final calm = await account.writer.createHabitUnchecked(
        name: 'Calm',
        type: 'binary',
        target: 1,
        category: 'mindfulness',
        icon: 'from-a-newer-app',
        startLocalDate: start,
        backdate: true,
      );
      await account.sync.sync(force: true);
      await account.actions.setValueOn(
        habitId: reading,
        date: LocalDate.parse('2026-05-27'),
        value: '5.000',
      );
      return {'reading': reading, 'water': water, 'calm': calm};
    }))!;
    return (account, ids);
  }

  Future<void> open(WidgetTester tester, AccountContext account, String at) async {
    await tester.pumpWidget(testApp(initial: at, account: account));
    // The rows come from drift on real I/O: wait for them rather than a fixed time.
    for (var i = 0; i < 20 && find.textContaining('Reading').evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  void expectOwnIcons() {
    expect(
      byAppIcon(habitIconGlyphs['book-open-01']!),
      findsOneWidget,
      reason: 'Reading: its book',
    );
    expect(byAppIcon(habitIconGlyphs['heart-check']!), findsOneWidget, reason: "Water: health's");
    expect(byAppIcon(habitIconGlyphs['yoga-03']!), findsOneWidget, reason: "Calm: mindfulness's");
    expect(byAppIcon(AppIcons.quantity), findsNothing, reason: 'never the type icon');
  }

  testWidgets('Today (05) shows each habit its own icon', (tester) async {
    final (account, _) = await withHabits(tester);
    await open(tester, account, Routes.today);
    expectOwnIcons();
    await tearDownApp(tester, account);
  });

  testWidgets('Habits (07) shows each habit its own icon', (tester) async {
    final (account, _) = await withHabits(tester);
    await open(tester, account, Routes.habits);
    expectOwnIcons();
    await tearDownApp(tester, account);
  });

  testWidgets('Archived routines (22) shows the archived habit its own icon', (tester) async {
    final (account, ids) = await withHabits(tester);
    await tester.runAsync(() => account.actions.archiveHabit(ids['reading']!));
    await open(tester, account, Routes.archivedHabits);
    expect(byAppIcon(habitIconGlyphs['book-open-01']!), findsOneWidget);
    expect(byAppIcon(AppIcons.quantity), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('History (13) rows show the habit its own icon', (tester) async {
    final (account, ids) = await withHabits(tester);
    await open(tester, account, Routes.history(ids['reading']!));
    expect(byAppIcon(habitIconGlyphs['book-open-01']!), findsWidgets);
    expect(byAppIcon(AppIcons.quantity), findsNothing);
    await tearDownApp(tester, account);
  });

  testWidgets('the unknown key survives on the habit (it is only shown as the default)', (
    tester,
  ) async {
    final (account, ids) = await withHabits(tester);
    final habits = (await tester.runAsync(() => account.view.habits()))!;
    expect(habits.firstWhere((h) => h.id == ids['calm']).icon, 'from-a-newer-app');
    expect(server.habits[ids['calm']]!['icon'], 'from-a-newer-app');
    await tearDownApp(tester, account);
  });
}
