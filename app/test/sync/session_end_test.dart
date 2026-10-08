import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/providers/session_provider.dart';
import 'package:habit/services/auth_service.dart';
import 'package:habit/sync/http_sync_transport.dart';
import 'package:habit/sync/sync_engine.dart';

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../services/auth_service_test.dart' show MemoryAccountStore;
import '../support/app_harness.dart';
import '../support/route_adapter.dart';
import '../support/fake_notification_scheduler.dart';

/// G1: one owner for "what a 401 means", proven with the real ApiClient, HttpSyncTransport,
/// AuthService and SessionProvider over a scripted HTTP adapter.
void main() {
  setUpAll(loadTestZones);

  late RouteAdapter http;
  late MemoryTokenStore tokens;
  late AuthService auth;
  late SessionProvider session;
  late ApiClient api;
  late AppDatabase db;
  late int ended;

  setUp(() async {
    http = RouteAdapter();
    tokens = MemoryTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    api = ApiClient.withDio(dio, tokens);
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    auth = AuthService(
      api,
      tokens,
      MemoryAccountStore(),
      openDatabase: (_) => db,
      clock: () => testNow,
    );
    session = SessionProvider(
      auth,
      buildAccount: (s) => AccountContext(
        session: s,
        transport: HttpSyncTransport(api.dio, currentToken: api.currentToken),
        refreshIfStale: () async {},
        notifications: FakeNotificationScheduler(),
        clock: () => testNow,
      ),
    );
    api.onUnauthenticated = session.handleUnauthenticated;
    ended = 0;
    session.addListener(() {
      if (!session.isAuthenticated) ended++;
    });

    http.on(
      'POST /auth/login',
      Reply(
        200,
        envelope({
          'user': {
            'id': '0190a000-0000-7000-8000-00000000000a',
            'name': 'Maya',
            'timezone': 'America/Los_Angeles',
            'day_start_offset_minutes': 0,
          },
          'token': 'tok-1',
          'token_type': 'Bearer',
        }),
      ),
    );
    await session.signIn(email: 'maya@example.test', password: 'a-long-password');
  });

  tearDown(() async {
    session.account?.dispose();
    await db.close();
  });

  test('a 401 ends the session exactly once and leaves the database and outbox', () async {
    final account = session.account!;
    await account.actions.createOneTapHabit(name: 'Stretch', category: 'health');
    http.on('GET /sync/bootstrap', Reply(401, errorEnvelope('unauthenticated')));

    expect(await account.sync.sync(force: true), SyncOutcome.loggedOut);
    await Future<void>.delayed(Duration.zero);

    expect(session.isAuthenticated, isFalse, reason: 'the UI cannot stay on Today');
    expect(ended, 1, reason: 'one end of session, one notification');
    expect(tokens.token, isNull);
    expect(http.sent('POST /auth/refresh'), isEmpty, reason: 'the engine never refreshes');
    expect(await db.select(db.outbox).get(), hasLength(1), reason: 'outbox untouched');
  });

  test('a token rotated while the request was in flight is retried once, then works', () async {
    final account = session.account!;
    var rotated = false;
    http
      ..beforeReply = (request) {
        if (!rotated && request.path == '/sync/bootstrap') {
          rotated = true;
          tokens.token = 'tok-2'; // e.g. a refresh finished meanwhile
        }
      }
      ..on('GET /sync/bootstrap', Reply(401, errorEnvelope('unauthenticated')))
      ..on(
        'GET /sync/bootstrap',
        Reply(
          200,
          envelope({
            'habits': <Object>[],
            'logs': <Object>[],
            'has_more': false,
            'sync_cursor': 'c:0',
          }),
        ),
      )
      ..on(
        'POST /sync',
        Reply(
          200,
          envelope({
            'acks': <Object>[],
            'changes': <Object>[],
            'next_cursor': 'c:0',
            'has_more': false,
          }),
        ),
      );

    expect(await account.sync.sync(force: true), SyncOutcome.completed);

    final bootstraps = http.sent('GET /sync/bootstrap');
    expect(bootstraps.map((r) => r.headers['Authorization']), ['Bearer tok-1', 'Bearer tok-2']);
    expect(session.isAuthenticated, isTrue);
    expect(ended, 0);
    expect(tokens.token, 'tok-2', reason: 'the rotated token was not cleared');
  });
}
