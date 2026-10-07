// Scripted run of the real sync engine against a running local API (Phase 2b.1 gate).
// Not part of CI. See docs/DEV_SETUP.md, "Sync smoke run".
//
//   dart run tool/sync_smoke.dart [http://127.0.0.1:8000/api/v1]
//
// Registers a fresh account, then plays two devices with their own databases and tokens:
// A creates a habit and ticks today; B bootstraps and sees both; B unticks; A pulls the
// change. Exits non-zero unless both databases hold the same confirmed state.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:habit/sync/http_sync_transport.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  final baseUrl = args.isEmpty ? 'http://127.0.0.1:8000/api/v1' : args.first;
  ensureTimeZonesLoaded(tzdata.initializeTimeZones);
  final dir = Directory.systemTemp.createTempSync('habit_smoke_');

  final email = 'smoke+${DateTime.now().millisecondsSinceEpoch}@example.test';
  const password = 'smoke-password-123';
  const zone = 'America/Los_Angeles';
  final a = await _Device.signIn(baseUrl, dir, 'A', '/auth/register', {
    'name': 'Smoke',
    'email': email,
    'password': password,
    'timezone': zone,
  });
  final b = await _Device.signIn(baseUrl, dir, 'B', '/auth/login', {
    'email': email,
    'password': password,
  });
  _say('registered $email; device A ${a.deviceId}, device B ${b.deviceId}');

  await a.sync('A bootstrap');
  final habitId = await a.writer.createHabit(
    name: 'Stretch',
    type: 'binary',
    target: 1,
    category: 'health',
    // Today in the account's zone: a past start would need date_mode "backdate".
    startLocalDate: LocalDate.parse(
      tz.TZDateTime.now(tz.getLocation(zone)).toIso8601String().substring(0, 10),
    ),
  );
  final tick = await a.writer.setLogValue(habitId: habitId, value: 1);
  _say('A wrote habit $habitId and ticked ${tick.date} (outbox: ${await a.pending()})');
  await a.sync('A push');

  await b.sync('B bootstrap');
  final untick = await b.writer.setLogValue(habitId: habitId, value: 0);
  _say('B unticked ${untick.date} (outbox: ${await b.pending()})');
  await b.sync('B push');
  await a.sync('A pull');

  final stateA = await a.snapshot();
  final stateB = await b.snapshot();
  _say('A: $stateA');
  _say('B: $stateB');
  await a.db.close();
  await b.db.close();

  final converged =
      jsonEncode(stateA) == jsonEncode(stateB) &&
      (stateA['habits'] as List).length == 1 &&
      (stateA['logs'] as List).length == 1 &&
      stateA['outbox'] == 0;
  _say(converged ? 'CONVERGED' : 'DIVERGED');
  exit(converged ? 0 : 1);
}

void _say(String line) => stdout.writeln('[smoke] $line');

class _Device implements AuthSession {
  _Device(this.name, this.db, this.deviceId, this.dio);

  final String name;
  final AppDatabase db;
  final String deviceId;
  final Dio dio;
  late final writer = LocalMutationService(db);

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
      data: {...body, 'device_name': 'smoke $name', 'device_id': deviceId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    dio.options.headers['Authorization'] = 'Bearer ${data['token']}';
    final user = (data['user'] as Map).cast<String, dynamic>();
    final db = AppDatabase(NativeDatabase(File('${dir.path}/habit_${user['id']}_$name.sqlite')));
    await initAccountState(db, userId: user['id'] as String, deviceId: deviceId, user: user);
    return _Device(name, db, deviceId, dio);
  }

  Future<void> sync(String label) async {
    final outcome = await SyncEngine(
      db: db,
      transport: HttpSyncTransport(dio),
      auth: this,
      capabilities: ProvisionalTypeRegistry.builtins().keys.toList(),
    ).run();
    _say('$label: $outcome (outbox: ${await pending()})');
    if (outcome != SyncOutcome.completed) throw StateError('$label did not complete');
  }

  Future<int> pending() async {
    final rows = await db.select(db.outbox).get();
    for (final r in rows) {
      _say('  $name outbox ${r.operation} ${r.state} ${r.lastError ?? ''}');
    }
    return rows.length;
  }

  /// Confirmed server state only (invariant 9), in a comparable form.
  Future<Map<String, Object?>> snapshot() async {
    final habits = await (db.select(db.habits)..orderBy([(h) => OrderingTerm.asc(h.id)])).get();
    final logs = await (db.select(db.habitLogs)..orderBy([(l) => OrderingTerm.asc(l.id)])).get();
    return {
      'habits': [for (final h in habits) '${h.id} ${h.name} v${h.version}'],
      'logs': [
        for (final l in logs) '${l.logDate} value=${l.value} v${l.version} deleted=${l.deletedAt}',
      ],
      'outbox': await pending(),
    };
  }

  @override
  Future<RefreshResult> refresh() async => RefreshResult.rejected;

  @override
  Future<void> logout() async => _say('$name was logged out');
}
