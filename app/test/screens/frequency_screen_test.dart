import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit/app/router.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/frequency_choice.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/screens/frequency_screen.dart';

/// Phase 4.2b: screen 10. No account, no network: the screen only pops a choice.
void main() {
  final today = LocalDate.parse('2026-05-28'); // a Thursday

  /// Opens 10 from a stub screen; returns a getter for what it popped.
  Future<FrequencyChoice? Function()> open(
    WidgetTester tester, {
    FrequencyChoice current = FrequencyChoice.daily,
    double textScale = 1,
  }) async {
    // A phone-shaped, tall view: the whole screen is built at 100% text.
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FrequencyChoice? popped;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => popped = await context.push<FrequencyChoice>(
                  Routes.frequency,
                  extra: FrequencyRequest(habitName: 'Pilates', current: current, today: today),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.frequency,
          builder: (context, state) => FrequencyScreen(request: state.extra! as FrequencyRequest),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 100, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> use(WidgetTester tester) async {
    await reveal(tester, find.text('Use this schedule'));
    await tester.tap(find.text('Use this schedule'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await reveal(tester, find.text(option));
    await tester.tap(find.text(option).first);
    await tester.pumpAndSettle();
  }

  testWidgets('copy, and the current option is selected by symbol and in words', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.text('A flexible schedule'), findsOneWidget);
    expect(find.text('Choose how often Pilates fits your week.'), findsOneWidget);
    for (final t in ['Every day', 'Specific weekdays', 'Times per week', 'Custom interval']) {
      expect(find.text(t), findsWidgets);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Every day\. A daily routine'))),
      matchesSemantics(
        label: 'Every day. A daily routine. Selected',
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
        hasSelectedState: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Custom interval.*Not selected$')), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'one check; the others are circles');
    expect(find.text('The week is still yours'), findsNothing);
    handle.dispose();
  });

  testWidgets('weekdays: seven toggles, ISO days, sent sorted', (tester) async {
    final handle = tester.ensureSemantics();
    final popped = await open(tester);
    await choose(tester, 'Specific weekdays');
    for (final day in ['Friday', 'Monday', 'Wednesday']) {
      await tester.tap(find.bySemanticsLabel(day));
      await tester.pump();
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Monday')),
      matchesSemantics(
        label: 'Monday',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tuesday')),
      matchesSemantics(
        label: 'Tuesday',
        isButton: true,
        hasToggledState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    for (final day in ['Monday', 'Tuesday', 'Sunday']) {
      final size = tester.getSize(find.bySemanticsLabel(day));
      expect(size.width >= 44 && size.height >= 44, isTrue, reason: '$day is $size');
    }
    expect(find.text('Monday, Wednesday and Friday'), findsOneWidget);
    await use(tester);
    expect(
      popped(),
      const FrequencyChoice('weekdays', {
        'days': [1, 3, 5],
      }),
    );
    handle.dispose();
  });

  testWidgets('weekdays with none chosen: a calm message, nothing popped', (tester) async {
    final popped = await open(tester);
    await choose(tester, 'Specific weekdays');
    await use(tester);
    expect(find.text('Choose at least one day.'), findsOneWidget);
    expect(find.byType(FrequencyScreen), findsOneWidget);
    expect(popped(), isNull);
  });

  testWidgets('times per week: a 1 to 7 stepper and the week info card', (tester) async {
    final handle = tester.ensureSemantics();
    final popped = await open(tester);
    await choose(tester, 'Times per week');
    expect(find.text('3 times each week'), findsOneWidget);
    expect(find.text('Monday–Sunday · each day counts once'), findsOneWidget);
    expect(find.text('The week is still yours'), findsOneWidget);
    expect(find.text('An unfinished week is pending, not missed.'), findsOneWidget);
    expect(find.textContaining('freeze'), findsNothing);

    final stepper = find.bySemanticsLabel('Times per week');
    expect(
      tester.getSemantics(stepper),
      matchesSemantics(
        label: 'Times per week',
        value: '3',
        increasedValue: '4',
        decreasedValue: '2',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
    }
    expect(find.text('7 times each week'), findsOneWidget, reason: 'stops at 7');
    await use(tester);
    expect(popped(), FrequencyChoice.weeklyCount(7));
    handle.dispose();
  });

  testWidgets('interval: every N days from a start date, default today', (tester) async {
    final popped = await open(tester);
    await choose(tester, 'Custom interval');
    expect(find.text('Every 2 days'), findsOneWidget);
    expect(find.text('Starting May 28'), findsOneWidget);
    await tester.tap(find.byTooltip('Fewer'));
    await tester.pump();
    expect(find.text('Every day'), findsWidgets);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await use(tester);
    expect(popped(), FrequencyChoice.interval(3, today));
  });

  testWidgets('the start date picker runs from the earlier anchor to today + 365', (tester) async {
    await open(tester, current: FrequencyChoice.interval(2, LocalDate.parse('2026-05-01')));
    await reveal(tester, find.text('May 1'));
    await tester.tap(find.text('May 1'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    String day(DateTime d) => '${d.year}-${d.month}-${d.day}';
    expect((day(picker.firstDate), day(picker.lastDate)), ('2026-5-1', '2027-5-28'));
  });

  testWidgets('at 200% text every option and control renders without overflow', (tester) async {
    await open(tester, textScale: 2);
    for (final option in ['Specific weekdays', 'Times per week', 'Custom interval', 'Every day']) {
      await choose(tester, option);
      expect(tester.takeException(), isNull, reason: option);
    }
    await choose(tester, 'Specific weekdays');
    await reveal(tester, find.text('Use this schedule'));
    expect(tester.takeException(), isNull);
  });
}
