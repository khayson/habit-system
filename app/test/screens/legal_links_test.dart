import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';
import 'package:habit/config/legal_config.dart';

import '../support/app_harness.dart';
import '../support/fake_url_opener.dart';

/// A33: the Terms and Privacy Policy links on screen 03 and the copy-link sheet when nothing can
/// open them.
void main() {
  setUpAll(loadTestZones);

  late FakeUrlOpener opener;
  late List<String> clipboard;

  setUp(() {
    opener = FakeUrlOpener();
    clipboard = [];
  });

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1}) async {
    useTallPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(testApp(initial: Routes.createAccount, urlOpener: opener));
    await settle(tester);
  }

  Finder link(String label) => find.widgetWithText(TextButton, label);

  testWidgets('each link opens its exact page', (tester) async {
    await pumpScreen(tester);

    await tester.tap(link('Terms'));
    await settle(tester);
    await tester.tap(link('Privacy Policy'));
    await settle(tester);

    expect(opener.opened, [
      Uri.parse('https://khayson.github.io/habit-system/terms/'),
      Uri.parse('https://khayson.github.io/habit-system/privacy/'),
    ]);
    expect(opener.opened.map((u) => u.toString()), [LegalConfig.termsUrl, LegalConfig.privacyUrl]);
    expect(find.text("The page didn't open here"), findsNothing, reason: 'opened: no sheet');
  });

  testWidgets('the links sit under the consent line, at least 44 px, hinted as browser links', (
    tester,
  ) async {
    await pumpScreen(tester);
    final handle = tester.ensureSemantics();

    final consent = tester.getBottomLeft(find.text('I agree to the Terms and Privacy Policy.'));
    for (final label in ['Terms', 'Privacy Policy']) {
      final size = tester.getSize(link(label));
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(tester.getTopLeft(link(label)).dy, greaterThanOrEqualTo(consent.dy), reason: label);
      expect(
        tester.getSemantics(link(label)),
        matchesSemantics(
          label: label,
          hint: 'Opens in your browser',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
        ),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('when nothing opens the page, a sheet shows the link and copies it', (tester) async {
    opener.result = false;
    await pumpScreen(tester);

    await tester.tap(link('Privacy Policy'));
    await settle(tester);

    expect(find.text("The page didn't open here"), findsOneWidget);
    expect(find.text('You can copy the link and open it in any browser.'), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'https://khayson.github.io/habit-system/privacy/'),
      findsOneWidget,
    );

    await tester.tap(find.text('Copy link'));
    await settle(tester);
    expect(clipboard, ['https://khayson.github.io/habit-system/privacy/']);
    expect(find.text('Link copied'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'a symbol, not colour alone');
  });

  testWidgets('no overflow at text scale 2.0, on the screen or in the sheet', (tester) async {
    opener.result = false;
    await pumpScreen(tester, textScale: 2);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(link('Terms'));
    await settle(tester);
    expect(tester.getSize(link('Terms')).height, greaterThanOrEqualTo(44));
    await tester.tap(link('Terms'));
    await settle(tester);
    expect(find.text("The page didn't open here"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
