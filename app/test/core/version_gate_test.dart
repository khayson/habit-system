import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/app_version.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/core/version_gate.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/widgets/version_gated.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_url_opener.dart';

/// A54 (the 6.6 review's I2): the server's min_app_version against this build's number. Lower
/// means a calm full-screen "Please update" with one way forward: the download page.
void main() {
  test('this build number is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*\S+\+(\d+)\s*$', multiLine: true).firstMatch(pubspec)!;
    expect(AppVersion.build, int.parse(version.group(1)!));
  });

  group('VersionGate', () {
    Map<String, dynamic> body(Object? min) => {
      'data': {'status': 'ok'},
      'meta': {'api_version': 'v1', 'min_app_version': min},
    };

    test('reads the fixture meta: the first release passes', () {
      final gate = VersionGate(build: AppVersion.build)
        ..observe(contractFixture('envelope/success_health.json')['body']);
      expect(gate.updateRequired, isFalse);
    });

    test('a minimum above this build requires the update; equal or below does not', () {
      final gate = VersionGate(build: 3);
      gate.observe(body(3));
      expect(gate.updateRequired, isFalse, reason: 'equal is fine');
      gate.observe(body(2));
      expect(gate.updateRequired, isFalse);
      gate.observe(body(4));
      expect(gate.updateRequired, isTrue);
    });

    test('once required it stays required for this run, whatever arrives later', () {
      final gate = VersionGate(build: 3)..observe(body(4));
      gate.observe(body(1));
      gate.observe(null);
      expect(gate.updateRequired, isTrue);
    });

    test('a body without the field, or a field of another type, changes nothing', () {
      final gate = VersionGate(build: 3);
      var notified = 0;
      gate.addListener(() => notified++);
      for (final b in [null, 'text', <String, dynamic>{}, body(null), body('9'), body(9.5)]) {
        gate.observe(b);
      }
      expect(gate.updateRequired, isFalse);
      expect(notified, 0);
    });
  });

  group('VersionGated', () {
    Future<FakeUrlOpener> pump(WidgetTester tester, VersionGate gate) async {
      final opener = FakeUrlOpener();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => VersionGated(
            gate: gate,
            opener: opener,
            downloadUrl: 'https://khayson.github.io/habit-system/download/',
            child: child!,
          ),
          home: const Scaffold(body: Text('Today')),
        ),
      );
      return opener;
    }

    testWidgets('a current app shows the app', (tester) async {
      await pump(tester, VersionGate(build: 1));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Get the update'), findsNothing);
    });

    testWidgets('an old app shows only the update view; its button opens the download page', (
      tester,
    ) async {
      final gate = VersionGate(build: 1);
      final opener = await pump(tester, gate);
      gate.observe({
        'meta': {'min_app_version': 2},
      });
      await tester.pump();
      expect(find.text('Today'), findsNothing, reason: 'no other way forward');
      expect(find.text('A new version is ready'), findsOneWidget);
      expect(find.textContaining('Your habits are safe on this phone'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Get the update');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pump();
      expect(opener.opened, [Uri.parse('https://khayson.github.io/habit-system/download/')]);
      expect(
        find.text('khayson.github.io/habit-system/download/'),
        findsOneWidget,
        reason: 'the address is shown too, in case no browser opens',
      );
    });

    testWidgets('the update view reads at text scale 2.0 without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final gate = VersionGate(build: 1)
        ..observe({
          'meta': {'min_app_version': 2},
        });
      await pump(tester, gate);
      expect(tester.takeException(), isNull);
      expect(find.text('Get the update'), findsOneWidget);
    });
  });
}
