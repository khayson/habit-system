import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/database_opener.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/providers/session_provider.dart';
import 'package:habit/services/auth_service.dart';
import 'package:habit/sync/background_sync.dart';
import 'package:path/path.dart' as p;

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../services/auth_service_test.dart' show MemoryAccountStore;
import '../support/app_harness.dart';
import '../support/contract_fixtures.dart';
import '../support/fake_notification_scheduler.dart';
import '../support/fake_sync_server.dart';
import '../support/route_adapter.dart';

/// Phase 6.2 (A49): screen 28 over the real SessionProvider and AuthService, a scripted HTTP
/// adapter and file-backed account databases, so a deletion can be seen on disk.
void main() {
  setUpAll(loadTestZones);

  const maya = '0190a000-0000-7000-8000-00000000000a';
  const sam = '0190a000-0000-7000-8000-00000000000b';
  final fixture = contractFixture('auth/delete_me.json');

  late Directory temp;
  late RouteAdapter http;
  late MemoryTokenStore tokens;
  late MemoryAccountStore accounts;
  late FakeNotificationScheduler os;
  late _Background background;
  late SessionProvider session;
  late List<AppDatabase> opened;

  File databaseFile(String userId) => File(p.join(temp.path, '${databaseNameFor(userId)}.sqlite'));

  setUp(() {
    temp = Directory.systemTemp.createTempSync('habit_delete_');
    http = RouteAdapter()
      ..on(
        'POST /auth/login',
        Reply(
          200,
          envelope({
            'user': {...FakeSyncServer().user, 'id': maya, 'version': 1},
            'token': 'tok-1',
            'token_type': 'Bearer',
          }),
        ),
      );
    tokens = MemoryTokenStore();
    accounts = MemoryAccountStore();
    os = FakeNotificationScheduler();
    background = _Background()..registered.add(sam);
    opened = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    final auth = AuthService(
      ApiClient.withDio(dio, tokens),
      tokens,
      accounts,
      openDatabase: (userId) {
        final db = AppDatabase(
          DatabaseConnection(NativeDatabase(databaseFile(userId)), closeStreamsSynchronously: true),
        );
        opened.add(db);
        return db;
      },
      deleteDatabase: (userId) => deleteAccountDatabase(userId, directory: () async => temp),
      clock: () => testNow,
    );
    session = SessionProvider(
      auth,
      buildAccount: (s) => AccountContext(
        session: s,
        transport: FakeSyncServer(),
        refreshIfStale: () async {},
        notifications: os,
        background: background,
        filesRoot: p.join(temp.path, '${databaseNameFor(s.userId)}_files'),
        clock: () => testNow,
      ),
    );
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file briefly; the OS cleans temp.
    }
  });

  /// Signed in as Maya, with a reminder scheduled and background sync registered, and Sam's
  /// database already on this device.
  Future<void> openDelete(WidgetTester tester) async {
    useTallPhone(tester);
    await tester.runAsync(() async {
      databaseFile(sam).writeAsStringSync('another account');
      await session.signIn(email: 'maya@example.com', password: 'correct horse battery');
      session.completeSetup();
      final account = session.account!;
      final habit = await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await account.writer.createReminder(
        habitId: habit,
        localTime: '20:00',
        daysOfWeek: [1, 2, 3],
      );
      await account.reminders.replan();
      await account.registerBackground();
      Directory(account.filesRoot).createSync(recursive: true);
    });
    await tester.pumpWidget(testApp(initial: Routes.privacy, session: session));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.tap(find.text('Delete account'));
    await settle(tester);
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

  FilledButton destructive(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Delete account permanently'), matching: find.byType(FilledButton)),
  );

  testWidgets('21 opens 28, drawn as designed, the button waiting for a password', (tester) async {
    await openDelete(tester);

    for (final t in [
      'Delete your account?',
      'This permanently removes your saved routines and history.',
      'Export before you leave',
      'Confirm your password',
      'What happens next',
      'Sessions are revoked immediately. Owned data is queued for deletion under the retention policy.',
      'Keep my account',
      'Delete account permanently',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Today'), findsNothing, reason: '28 draws no bottom bar');
    // The habit and reminder above are still waiting to sync.
    expect(
      find.textContaining(
        'Download your history first if you want to keep it. Pending changes need to sync. ',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('changes are still waiting to sync.'), findsOneWidget);
    expect(destructive(tester).onPressed, isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.autofillHints, isEmpty);

    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();
    expect(destructive(tester).onPressed, isNotNull);
    final semantics = tester.getSemantics(find.text('Delete account permanently'));
    expect(semantics.label, 'Delete account permanently');

    await tester.tap(find.text('Keep my account'));
    await settle(tester);
    expect(find.text('Your data, yours'), findsOneWidget);
    expect(http.sent('DELETE /me'), isEmpty);
    await finish(tester);
  });

  testWidgets('a wrong password shows the server\'s field error and changes nothing', (
    tester,
  ) async {
    final wrong = fixture['wrong_password'] as Map<String, dynamic>;
    http.on('DELETE /me', Reply(wrong['status'] as int, materialize(wrong['body'])));
    await openDelete(tester);

    await tester.enterText(find.byType(TextField), 'not the password');
    await tester.pump();
    await tester.tap(find.text('Delete account permanently'));
    await settle(tester);

    expect(find.text('The password is incorrect.'), findsOneWidget);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect((tokens.token, session.isAuthenticated), ('tok-1', true));
    expect(databaseFile(maya).existsSync(), isTrue);
    await finish(tester);
  });

  testWidgets('offline it says a connection is needed and changes nothing', (tester) async {
    http.on('DELETE /me', const Reply.offline());
    await openDelete(tester);

    await tester.enterText(find.byType(TextField), 'correct horse battery');
    await tester.pump();
    await tester.tap(find.text('Delete account permanently'));
    await settle(tester);

    expect(find.text('Deleting your account needs a connection.'), findsOneWidget);
    expect((tokens.token, session.isAuthenticated), ('tok-1', true));
    expect(os.pending, isNotEmpty);
    expect(accounts.deletionReceipts, isEmpty);
    expect(databaseFile(maya).existsSync(), isTrue);
    await finish(tester);
  });

  testWidgets('any other error is neutral, with Try again', (tester) async {
    http
      ..on('DELETE /me', Reply(500, errorEnvelope('server_error')))
      ..on('DELETE /me', Reply(500, errorEnvelope('server_error')));
    await openDelete(tester);

    await tester.enterText(find.byType(TextField), 'correct horse battery');
    await tester.pump();
    await tester.tap(find.text('Delete account permanently'));
    await settle(tester);
    expect(
      find.text('Your account could not be deleted right now. Nothing has changed.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(http.sent('DELETE /me'), hasLength(2));
    expect(session.isAuthenticated, isTrue);
    await finish(tester);
  });

  testWidgets(
    "success clears this account's database, tokens, reminders and background sync, and no one else's",
    (tester) async {
      final accepted = fixture['accepted'] as Map<String, dynamic>;
      http.on('DELETE /me', Reply(accepted['status'] as int, materialize(accepted['body'])));
      await openDelete(tester);
      final files = session.account!.filesRoot;

      await tester.enterText(find.byType(TextField), 'correct horse battery');
      await tester.pump();
      await tester.tap(find.text('Delete account permanently'));
      await settle(tester);

      expect(find.text('Your account is being deleted.'), findsOneWidget);
      expect(find.text('Sessions on your other devices have ended.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget, reason: 'sign in (02)');
      expect(session.isAuthenticated, isFalse);
      expect((tokens.token, accounts.userId), (null, null));
      expect(accounts.deletionReceipts, {materialize('{{uuid}}'): materialize('{{secret}}')});
      expect(databaseFile(maya).existsSync(), isFalse);
      expect(Directory(files).existsSync(), isFalse);
      expect(os.pending, isEmpty);
      expect(background.registered, {sam});
      expect(databaseFile(sam).readAsStringSync(), 'another account');
      await finish(tester);
    },
  );

  testWidgets('text scale 2.0 keeps 28 readable down to the destructive button', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openDelete(tester);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Delete account permanently'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Delete account permanently')).height, greaterThan(0));
    await finish(tester);
  });
}

class _Background implements BackgroundSyncScheduler {
  final registered = <String>{};

  @override
  Future<void> register(String accountKey) async => registered.add(accountKey);

  @override
  Future<void> cancel(String accountKey) async => registered.remove(accountKey);
}
