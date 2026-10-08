import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
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
import '../support/fake_sync_server.dart';
import '../support/route_adapter.dart';

/// Screens 02, 03, 04 and 08 through the real session, router redirect and auth service, with
/// HTTP answered by a scripted adapter.
void main() {
  setUpAll(loadTestZones);

  late RouteAdapter http;
  late SessionProvider session;
  late List<AppDatabase> opened;
  late FakeSyncServer server;

  setUp(() {
    http = RouteAdapter();
    opened = [];
    server = FakeSyncServer();
    final tokens = MemoryTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    final auth = AuthService(
      ApiClient.withDio(dio, tokens),
      tokens,
      MemoryAccountStore(),
      openDatabase: (_) {
        final db = AppDatabase(
          DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
        );
        opened.add(db);
        return db;
      },
      clock: () => testNow,
    );
    session = SessionProvider(
      auth,
      buildAccount: (s) => AccountContext(
        session: s,
        transport: server,
        refreshIfStale: () async {},
        clock: () => testNow,
      ),
    );
  });

  Widget app(WidgetTester tester, String initial) {
    useTallPhone(tester);
    return testApp(initial: initial, session: session);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    session.account?.dispose();
    await tester.runAsync(() async {
      for (final db in opened) {
        await db.close();
      }
    });
  }

  Map<String, Object?> sessionBody() => envelope({
    'user': {...server.user, 'id': 'user-1', 'version': 1},
    'token': 'tok-1',
    'token_type': 'Bearer',
  });

  testWidgets('02: client checks first, then the server field error, email kept', (tester) async {
    await tester.pumpWidget(app(tester, Routes.signIn));
    await settle(tester);

    await tester.tap(find.text('Sign in').last);
    await settle(tester);
    expect(find.text('Enter an email address, like name@example.com.'), findsOneWidget);
    expect(find.text('This field is needed.'), findsOneWidget);

    http.on(
      'POST /auth/login',
      const Reply(422, {
        'error': {
          'code': 'validation_failed',
          'message': 'Check the highlighted fields.',
          'fields': {
            'email': ['Email or password is incorrect.'],
          },
        },
        'meta': {'request_id': 'r', 'server_time': '2026-05-28T17:22:00Z'},
      }),
    );
    await tester.enterText(find.byType(TextFormField).first, 'maya@example.co');
    await tester.enterText(find.byType(TextFormField).last, 'not the password');
    await tester.tap(find.text('Sign in').last);
    await settle(tester);

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('maya@example.co'), findsOneWidget, reason: 'the email is kept');
    expect(find.text('Welcome back'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('02: no connection shows a plain error and stays on the form', (tester) async {
    http.on('POST /auth/login', const Reply.offline());
    await tester.pumpWidget(app(tester, Routes.signIn));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).first, 'maya@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'a-long-password');
    await tester.tap(find.text('Sign in').last);
    await settle(tester);

    expect(
      find.text('Could not reach the server. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Welcome back'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('03 -> 04 -> 23 -> 08 -> 05: a new account creates its first habit offline', (
    tester,
  ) async {
    http.on('POST /auth/register', Reply(201, sessionBody()));
    await tester.pumpWidget(app(tester, Routes.createAccount));
    await settle(tester);

    await tester.tap(find.text('Create account').last);
    await settle(tester);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(
      find.text('Use at least 12 characters.'),
      findsOneWidget,
      reason: 'the error replaces the helper',
    );
    expect(find.text('Agree to the Terms and Privacy Policy to continue.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Maya Chen');
    await tester.enterText(fields.at(1), 'maya@example.com');
    await tester.enterText(fields.at(2), 'short');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Create account').last);
    await settle(tester);
    expect(http.sent('POST /auth/register'), isEmpty, reason: 'nothing sent while invalid');

    await tester.enterText(fields.at(2), 'twelve-chars-or-more');
    await tester.tap(find.text('Create account').last);
    await settle(tester);

    final body = http.sent('POST /auth/register').single.data as Map;
    expect(body['timezone'], 'America/Los_Angeles', reason: 'the device zone at registration');
    expect(find.text('Your day, your time'), findsOneWidget, reason: '04 after 201');
    expect(find.text('Los Angeles'), findsOneWidget);
    expect(find.text('America/Los_Angeles'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Your first step'), findsOneWidget, reason: '23 for a new account');

    await tester.tap(find.text('Create your first habit'));
    await settle(tester);
    expect(find.text('A new routine'), findsOneWidget);
    await tester.tap(find.text('Create habit'));
    await settle(tester);
    expect(find.text('This field is needed.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Evening stretch');
    await tester.tap(find.text('Mindful'));
    await tester.tap(find.text('Create habit'));
    await settle(tester, rounds: 12);

    expect(find.text('Evening stretch'), findsOneWidget, reason: 'back on Today (05)');
    expect(find.text('New · waiting to sync'), findsOneWidget);
    final row = (await tester.runAsync(
      () => session.account!.session.db.select(session.account!.session.db.outbox).getSingle(),
    ))!;
    expect(row.payload, contains('"category":"mindfulness"'));
    expect(row.payload, contains('"start_local_date":"2026-05-28"'));
    await finish(tester);
  });
}
