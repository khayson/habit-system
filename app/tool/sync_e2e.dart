// End-to-end run of the real sync engine against a running API (Phase 2b.1 review, F9).
// CI job `e2e` runs it; locally see docs/DEV_SETUP.md, "Sync end-to-end run".
//
//   dart run tool/sync_e2e.dart [http://127.0.0.1:8000/api/v1]
//
// Environment: E2E_DATABASE_URL (postgresql://user:pass@host:port/db, the API's database) and
// optionally E2E_PSQL (path to psql, default `psql`); they simulate a database restore.
// E2E_CLOSE_CMD runs the period closer once (e.g. `php artisan habits:close-periods --sync`).
//
// One fresh account, two devices with their own databases and tokens. Scenarios, in order:
//   setup     A creates a habit; B bootstraps it.
//   merged    both tick the same habit-day offline; B's log is merged into A's id.
//   conflict  B edits a stale version after A's edit; kept as needs_attention, then discarded.
//   restore   A deletes the day; B logs it again on the tombstone version and restores it.
//   db-restore the server journal rolls back (restore from backup): 410, re-bootstrap, outbox kept.
//   refresh   A refreshes; the old token still works inside the 10-minute grace window.
//   derived   a past day closes; B holds typed habit_progress and period_evaluation rows (A32).
//   dependency_pending  A creates a habit and ticks it in one request; both land, B converges.
//   calendar  A sets a zone; B gains the pending calendar entry; A changes back; it is gone.
//   reminders A creates, edits and deletes a reminder; B holds the typed row each time.
//   profile   A edits name, city and country (profile.update); the server and B have them.
//   photo     A chooses a photo offline (shown at once), reconnects; the engine uploads it with
//             a real multipart PUT; sm/md/lg are WebP 96/160/320; B fetches md; another
//             account never gets the bytes (404); removing it clears has_avatar and B's copy.
//             Needs PHP with GD to make the test JPEG (E2E_PHP, default `php`).
// Exits non-zero at the first failed check, or unless both databases end identical.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit/data/account_calendar.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/data/photo_service.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:habit/sync/avatar_sync.dart';
import 'package:habit/sync/http_avatar_transport.dart';
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
    // A33: the accepted docs/legal versions.
    'terms_version': '2026-10-10',
    'privacy_version': '2026-10-10',
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
    // Further back than one edit journals (the log plus its derived entities, A32), so the
    // re-sent edit cannot carry the head past B's cursor again.
    await _rollBackJournal(email, 6);
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

  await _scenario('derived', () async {
    // A32 on real data: a habit backdated two days, checked in yesterday; after the closer
    // runs, the other device receives habit_progress and period_evaluation. This client has no
    // tables for them yet, so they must arrive as opaque entities (A31, invariant 13).
    final derived = await a.writer.createHabit(
      name: 'Read',
      type: 'binary',
      target: 1,
      category: 'learning',
      startLocalDate: today.addDays(-2),
      backdate: true,
    );
    final yesterday = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    final tick = await a.writer.setLogValue(habitId: derived, value: 1, at: yesterday);
    await a.sync();
    await _closePeriods();
    await b.sync();

    final progress = await (b.db.select(
      b.db.habitProgress,
    )..where((p) => p.habitId.equals(derived))).get();
    _check(progress.length == 1, 'B holds a typed habit_progress row for the new habit');
    final evaluations = await (b.db.select(
      b.db.periodEvaluations,
    )..where((e) => e.habitId.equals(derived))).get();
    final yesterdayKey = 'd:${tick.date}';
    final closedYesterday = evaluations.where((e) => e.periodKey == yesterdayKey).toList();
    _check(closedYesterday.length == 1, 'B holds the typed evaluation for $yesterdayKey');
    _check(closedYesterday.single.completed == true, 'yesterday was completed');
    _check(
      evaluations.any((e) => e.completed == false),
      'the day before (no check-in) is closed as not completed',
    );
    _check(
      (await b.db.select(b.db.opaqueEntities).get()).every(
        (o) => o.entityType != 'habit_progress' && o.entityType != 'period_evaluation',
      ),
      'nothing derived is left opaque',
    );
  });

  await _scenario('dependency_pending', () async {
    // The habit and its first check-in travel in one request while the habit is not yet on
    // the server: the log must never be lost behind its parent.
    final fresh = await a.writer.createHabit(
      name: 'Breathe',
      type: 'binary',
      target: 1,
      category: 'mindfulness',
      startLocalDate: today,
    );
    await a.writer.setLogValue(habitId: fresh, value: 1);
    a.transport.batches.clear();
    await a.sync();
    _check(a.transport.batches.first == 2, 'one request carried both mutations');
    _check((await a.outbox()).isEmpty, 'A has nothing left to send');
    await b.sync();
    _check((await b.log(fresh, today)).value == '1', 'B sees the check-in on the new habit');
  });

  await _scenario('calendar', () async {
    Future<List<String>> entries(_Device d) async => [
      for (final e in await (d.db.select(
        d.db.calendarEntries,
      )..orderBy([(c) => OrderingTerm.asc(c.effectiveAt)])).get())
        e.timezone,
    ];
    await a.writer.setTimezone('Europe/Paris');
    await a.sync();
    await b.sync();
    _check((await entries(b)).last == 'Europe/Paris', 'B gains the pending Paris entry');
    _check(
      (await AccountCalendar.load(b.db))!.pendingAfter(DateTime.now())?.timezone == 'Europe/Paris',
      'on B it is pending, not yet in force',
    );

    await a.writer.setTimezone('America/Los_Angeles');
    await a.sync();
    await b.sync();
    _check(!(await entries(b)).contains('Europe/Paris'), "B's pending entry is removed");
    _check((await entries(a)).join(',') == (await entries(b)).join(','), 'both calendars agree');
  });

  await _scenario('reminders', () async {
    Future<ConfirmedReminder?> onB(String id) =>
        (b.db.select(b.db.reminders)..where((r) => r.id.equals(id))).getSingleOrNull();
    final id = await a.writer.createReminder(
      habitId: habit,
      localTime: '08:00',
      daysOfWeek: [1, 2, 3, 4, 5],
    );
    await a.sync();
    await b.sync();
    final created = await onB(id);
    _check(created != null && created.version == 1, 'B holds the typed reminder');
    _check(created!.localTime == '08:00' && created.daysOfWeek == '[1,2,3,4,5]', 'as created');

    await a.writer.updateReminder(
      reminderId: id,
      localTime: '07:30',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      timezoneMode: 'device_zone',
    );
    await a.sync();
    await b.sync();
    final updated = await onB(id);
    _check(updated!.version == 2 && updated.localTime == '07:30', 'B sees the edit');
    _check(updated.timezoneMode == 'device_zone', 'with its mode');

    await a.writer.deleteReminder(id);
    await a.sync();
    await b.sync();
    final deleted = await onB(id);
    _check(deleted!.version == 3 && deleted.deletedAt != null, 'B keeps the tombstone');
    _check((await a.outbox()).isEmpty, 'A has nothing left to send');
  });

  await _scenario('profile', () async {
    await a.writer.updateProfile(name: 'E2E Maya', city: 'Accra', countryCode: 'GH');
    await a.sync();
    final me = (await a.dio.get<Map<String, dynamic>>('/me')).data!['data'] as Map;
    _check(
      (me['name'], me['city'], me['country_code']) == ('E2E Maya', 'Accra', 'GH'),
      'the server user has the new name, city and country ($me)',
    );
    await b.sync();
    final onB = (await b.profile.load())!;
    _check((onB.name, onB.city, onB.countryCode) == ('E2E Maya', 'Accra', 'GH'), 'B has them');
  });

  await _scenario('photo', () async {
    final jpeg = await _makeJpeg(dir, 640, 480);
    final online = a.dio.options.baseUrl;
    // Offline: nothing answers on this port.
    a.dio.options.baseUrl = 'http://127.0.0.1:9/api/v1';
    await a.photos.choose(jpeg);
    final offline = await a.engine.run(force: true);
    _check(offline == SyncOutcome.offline, 'offline run (${offline.name})');
    final shown = (await a.profile.load())!;
    _check(shown.photoPath != null && File(shown.photoPath!).existsSync(), 'shown at once');
    _check(shown.uploadPending, 'waiting to upload');

    a.dio.options.baseUrl = online;
    await a.sync();
    final after = (await a.profile.load())!;
    _check(!after.uploadPending, 'uploaded');
    _check((after.avatarVersion, after.hasAvatar) == (1, true), 'avatar_version 1, has_avatar');
    _check(after.photoPath == shown.photoPath, 'A keeps its own photo, never downloads it');

    for (final (size, px) in [('sm', 96), ('md', 160), ('lg', 320)]) {
      final r = await a.dio.get<List<int>>(
        '/me/avatar/$size',
        options: Options(responseType: ResponseType.bytes),
      );
      _check(r.headers.value('content-type') == 'image/webp', '$size is WebP');
      _check(_webpSize(r.data!) == (px, px), '$size is ${px}x$px (${_webpSize(r.data!)})');
    }

    await b.sync();
    final onB = (await b.profile.load())!;
    _check(onB.photoPath != null && File(onB.photoPath!).existsSync(), 'B fetched md');
    _check(onB.photoPath!.endsWith('md-1.webp'), 'cached as md-1.webp');

    final other = await _Device.signIn(online, dir, 'C', '/auth/register', {
      'name': 'Other',
      'email': 'e2e-other+${DateTime.now().millisecondsSinceEpoch}@example.test',
      'password': 'e2e-password-1234',
      'timezone': 'UTC',
      'terms_version': '2026-10-10',
      'privacy_version': '2026-10-10',
    });
    final foreign = await other.dio.get<Object?>(
      '/me/avatar/md',
      options: Options(validateStatus: (_) => true),
    );
    _check(foreign.statusCode == 404, 'another account gets 404 (${foreign.statusCode})');
    await other.db.close();

    final bCopy = onB.photoPath!;
    await a.photos.remove();
    await a.sync();
    _check(!(await a.profile.load())!.hasAvatar, 'has_avatar false');
    await b.sync();
    final bAfter = (await b.profile.load())!;
    _check(!bAfter.hasAvatar && bAfter.photoPath == null, 'B shows initials');
    _check(!File(bCopy).existsSync(), 'the cached copy on B is deleted');
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

/// Runs the A10 closer once (E2E_CLOSE_CMD, e.g. `php artisan habits:close-periods --sync`).
Future<void> _closePeriods() async {
  final command = Platform.environment['E2E_CLOSE_CMD'];
  if (command == null || command.isEmpty) {
    throw StateError('E2E_CLOSE_CMD is required for the derived scenario');
  }
  // One command line, run by the platform shell (a single executable name otherwise).
  final result = Platform.isWindows
      ? await Process.run('cmd', ['/c', command])
      : await Process.run('/bin/sh', ['-c', command]);
  if (result.exitCode != 0) throw StateError('close-periods failed: ${result.stderr}');
  _say('  closer: ${'${result.stdout}'.trim()}');
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

/// A real JPEG for the photo scenario, drawn by PHP's GD (the CI runner has PHP for the API).
Future<String> _makeJpeg(Directory dir, int width, int height) async {
  final out = '${dir.path}/e2e-photo.jpg';
  final php = Platform.environment['E2E_PHP'] ?? 'php';
  final result = await Process.run(php, [
    '-r',
    r'$i = imagecreatetruecolor((int) $argv[1], (int) $argv[2]); '
        r'imagefill($i, 0, 0, imagecolorallocate($i, 40, 120, 70)); '
        r'imagejpeg($i, $argv[3], 85);',
    '$width',
    '$height',
    out,
  ]);
  if (result.exitCode != 0) throw StateError('php could not make the JPEG: ${result.stderr}');
  return out;
}

/// Width and height from a WebP header (VP8X, VP8 or VP8L).
(int, int)? _webpSize(List<int> b) {
  if (b.length < 30 || String.fromCharCodes(b.sublist(8, 12)) != 'WEBP') return null;
  int le(int at, int n) {
    var v = 0;
    for (var i = n - 1; i >= 0; i--) {
      v = (v << 8) | b[at + i];
    }
    return v;
  }

  return switch (String.fromCharCodes(b.sublist(12, 16))) {
    'VP8X' => (le(24, 3) + 1, le(27, 3) + 1),
    'VP8 ' => (le(26, 2) & 0x3fff, le(28, 2) & 0x3fff),
    'VP8L' => ((le(21, 4) & 0x3fff) + 1, ((le(21, 4) >> 14) & 0x3fff) + 1),
    _ => null,
  };
}

/// Counts bootstraps so a scenario can see that a 410 happened.
class _CountingTransport implements SyncTransport {
  _CountingTransport(this.inner);
  final SyncTransport inner;
  int bootstraps = 0;

  /// Mutations per request, in order.
  final List<int> batches = [];

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) {
    if (mutations.isNotEmpty) batches.add(mutations.length);
    return inner.sync(
      deviceId: deviceId,
      cursor: cursor,
      pullLimit: pullLimit,
      mutations: mutations,
      capabilities: capabilities,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) {
    bootstraps++;
    return inner.bootstrap(cursor: cursor, limit: limit);
  }
}

class _Device {
  _Device(this.name, this.db, this.deviceId, this.dio, this.token, this.filesRoot)
    : transport = _CountingTransport(HttpSyncTransport(dio));

  final String name;
  final AppDatabase db;
  final String deviceId;
  final Dio dio;
  final _CountingTransport transport;
  String token;
  late final writer = LocalMutationService(db);

  /// Phase 3b: this device's own folder for the profile photo.
  final String filesRoot;
  late final photos = PhotoService(db, filesRoot: filesRoot);
  late final profile = ProfileView(db, filesRoot: filesRoot);
  late final engine = SyncEngine(
    db: db,
    transport: transport,
    capabilities: ProvisionalTypeRegistry.builtins().keys.toList(),
    avatars: AvatarSync(db: db, transport: HttpAvatarTransport(dio), filesRoot: filesRoot),
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
    final files = Directory('${dir.path}/files_$name')..createSync(recursive: true);
    return _Device(name, db, deviceId, dio, token, files.path);
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
      'calendar': [
        for (final e in await (db.select(
          db.calendarEntries,
        )..orderBy([(c) => OrderingTerm.asc(c.effectiveAt)])).get())
          '${e.effectiveAt} ${e.timezone} ${e.dayStartOffsetMinutes}',
      ],
      'reminders': [
        for (final r in await (db.select(
          db.reminders,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get())
          '${r.id} ${r.localTime} ${r.daysOfWeek} v${r.version} deleted=${r.deletedAt != null}',
      ],
      'outbox': (await outbox()).length,
    };
  }
}
