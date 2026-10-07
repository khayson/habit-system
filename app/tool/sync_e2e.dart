// End-to-end run of the real sync engine against a running API (Phase 2b.1 review, F9).
// CI job `e2e` runs it; locally see docs/DEV_SETUP.md, "Sync end-to-end run".
//
//   dart run tool/sync_e2e.dart [http://127.0.0.1:8000/api/v1]
//
// Environment: E2E_DATABASE_URL (postgresql://user:pass@host:port/db, the API's database) and
// optionally E2E_PSQL (path to psql, default `psql`). They simulate a database restore.
//
// One fresh account, two devices with their own databases and tokens. Scenarios, in order:
//   setup     A creates a habit; B bootstraps it.
//   merged    both tick the same habit-day offline; B's log is merged into A's id.
//   conflict  B edits a stale version after A's edit; kept as needs_attention, then discarded.
//   restore   A deletes the day; B logs it again on the tombstone version and restores it.
//   db-restore the server journal rolls back (restore from backup): 410, re-bootstrap, outbox kept.
//   refresh   A refreshes; the old token still works inside the 10-minute grace window.
// Exits non-zero at the first failed check, or unless both databases end identical.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit/data/account_calendar.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:habit/sync/http_sync_transport.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  final baseUrl = args.isEmpty ? 'http://127.0.0.1:8000/api/v1' : args.first;
  ensureTimeZonesLoaded(tzdata.initializeTimeZones);
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final dir = Directory.systemTemp.createTempSync('habit_e2e_');

  final email = 'e2e+${DateTime.now().millisecondsSinceEpoch}@example.test';
  const password = 'e2e-password-1234';
  final a = await _Device.signIn(baseUrl, dir, 'A', '/auth/register', {
    'name': 'E2E',
    'email': email,
    'password': password,
    'timezone': 'America/Los_Angeles',
  });
  final b = await _Device.signIn(baseUrl, dir, 'B', '/auth/login', {
    'email': email,
    'password': password,
  });
  _say('account $email; device A ${a.deviceId}, device B ${b.deviceId}');

  late String habit;
  late LocalDate today;

  await _scenario('setup', () async {
    await a.sync();
    today = await a.today();
    habit = await a.writer.createHabit(
      name: 'Stretch',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: today,
    );
    await a.sync();
    await b.sync();
    _check((await b.db.select(b.db.habits).get()).single.id == habit, 'B sees the habit');
  });

  await _scenario('merged', () async {
    await a.writer.setLogValue(habitId: habit, value: 1);
    await b.writer.setLogValue(habitId: habit, value: 1);
    final aLocal = (await a.outbox()).single.entityId;
    final bLocal = (await b.outbox()).single.entityId;
    _check(aLocal != bLocal, 'each device minted its own log id');
    await a.sync();
    await b.sync();
    await a.sync();
    final la = await a.log(habit, today);
    final lb = await b.log(habit, today);
    _check(la.id == aLocal && lb.id == aLocal, 'B was remapped to the canonical id ($aLocal)');
    _check(await b.outbox().then((r) => r.isEmpty), 'B queue drained');
    _check((la.value, lb.value) == ('1', '1'), 'both ticked');
  });

  await _scenario('conflict', () async {
    await a.writer.setLogValue(habitId: habit, value: 0);
    await a.sync(); // v2 = 0
    // B has not pulled A's edit: it writes on v1 while the server holds 0 at v2.
    await b.writer.setLogValue(habitId: habit, value: 1);
    await b.sync();
    final row = (await b.outbox()).single;
    final error = jsonDecode(row.lastError ?? '{}') as Map;
    _check(row.state == OutboxState.needsAttention, 'stale edit kept for review (${row.state})');
    _check(error['code'] == 'version_conflict', 'version_conflict (${error['code']})');
    _check(jsonDecode(row.payload)['value'] == 1, 'the user value is kept');
    _check((await b.log(habit, today)).value == '0', 'B pulled the other edit');
    _check(await b.writer.discard(row.mutationId), 'discarded');
    await b.sync();
    _check(await b.outbox().then((r) => r.isEmpty), 'queue clean after discard');
    _check(
      (await b.db.select(b.db.discardedMutations).get()).length == 1,
      'the discard is recorded',
    );
  });

  await _scenario('restore', () async {
    await a.writer.deleteLog(habitId: habit, date: today);
    await a.sync();
    await b.sync();
    final tomb = await b.log(habit, today);
    _check(tomb.deletedAt != null, 'B sees the tombstone');
    await b.writer.setLogValue(habitId: habit, value: 1);
    _check((await b.outbox()).single.baseVersion == tomb.version, 'based on the tombstone');
    await b.sync();
    await a.sync();
    final la = await a.log(habit, today);
    final lb = await b.log(habit, today);
    _check(la.deletedAt == null && lb.deletedAt == null, 'restored on both');
    _check(la.version == lb.version && la.version == tomb.version + 1, 'one version bump');
    _check(la.id == tomb.id, 'the same row came back');
  });

  await _scenario('db-restore', () async {
    await a.writer.setLogValue(habitId: habit, value: 0); // queued before the restore
    await _rollBackJournal(email, 2);
    final before = a.transport.bootstraps;
    await a.sync();
    _check(a.transport.bootstraps > before, 'A got 410 and bootstrapped again');
    _check(await a.outbox().then((r) => r.isEmpty), 'the queued edit survived and was sent');
    final beforeB = b.transport.bootstraps;
    await b.sync();
    _check(b.transport.bootstraps > beforeB, 'B bootstrapped again too');
    _check((await b.log(habit, today)).value == '0', 'B has the post-restore edit');
  });

  await _scenario('refresh', () async {
    final old = a.token;
    final refreshed = await a.dio.post<Map<String, dynamic>>('/auth/refresh');
    final fresh = (refreshed.data!['data'] as Map)['token'] as String;
    _check(fresh != old, 'a new token');
    await a.writer.setLogValue(habitId: habit, value: 1);
    a.useToken(old);
    await a.sync(); // inside the grace window
    a.useToken(fresh);
    await a.writer.setLogValue(habitId: habit, value: 0);
    await a.sync();
    await b.sync();
    _check((await b.log(habit, today)).value == '0', 'B sees both edits');
  });

  await a.sync();
  await b.sync();
  final stateA = await a.snapshot();
  final stateB = await b.snapshot();
  _say('A: $stateA');
  _say('B: $stateB');
  await a.db.close();
  await b.db.close();
  final converged = jsonEncode(stateA) == jsonEncode(stateB) && stateA['outbox'] == 0;
  _say(converged ? 'CONVERGED' : 'DIVERGED');
  exit(converged ? 0 : 1);
}

void _say(String line) => stdout.writeln('[e2e] $line');

void _check(bool ok, String what) {
  if (!ok) throw StateError('check failed: $what');
}

Future<void> _scenario(String name, Future<void> Function() body) async {
  try {
    await body();
    _say('PASS $name');
  } on Object catch (e) {
    _say('FAIL $name: $e');
    exit(1);
  }
}

/// A restore from an older backup, as the API sees it: the user's journal head moves back and
/// the newest journal rows are gone, so every device's cursor is ahead of the head (A29: 410).
Future<void> _rollBackJournal(String email, int rows) async {
  final url = Platform.environment['E2E_DATABASE_URL'];
  if (url == null || url.isEmpty) {
    throw StateError('E2E_DATABASE_URL is required for the db-restore scenario');
  }
  final psql = Platform.environment['E2E_PSQL'] ?? 'psql';
  final sql =
      '''
BEGIN;
DELETE FROM server_changes s USING users u
  WHERE u.email = '$email' AND s.user_id = u.id AND s.seq > u.change_seq - $rows;
UPDATE users SET change_seq = change_seq - $rows WHERE email = '$email';
COMMIT;''';
  final result = await Process.run(psql, [url, '-v', 'ON_ERROR_STOP=1', '-c', sql]);
  if (result.exitCode != 0) throw StateError('psql failed: ${result.stderr}');
}

/// Counts bootstraps so a scenario can see that a 410 happened.
class _CountingTransport implements SyncTransport {
  _CountingTransport(this.inner);
  final SyncTransport inner;
  int bootstraps = 0;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) => inner.sync(
    deviceId: deviceId,
    cursor: cursor,
    pullLimit: pullLimit,
    mutations: mutations,
    capabilities: capabilities,
  );

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) {
    bootstraps++;
    return inner.bootstrap(cursor: cursor, limit: limit);
  }
}

class _Device implements AuthSession {
  _Device(this.name, this.db, this.deviceId, this.dio, this.token)
    : transport = _CountingTransport(HttpSyncTransport(dio));

  final String name;
  final AppDatabase db;
  final String deviceId;
  final Dio dio;
  final _CountingTransport transport;
  String token;
  late final writer = LocalMutationService(db);
  late final engine = SyncEngine(
    db: db,
    transport: transport,
    auth: this,
    capabilities: ProvisionalTypeRegistry.builtins().keys.toList(),
  );

  static Future<_Device> signIn(
    String baseUrl,
    Directory dir,
    String name,
    String path,
    Map<String, Object?> body,
  ) async {
    final deviceId = const Uuid().v7();
    final dio = Dio(BaseOptions(baseUrl: baseUrl, headers: {'Accept': 'application/json'}));
    final response = await dio.post<Map<String, dynamic>>(
      path,
      data: {...body, 'device_name': 'e2e $name', 'device_id': deviceId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    dio.options.headers['Authorization'] = 'Bearer $token';
    final user = (data['user'] as Map).cast<String, dynamic>();
    final db = AppDatabase(NativeDatabase(File('${dir.path}/habit_${user['id']}_$name.sqlite')));
    await initAccountState(db, userId: user['id'] as String, deviceId: deviceId, user: user);
    return _Device(name, db, deviceId, dio, token);
  }

  void useToken(String value) {
    token = value;
    dio.options.headers['Authorization'] = 'Bearer $value';
  }

  Future<void> sync() async {
    final outcome = await engine.run(force: true);
    final rows = await outbox();
    _say('  $name sync: ${outcome.name} (outbox ${rows.map((r) => r.state).join(', ')})');
    if (outcome != SyncOutcome.completed) {
      final state = await (db.select(db.syncState)).getSingle();
      throw StateError('$name sync ended ${outcome.name}: ${state.lastError}');
    }
  }

  Future<LocalDate> today() async => (await AccountCalendar.load(db))!.today(DateTime.now());

  Future<List<OutboxRow>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Future<ConfirmedLog> log(String habitId, LocalDate date) => (db.select(
    db.habitLogs,
  )..where((l) => l.habitId.equals(habitId) & l.logDate.equals(date.toString()))).getSingle();

  /// Confirmed server state only (invariant 9), in a comparable form.
  Future<Map<String, Object?>> snapshot() async {
    final habits = await (db.select(db.habits)..orderBy([(h) => OrderingTerm.asc(h.id)])).get();
    final logs = await (db.select(db.habitLogs)..orderBy([(l) => OrderingTerm.asc(l.id)])).get();
    return {
      'habits': [for (final h in habits) '${h.id} ${h.name} v${h.version}'],
      'logs': [
        for (final l in logs)
          '${l.id} ${l.logDate} value=${l.value} v${l.version} deleted=${l.deletedAt != null}',
      ],
      'outbox': (await outbox()).length,
    };
  }

  @override
  Future<RefreshResult> refresh() async => RefreshResult.rejected;

  @override
  Future<void> logout() async => _say('$name was logged out');
}
