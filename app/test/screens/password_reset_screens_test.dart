import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/providers/session_provider.dart';
import 'package:habit/services/auth_service.dart';

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../services/auth_service_test.dart' show MemoryAccountStore;
import '../support/app_harness.dart';
import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import '../support/route_adapter.dart';

/// Phase 6.4 (A50): screens 02, 25, 26 and 27 over the real SessionProvider and AuthService and
/// a scripted HTTP adapter. Signed out throughout.
void main() {
  setUpAll(loadTestZones);

  final forgot = contractFixture('auth/forgot_password.json');
  final reset = contractFixture('auth/reset_password.json');
  const email = 'maya.chen@example.com';

  late RouteAdapter http;
  late SessionProvider session;

  setUp(() {
    http = RouteAdapter();
    final tokens = MemoryTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    session = SessionProvider(
      AuthService(
        ApiClient.withDio(dio, tokens),
        tokens,
        MemoryAccountStore(),
        openDatabase: (_) => AppDatabase(NativeDatabase.memory()),
        clock: () => testNow,
      ),
      buildAccount: (s) => AccountContext(
        session: s,
        transport: FakeSyncServer(),
        refreshIfStale: () async {},
        clock: () => testNow,
      ),
    );
  });

  void acceptForgot() {
    final accepted = forgot['accepted'] as Map<String, dynamic>;
    http.on(
      'POST /auth/forgot-password',
      Reply(accepted['status'] as int, materialize(accepted['body'])),
    );
  }

  Future<void> open(WidgetTester tester, String at, {Object? extra}) async {
    useTallPhone(tester);
    await tester.pumpWidget(testApp(initial: at, initialExtra: extra, session: session));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
  }

  testWidgets('02 offers Forgot password? and 25 starts with the email typed so far', (
    tester,
  ) async {
    await open(tester, Routes.signIn);
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.tap(find.text('Forgot password?'));
    await settle(tester);

    for (final t in [
      'A fresh start',
      'Enter your email to get a reset code.',
      'Private and secure',
      'The response is the same whether or not an account uses this email.',
      'Send reset code',
      'Back to sign in',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text(email), findsOneWidget);
    expect(find.text('Send reset link'), findsNothing, reason: 'A50: a code, never a link');
    await leave(tester);
  });

  testWidgets(
    '25 sends the fixture body and opens 26, whose resend waits out a visible countdown',
    (tester) async {
      acceptForgot();
      await open(tester, Routes.forgotPassword, extra: email);

      await tester.tap(find.text('Send reset code'));
      await settle(tester);

      expectContract(forgot['request'], http.sent('POST /auth/forgot-password').single.data);
      for (final t in [
        'Check your inbox',
        'If an account matches, a reset email is on its way.',
        'Enter the 6-digit code from the email to choose a new password.',
        'Nothing arrived?',
        'Check your spam folder. You can request another code after the resend cooldown.',
        'Enter code',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Resend reset email in 60 s'), findsOneWidget);
      expect(find.bySemanticsLabel('Resend reset email, available in 60 seconds'), findsOneWidget);
      await tester.tap(find.text('Resend reset email in 60 s'));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Resend reset email in 45 s'), findsOneWidget);
      expect(http.sent('POST /auth/forgot-password'), hasLength(1), reason: 'disabled meanwhile');

      await tester.pump(const Duration(seconds: 45));
      await tester.tap(find.text('Resend reset email'));
      await settle(tester);
      expect(http.sent('POST /auth/forgot-password'), hasLength(2));
      expect(find.text('We asked for a new code. It replaces the earlier one.'), findsOneWidget);
      expect(
        find.text('Resend reset email in 60 s'),
        findsOneWidget,
        reason: 'the cooldown restarts',
      );
      await leave(tester);
    },
  );

  testWidgets('26 opens 27, drawn as designed with the code field first', (tester) async {
    await open(tester, Routes.resetSent, extra: email);
    await tester.tap(find.text('Enter code'));
    await settle(tester);

    for (final t in [
      'Choose a new password',
      'A reset code can only be used once.',
      'Reset code',
      'New password',
      'Confirm password',
      'Use at least 12 characters',
      'The two passwords must match. Expired codes return to the reset request.',
      'Save new password',
      'Successful reset returns to sign in.',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    final code = tester.widget<TextField>(find.byType(TextField).first);
    expect(code.keyboardType, TextInputType.number);
    expect(code.autofillHints, [AutofillHints.oneTimeCode]);
    expect(
      tester.getTopLeft(find.text('Reset code')).dy,
      lessThan(tester.getTopLeft(find.text('New password')).dy),
    );
    await leave(tester);
  });

  testWidgets('27 checks the code, the length and the match before sending', (tester) async {
    await open(tester, Routes.resetPassword, extra: email);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), '12a45');
    await tester.enterText(fields.at(1), 'short');
    await tester.enterText(fields.at(2), 'different');
    await tester.tap(find.text('Save new password'));
    await settle(tester);

    expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    expect(find.text('The two passwords must match.'), findsOneWidget);
    expect(http.sent('POST /auth/reset-password'), isEmpty);
    await leave(tester);
  });

  testWidgets('an invalid code shows on its field and offers a new code back on 25', (
    tester,
  ) async {
    final invalid = reset['invalid_code'] as Map<String, dynamic>;
    http.on(
      'POST /auth/reset-password',
      Reply(invalid['status'] as int, materialize(invalid['body'])),
    );
    await open(tester, Routes.resetPassword, extra: email);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), '000000');
    await tester.enterText(fields.at(1), 'a-new-12-plus-character-password');
    await tester.enterText(fields.at(2), 'a-new-12-plus-character-password');
    await tester.tap(find.text('Save new password'));
    await settle(tester);

    expect(find.text('This code is not valid. Request a new one.'), findsOneWidget);
    await tester.tap(find.text('Request a new code'));
    await settle(tester);
    expect(find.text('A fresh start'), findsOneWidget);
    expect(find.text(email), findsOneWidget, reason: 'the email comes along');
    await leave(tester);
  });

  testWidgets('success sends the fixture body and opens sign in with the email and a calm line', (
    tester,
  ) async {
    final request = reset['request'] as Map<String, dynamic>;
    http.on('POST /auth/reset-password', Reply((reset['reset'] as Map)['status'] as int));
    await open(tester, Routes.resetPassword, extra: request['email']);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), request['reset_token'] as String);
    await tester.enterText(fields.at(1), request['password'] as String);
    await tester.enterText(fields.at(2), request['password_confirmation'] as String);
    await tester.tap(find.text('Save new password'));
    await settle(tester);

    expectContract(request, http.sent('POST /auth/reset-password').single.data);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your password has changed.'), findsOneWidget);
    expect(find.text('Sign in with the new one.'), findsOneWidget);
    expect(find.text(request['email'] as String), findsOneWidget);
    await leave(tester);
  });

  testWidgets('text scale 2.0 keeps 27 readable down to its footer', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, Routes.resetPassword, extra: email);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Successful reset returns to sign in.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
