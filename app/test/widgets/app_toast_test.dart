import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/widgets/app_icons.dart';
import 'package:habit/widgets/app_toast.dart';

import '../support/app_harness.dart';

/// A52: the app's own toast. Top of the root overlay, one at a time, 4 s plain or 6 s with an
/// action, stays while a screen reader is on, a close button and an action of at least 44 px.
void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext) onTap, {
    bool screenReader = false,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(accessibleNavigation: screenReader, disableAnimations: reducedMotion),
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) =>
                    TextButton(onPressed: () => onTap(context), child: const Text('go')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a plain toast shows a check and the message, then leaves after 4 s', (tester) async {
    await pumpHost(tester, (c) => AppToast.of(c).show('Saved.'));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved.'), findsOneWidget);
    expect(byAppIcon(AppIcons.done), findsOneWidget, reason: 'a symbol, never colour alone');
    expect(find.byTooltip('Close message'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('Saved.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsNothing);
  });

  testWidgets('with an action it stays 6 s; the action runs once and closes the toast', (
    tester,
  ) async {
    var undone = 0;
    await pumpHost(
      tester,
      (c) =>
          AppToast.of(c).show('Archived Stretch.', actionLabel: 'Undo', onAction: () => undone++),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Archived Stretch.'), findsOneWidget);

    final undo = find.widgetWithText(TextButton, 'Undo');
    expect(tester.getSize(undo).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(undo).width, greaterThanOrEqualTo(44));
    final close = find.byTooltip('Close message');
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));

    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Archived Stretch.'), findsNothing);
  });

  testWidgets('a new toast replaces the one on screen', (tester) async {
    var n = 0;
    await pumpHost(tester, (c) => AppToast.of(c).show('Toast ${++n}'));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the close button dismisses it; an info toast shows the info mark', (tester) async {
    await pumpHost(tester, (c) => AppToast.of(c).show('Note.', tone: ToastTone.info));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(byAppIcon(AppIcons.info), findsOneWidget);
    await tester.tap(find.byTooltip('Close message'));
    await tester.pumpAndSettle();
    expect(find.text('Note.'), findsNothing);
  });

  testWidgets('with a screen reader on it stays until closed, and is a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHost(tester, (c) => AppToast.of(c).show('Saved.'), screenReader: true);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Saved.'), findsOneWidget);
    final live = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true);
    expect(live, findsOneWidget);
    await tester.tap(find.byTooltip('Close message'));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsNothing);
    semantics.dispose();
  });

  testWidgets('reduced motion: it appears at once, without a slide', (tester) async {
    await pumpHost(tester, (c) => AppToast.of(c).show('Saved.'), reducedMotion: true);
    await tester.tap(find.text('go'));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('Saved.'), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('it stays visible after the screen that showed it is left', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (inner) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      final toast = AppToast.of(inner);
                      Navigator.of(inner).pop();
                      toast.show('Saved.');
                    },
                    child: const Text('save'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('save'), findsNothing);
    expect(find.text('Saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
  // 6.7 review L1: a toast never outlives the account it was shown for.
  testWidgets('AppToastScope closes the toast when its owner changes (sign-out, switch)', (
    tester,
  ) async {
    Widget host(Object? owner) => AppToastScope(
      owner: owner,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppToast.of(context).show('Archived Stretch.'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    const a = 'account-a';
    await tester.pumpWidget(host(a));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(a)); // a rebuild with the same owner keeps it
    expect(find.text('Archived Stretch.'), findsOneWidget);

    await tester.pumpWidget(host(null)); // signed out
    await tester.pump();
    expect(find.text('Archived Stretch.'), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host('account-b')); // switched
    await tester.pump();
    expect(find.text('Archived Stretch.'), findsNothing);
  });
}
