import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/storage/account_store.dart';
import 'package:habit/core/storage/token_store.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/database_opener.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/background_sync.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 3.2b: best-effort background sync. The same engine on the account's own database; it
/// never touches the session; a refused BEGIN is retried, never surfaced; and a second isolate
/// writing to the same file during a sync loses nothing.
void main() {
  setUpAll(Device.loadZones);

  late Directory dir;
  late File file;
  final now = DateTime.utc(2026, 5, 28, 17, 22);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('habit_background_');
    file = File(p.join(dir.path, 'habit_account.sqlite'));
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold the WAL files briefly; the OS cleans temp.
    }
  });

  AppDatabase independent(String path) =>
      AppDatabase(NativeDatabase(File(path), setup: configureConnection));

  group('runBackgroundSync', () {
    Future<AppDatabase> seeded(FakeSyncServer server) async {
      final db = independent(file.path);
      await initAccountState(db, userId: 'user-1', deviceId: 'd1', user: server.user);
      await db.close();
      return db;
    }

    test(
      'a 401 records reauth_needed and stops; the token is never refreshed or cleared',
      () async {
        final server = FakeSyncServer()
          ..failNextSync.add(const SyncTransportException(SyncFailure.unauthorized));
        await seeded(server);
        final tokens = _Tokens('t-1');

        final outcome = await runBackgroundSync(
          accountKey: 'user-1',
          tokens: tokens,
          accounts: _Accounts('user-1'),
          open: (_) => independent(file.path),
          transport: (_) => server,
        );

        expect(outcome, SyncOutcome.loggedOut);
        expect(tokens.writes, 0);
        expect(tokens.clears, 0);
        final db = independent(file.path);
        final state = await db.select(db.syncState).getSingle();
        expect(jsonDecode(state.lastError!)['code'], 'reauth_needed');
        await db.close();
      },
    );

    test('runs nothing for an account that is no longer the signed-in one', () async {
      final server = FakeSyncServer();
      await seeded(server);
      final outcome = await runBackgroundSync(
        accountKey: 'user-1',
        tokens: _Tokens('t-1'),
        accounts: _Accounts('user-2'),
        open: (_) => independent(file.path),
        transport: (_) => server,
      );
      expect(outcome, isNull);
      expect(server.syncCalls, 0);
    });
  });

  test('a BEGIN refused with SQLITE_BUSY is retried, never surfaced', () async {
    final setup = independent(file.path);
    await setup.customStatement('CREATE TABLE IF NOT EXISTS probe (id INTEGER PRIMARY KEY)');
    await setup.close();
    // Another connection holds the write lock; this one does not wait on busy_timeout.
    final holder = sqlite.sqlite3.open(file.path)..execute('BEGIN IMMEDIATE');
    final impatient = AppDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          configureConnection(db);
          db.execute('PRAGMA busy_timeout = 0');
        },
      ),
    );
    await impatient.customSelect('SELECT 1').get(); // open before the lock matters
    Future<void>.delayed(const Duration(milliseconds: 60), () => holder.execute('COMMIT'));

    await impatient.transaction(
      () => impatient.customStatement('INSERT INTO probe DEFAULT VALUES'),
    );

    final count = await impatient.customSelect('SELECT count(*) AS c FROM probe').getSingle();
    expect(count.read<int>('c'), 1);
    await impatient.close();
    holder.close();
  });

  test(
    'the lease statements are retried when SQLite refuses the write at once (CI 38062073726)',
    () async {
      final server = FakeSyncServer();
      final setup = independent(file.path);
      await initAccountState(setup, userId: 'user-1', deviceId: 'd1', user: server.user);
      await setup.close();
      final impatient = AppDatabase(
        NativeDatabase(
          file,
          setup: (db) {
            configureConnection(db);
            db.execute('PRAGMA busy_timeout = 0');
          },
        ),
      );
      await impatient.customSelect('SELECT 1').get(); // open before the lock matters
      // Another connection holds the write lock as the engine takes its lease.
      final holder = sqlite.sqlite3.open(file.path)..execute('BEGIN IMMEDIATE');
      Future<void>.delayed(const Duration(milliseconds: 60), () => holder.execute('COMMIT'));

      final outcome = await SyncEngine(
        db: impatient,
        transport: server,
        capabilities: const ['binary'],
        clock: () => now,
      ).run(force: true);

      expect(outcome, SyncOutcome.completed);
      final state = await impatient.select(impatient.syncState).getSingle();
      expect(state.leaseOwner, isNull, reason: 'released');
      await impatient.close();
      holder.close();
    },
  );

  test('a second isolate writing during a sync run: no lost write, no SQLITE_BUSY', () async {
    final server = FakeSyncServer();
    final main = independent(file.path);
    await initAccountState(main, userId: 'user-1', deviceId: 'd1', user: server.user);
    final habit = await LocalMutationService(main, clock: () => now).createHabit(
      name: 'Stretch',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: LocalDate.parse('2026-04-28'),
      backdate: true,
    );
    final engine = SyncEngine(
      db: main,
      transport: server,
      capabilities: const ['binary'],
      clock: () => now,
    );
    expect(await engine.run(force: true), SyncOutcome.completed);

    // The other isolate: an independent connection checking in 30 past days, one by one.
    final writes = _writeFromAnotherIsolate(file.path, habit);

    // Meanwhile this isolate keeps syncing whatever has landed.
    var done = false;
    final syncing = () async {
      while (!done) {
        expect(await engine.run(force: true), isNot(SyncOutcome.failed));
        // In-isolate SQLite completes through microtasks: yield so the other isolate's
        // completion message can arrive.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }();
    await writes;
    done = true;
    await syncing;
    expect(await engine.run(force: true), SyncOutcome.completed);

    final dates = server.logs.values.map((l) => l['log_date']).toSet();
    expect(dates, hasLength(30), reason: 'every write reached the server exactly once');
    final sent = server.sentMutationIds.expand((ids) => ids).toList();
    expect(sent.toSet(), hasLength(31), reason: 'the habit and 30 check-ins, no duplicates');
    final left = await main.select(main.outbox).get();
    expect(left.where((r) => r.state != OutboxState.acked), isEmpty);
    final state = await main.select(main.syncState).getSingle();
    expect(state.lastError ?? '', isNot(contains('database is locked')));
    await main.close();
  });
}

/// Top level, so the isolate captures only these two strings (never the engine or database).
Future<void> _writeFromAnotherIsolate(String path, String habit) => Isolate.run(() async {
  ensureTimeZonesLoaded(tzdata.initializeTimeZones); // each isolate has its own tz database
  final db = AppDatabase(NativeDatabase(File(path), setup: configureConnection));
  final writer = LocalMutationService(db, clock: () => DateTime.utc(2026, 5, 28, 17, 22));
  for (var i = 0; i < 30; i++) {
    await writer.setLogValue(
      habitId: habit,
      value: 1,
      logDate: LocalDate.parse('2026-05-28').addDays(-i),
    );
  }
  await db.close();
});

class _Tokens implements TokenStore {
  _Tokens(this.token);
  final String? token;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => writes++;

  @override
  Future<void> clear() async => clears++;
}

class _Accounts implements AccountStore {
  _Accounts(this.userId);
  final String userId;

  @override
  Future<String?> readUserId() async => userId;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
