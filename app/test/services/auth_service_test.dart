import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/core/storage/account_store.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/services/auth_service.dart';
import 'package:habit/sync/sync_transport.dart';

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../support/route_adapter.dart';

class MemoryAccountStore implements AccountStore {
  String? userId;
  DateTime? issuedAt;
  String? device;

  @override
  Future<String?> readUserId() async => userId;
  @override
  Future<DateTime?> readTokenIssuedAt() async => issuedAt;
  @override
  Future<void> writeSession({required String userId, required DateTime tokenIssuedAt}) async {
    this.userId = userId;
    issuedAt = tokenIssuedAt;
  }

  @override
  Future<void> writeTokenIssuedAt(DateTime at) async => issuedAt = at;
  @override
  Future<void> clearSession() async {
    userId = null;
    issuedAt = null;
  }

  @override
  Future<String> deviceId(String Function() create) async => device ??= create();
}

const _alice = '0190a000-0000-7000-8000-00000000000a';
const _bob = '0190a000-0000-7000-8000-00000000000b';

Map<String, Object?> _session(String userId, String token) => envelope({
  'user': {
    'id': userId,
    'timezone': 'America/Los_Angeles',
    'day_start_offset_minutes': 0,
    'version': 1,
  },
  'token': token,
  'token_type': 'Bearer',
});

void main() {
  late RouteAdapter http;
  late MemoryTokenStore tokens;
  late MemoryAccountStore accounts;
  late Map<String, AppDatabase> opened;
  late DateTime now;
  late AuthService auth;

  setUp(() {
    http = RouteAdapter();
    tokens = MemoryTokenStore();
    accounts = MemoryAccountStore();
    opened = {};
    now = DateTime.utc(2026, 5, 28, 10);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    auth = AuthService(
      ApiClient.withDio(dio, tokens),
      tokens,
      accounts,
      openDatabase: (userId) =>
          opened.putIfAbsent(userId, () => AppDatabase(NativeDatabase.memory())),
      clock: () => now,
    );
  });

  tearDown(() async {
    for (final db in opened.values) {
      await db.close();
    }
  });

  test('login stores the token, binds this install, opens the account database', () async {
    http.on('POST /auth/login', Reply(200, _session(_alice, 'tok-1')));

    final session = await auth.login(email: 'a@example.test', password: 'correct horse battery');

    final body = http.sent('POST /auth/login').single.data as Map;
    expect(body['device_id'], accounts.device);
    expect((tokens.token, accounts.userId, accounts.issuedAt), ('tok-1', _alice, now));
    expect(session.userId, _alice);
    final state = await session.db.select(session.db.syncState).getSingle();
    expect(
      (state.userId, state.deviceId, state.calendarTimezone),
      (_alice, accounts.device, 'America/Los_Angeles'),
    );
  });

  test('refresh rotates the token; 401 rejects; no answer keeps the old token', () async {
    tokens.token = 'old';
    http
      ..on('POST /auth/refresh', Reply(200, envelope({'token': 'new', 'token_type': 'Bearer'})))
      ..on('POST /auth/refresh', const Reply.offline())
      ..on('POST /auth/refresh', Reply(401, errorEnvelope('unauthenticated')));

    expect(await auth.refresh(), RefreshResult.refreshed);
    expect(tokens.token, 'new');
    expect(http.sent('POST /auth/refresh').single.headers['Authorization'], 'Bearer old');

    expect(await auth.refresh(), RefreshResult.unavailable);
    expect(tokens.token, 'new', reason: 'the grace window covers a lost refresh (A29)');

    expect(await auth.refresh(), RefreshResult.rejected);
    expect(tokens.token, isNull);
  });

  test('refreshIfStale waits until the token is 30 days old (A6)', () async {
    tokens.token = 'old';
    accounts.issuedAt = now.subtract(const Duration(days: 29));
    http.on('POST /auth/refresh', Reply(200, envelope({'token': 'new'})));

    await auth.refreshIfStale();
    expect(http.sent('POST /auth/refresh'), isEmpty);

    now = now.add(const Duration(days: 2));
    await auth.refreshIfStale();
    expect(tokens.token, 'new');
  });

  test('logout forgets the session but keeps the account database and its outbox', () async {
    http.on('POST /auth/login', Reply(200, _session(_alice, 'tok-1')));
    final session = await auth.login(email: 'a@example.test', password: 'correct horse battery');
    await session.db.customStatement(
      "INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, state, created_at) "
      "VALUES ('m1', 'habit', 'h1', 'habit.create', 0, '{}', 'pending', 0)",
    );

    await auth.logout();

    expect((tokens.token, accounts.userId, auth.current), (null, null, null));
    expect(await session.db.select(session.db.outbox).get(), hasLength(1));
  });

  test('switching accounts opens a separate database per user id', () async {
    http
      ..on('POST /auth/login', Reply(200, _session(_alice, 'tok-a')))
      ..on('POST /auth/login', Reply(200, _session(_bob, 'tok-b')));

    final a = await auth.login(email: 'a@example.test', password: 'correct horse battery');
    await auth.logout();
    final b = await auth.login(email: 'b@example.test', password: 'correct horse battery');

    expect(opened.keys, [_alice, _bob]);
    expect(identical(a.db, b.db), isFalse);
    expect((await b.db.select(b.db.syncState).getSingle()).userId, _bob);
  });

  test('restore reopens the stored account without the network', () async {
    tokens.token = 'tok-1';
    accounts.userId = _alice;

    final session = await auth.restore();

    expect(session?.userId, _alice);
    expect(http.requests, isEmpty);
  });
}
