import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/legal_config.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/core/storage/account_store.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/models/account_deletion.dart';
import 'package:habit/services/auth_service.dart';

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../support/contract_fixtures.dart';
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

  final Map<String, String> deletionReceipts = {};

  @override
  Future<Map<String, String>> readDeletionReceipts() async => {...deletionReceipts};

  @override
  Future<void> addDeletionReceipt(String deletionId, String token) async =>
      deletionReceipts[deletionId] = token;
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
  late List<String> deletedDatabases;

  setUp(() {
    deletedDatabases = [];
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
      deleteDatabase: (userId) async => deletedDatabases.add(userId),
      clock: () => now,
    );
  });

  group('A50: password reset by code', () {
    final forgot = contractFixture('auth/forgot_password.json');
    final reset = contractFixture('auth/reset_password.json');

    test('both fixtures declare the Dart suite', () {
      expect(forgot['suites'], contains('dart'));
      expect(reset['suites'], contains('dart'));
    });

    test('asks for a code with the fixture body and needs no session', () async {
      final accepted = forgot['accepted'] as Map<String, dynamic>;
      http.on(
        'POST /auth/forgot-password',
        Reply(accepted['status'] as int, materialize(accepted['body'])),
      );

      await auth.requestPasswordReset((forgot['request'] as Map)['email'] as String);

      final sent = http.sent('POST /auth/forgot-password').single;
      expectContract(forgot['request'], sent.data);
      expect(sent.headers['Authorization'], isNull);
    });

    test('resets with the fixture body; the 204 changes nothing on the device', () async {
      final request = reset['request'] as Map<String, dynamic>;
      http.on('POST /auth/reset-password', Reply((reset['reset'] as Map)['status'] as int));

      await auth.resetPassword(
        email: request['email'] as String,
        code: request['reset_token'] as String,
        password: request['password'] as String,
        confirmation: request['password_confirmation'] as String,
      );

      expectContract(request, http.sent('POST /auth/reset-password').single.data);
      expect((tokens.token, accounts.userId), (null, null));
    });

    for (final (name, field) in [('invalid_code', 'reset_token'), ('weak_password', 'password')]) {
      test('$name is the field error from the server', () async {
        final error = reset[name] as Map<String, dynamic>;
        http.on(
          'POST /auth/reset-password',
          Reply(error['status'] as int, materialize(error['body'])),
        );
        final expected = (((error['body'] as Map)['error'] as Map)['fields'] as Map)[field];

        await expectLater(
          auth.resetPassword(
            email: 'm@example.com',
            code: '000000',
            password: 'x',
            confirmation: 'x',
          ),
          throwsA(isA<AppException>().having((e) => e.fields[field], field, expected)),
        );
      });
    }
  });

  group('A49: account deletion', () {
    final fixture = contractFixture('auth/delete_me.json');
    final statuses = contractFixture('auth/account_deletion_status.json');

    test('both fixtures declare the Dart suite', () {
      expect(fixture['suites'], contains('dart'));
      expect(statuses['suites'], contains('dart'));
    });

    test('sends the fixture body and decodes the 202 receipt', () async {
      http.on('POST /auth/login', Reply(200, _session(_alice, 'tok-1')));
      await auth.login(email: 'a@example.test', password: 'correct horse battery');
      final accepted = fixture['accepted'] as Map<String, dynamic>;
      http.on('DELETE /me', Reply(accepted['status'] as int, materialize(accepted['body'])));

      final receipt = await auth.requestAccountDeletion(
        (fixture['request'] as Map)['password'] as String,
      );

      expectContract(fixture['request'], http.sent('DELETE /me').single.data);
      expect(http.sent('DELETE /me').single.headers['Authorization'], 'Bearer tok-1');
      expect(receipt.deletion.status, AccountDeletionStatus.queued);
      expect(receipt.token, materialize('{{secret}}'));
      expect(receipt.expiresAt, DateTime.utc(2026, 5, 28, 17, 22));
      expect(tokens.token, 'tok-1', reason: 'nothing local changes before the caller decides');
      expect(deletedDatabases, isEmpty);
    });

    test('a wrong password is the field error from the server', () async {
      http.on('POST /auth/login', Reply(200, _session(_alice, 'tok-1')));
      await auth.login(email: 'a@example.test', password: 'correct horse battery');
      final wrong = fixture['wrong_password'] as Map<String, dynamic>;
      http.on('DELETE /me', Reply(wrong['status'] as int, materialize(wrong['body'])));

      await expectLater(
        auth.requestAccountDeletion('not it'),
        throwsA(
          isA<AppException>().having((e) => e.fields['password'], 'password', [
            'The password is incorrect.',
          ]),
        ),
      );
      expect(tokens.token, 'tok-1');
    });

    for (final status in ['queued', 'purging', 'completed']) {
      test('decodes a $status deletion status', () {
        final json = materialize((statuses['statuses'] as Map)[status]) as Map<String, dynamic>;
        final deletion = AccountDeletion.fromJson(json);
        expect(deletion.status.name, status);
        expect(deletion.completedAt == null, status != 'completed');
      });
    }

    test('an unknown status word is kept as unknown, never a crash', () {
      final json = {
        ...materialize((statuses['statuses'] as Map)['queued']) as Map<String, dynamic>,
        'status': 'archived',
      };
      expect(AccountDeletion.fromJson(json).status, AccountDeletionStatus.unknown);
    });

    test(
      "forgetting keeps the receipt, ends the session, and deletes only this account's database",
      () async {
        http
          ..on('POST /auth/login', Reply(200, _session(_bob, 'tok-b')))
          ..on('POST /auth/login', Reply(200, _session(_alice, 'tok-a')));
        await auth.login(email: 'b@example.test', password: 'correct horse battery');
        await auth.login(email: 'a@example.test', password: 'correct horse battery');
        var ended = 0;
        auth.onSessionEnded = () => ended++;
        final accepted = fixture['accepted'] as Map<String, dynamic>;
        final receipt = DeletionReceipt.fromJson(
          ((materialize(accepted['body']) as Map)['data'] as Map).cast<String, dynamic>(),
        );

        await auth.forgetDeletedAccount(receipt);

        expect(deletedDatabases, [_alice]);
        expect(accounts.deletionReceipts, {receipt.deletion.id: receipt.token});
        expect((tokens.token, accounts.userId, auth.current), (null, null, null));
        expect(ended, 1);
        expect(accounts.device, isNotNull, reason: 'the install keeps its device id');
      },
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

  test('A33: register sends the body in contract-fixtures/auth/register_request.json', () async {
    http.on('POST /auth/register', Reply(201, _session(_alice, 'tok-1')));
    final fixture = contractFixture('auth/register_request.json');
    expect(fixture['suites'], contains('dart'));
    final expected = fixture['request'] as Map<String, dynamic>;

    await auth.register(
      name: expected['name'] as String,
      email: expected['email'] as String,
      password: expected['password'] as String,
      timezone: expected['timezone'] as String,
    );

    final body = Map<String, dynamic>.from(http.sent('POST /auth/register').single.data as Map);
    // The device name is the platform's; every other field matches the fixture exactly.
    expect(body['device_name'], isA<String>());
    expectContract({...expected, 'device_name': body['device_name']}, body);
    expect(
      (body['terms_version'], body['privacy_version']),
      (LegalVersions.terms, LegalVersions.privacy),
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

  test('F5: concurrent refreshes share one request', () async {
    tokens.token = 'old';
    http.on('POST /auth/refresh', Reply(200, envelope({'token': 'new'})));

    final results = await Future.wait([for (var i = 0; i < 10; i++) auth.refresh()]);

    expect(results, everyElement(RefreshResult.refreshed));
    expect(http.sent('POST /auth/refresh'), hasLength(1));
    expect(tokens.token, 'new');

    await auth.refresh();
    expect(http.sent('POST /auth/refresh'), hasLength(2), reason: 'a later call refreshes again');
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
