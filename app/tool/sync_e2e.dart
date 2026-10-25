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
//   rewards   the merged tick earned 10 XP once; B holds it in the typed reward_state table (A39).
//   conflict  B edits a stale version after A's edit; kept as needs_attention, then discarded.
//   restore   A deletes the day; B logs it again on the tombstone version and restores it.
//   db-restore the server journal rolls back (restore from backup): 410, re-bootstrap, outbox kept.
//   refresh   A refreshes; the old token still works inside the 10-minute grace window.
//   derived   a past day closes; B holds typed habit_progress and period_evaluation rows (A32).
//   dependency_pending  A creates a habit and ticks it in one request; both land, B converges.
//   calendar  A sets a zone; B gains the pending calendar entry; A changes back; it is gone.
//   reminders A creates, edits and deletes a reminder; B holds the typed row each time.
//   profile   A edits name, city and country (profile.update); the server and B have them.
//   autofreeze A turns auto-protect on; B pulls it. Opposite toggles converge on the later one
//             (A45); a profile edit and the switch queued together both apply.
//   photo     A chooses a photo offline (shown at once), reconnects; the engine uploads it with
//             a real multipart PUT; sm/md/lg are WebP 96/160/320; B fetches md; another
//             account never gets the bytes (404); removing it clears has_avatar and B's copy.
//             Needs PHP with GD to make the test JPEG (E2E_PHP, default `php`).
//   habit-offline  A creates, edits, archives and restores a habit offline, then syncs: one
//             create (the edit folded in), the server's definitions, two adjacent ranges (A34).
//   habit-pending  A raises a synced habit's target: the server dates the new version after
//             today, and Today keeps the old target (the definition in force).
//   habit-stale    B edits a habit A already changed: version_conflict, kept with `current`.
//   habit-schedules A creates five habits offline through the validated draft (4.2b, the first
//             non-daily schedules the app sends): daily, weekdays, 3 a week, every 2 days and a
//             30-minute duration (1800 s). Every ack is accepted; the canonical schedule B
//             pulls equals what A shows (weekdays sorted).
//   habit-archived A archives a habit; B's later check-in is habit_archived, kept for review.
//   log-increment  A and B add to the same habit-day offline (A35); both sync: the total is the
//             sum on both devices and the server, nothing needs a look.
//   log-conflict   B writes a stale value: keep synced converges on the server's value; then A
//             writes a stale value and uses its own (A37): both converge on A's, a higher version.
//   log-deleted    A deletes the day, B adds to it: kept with `current`; use mine restores the
//             day with B's amount.
//   completion     A completes a quantity habit: the engine's AckWatch yields xp_delta 10; B's
//             reward_state rises by 10; a further add yields none; below target -10; again +10.
//   insights       GET /insights counts a synced backdated completion and its XP; a not-due
//             check-in raises xp_earned but not the totals (A47).
//   timer-draft    A times a duration habit offline (start, pause, resume, finish, A36): one
//             increment of whole seconds; after sync both devices agree.
//   export    A requests a JSON export (A48); the queue worker builds it (E2E_QUEUE_CMD, e.g.
//             `php artisan queue:work --stop-when-empty`); the zip downloads, its manifest
//             verifies with E2E_EXPORT_KEY (kid:secret, the server's EXPORT_SIGNING_KEYS) and
//             every file hash matches; habit and log counts equal A's. A CSV export quotes and
//             neutralises a habit named with a leading = (A16).
//   delete-account  a fresh account on two devices (A49): C1 deletes it with its password;
//             C2's next sync is logged out (401); the receipt reads queued, then completed after
//             one queue worker pass (E2E_QUEUE_CMD runs the purge); the old credentials fail
//             like a wrong password; the email registers again.
//   password-reset  a fresh account on two devices (A50): a code is requested; the tool reads it
//             from the API's log mailer (E2E_MAIL_LOG, the API's storage/logs/laravel.log; local
//             and CI only, where MAIL_MAILER=log); a wrong code is refused; the reset revokes
//             both devices (401 on /me, the next sync logged out); the new password signs in.
//   habit-delete  a fresh account on two devices (A51): E1 deletes a habit with check-ins while
//             E2 holds an unsent increment for it; after syncing neither device has the habit,
//             E2's increment waits in its queue as deleted on another device (discard only),
//             and XP is unchanged on both.
// Exits non-zero at the first failed check, or unless both databases end identical.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit/data/account_calendar.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/conflicts.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/data/photo_service.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/domain/habit_schedule.dart';
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
    habit = await a.writer.createHabitUnchecked(
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

  await _scenario('rewards', () async {
    // One completed habit-day, ticked on both devices: 10 XP once (A40). Since 5.2a B keeps
    // reward_state in its typed table, never opaque (A39).
    await b.sync();
    final rewards = await b.db.select(b.db.rewardState).get();
    _check(rewards.length == 1, 'B holds one reward_state (${rewards.length})');
    _check(rewards.single.xp == 10, 'xp 10 (${rewards.single.xp})');
    _check(rewards.single.freezeBalance == 2, 'the signup grant (${rewards.single.freezeBalance})');
    final opaque = await (b.db.select(
      b.db.opaqueEntities,
    )..where((o) => o.entityType.like('%reward_state'))).get();
    _check(opaque.isEmpty, 'no opaque reward_state (${opaque.length})');
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
    final derived = await a.writer.createHabitUnchecked(
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
    final fresh = await a.writer.createHabitUnchecked(
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

  await _scenario('autofreeze', () async {
    // A42 / A45: the switch is a desired state on the user entity.
    await a.writer.setAutoFreeze(true);
    await a.sync();
    await b.sync();
    _check((await b.profile.load())!.autoFreeze, 'B pulled auto_freeze on');

    // Opposite choices at once: both end on the choice that reached the server last, nothing
    // needs a look.
    await a.writer.setAutoFreeze(false);
    await b.writer.setAutoFreeze(true);
    await a.sync();
    await b.sync(); // stale base: rebased once (A45)
    await a.sync();
    final onA = (await a.profile.load())!;
    final onB = (await b.profile.load())!;
    _check(
      onA.autoFreeze && onB.autoFreeze,
      'both on the later write (${onA.autoFreeze}, ${onB.autoFreeze})',
    );
    _check(!onA.autoFreezeNeedsAttention && !onB.autoFreezeNeedsAttention, 'nothing needs a look');

    // A profile edit and the switch queued in one offline session both apply.
    await a.writer.updateProfile(name: 'E2E Maya', city: 'Kumasi', countryCode: 'GH');
    await a.writer.setAutoFreeze(false);
    await a.sync();
    await a.sync();
    final me = (await a.dio.get<Map<String, dynamic>>('/me')).data!['data'] as Map;
    _check((me['city'], me['auto_freeze']) == ('Kumasi', false), 'both applied ($me)');
    _check((await a.outbox()).isEmpty, 'nothing left in the queue');
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

  HabitDraft drink(String name, {String target = '2000.000'}) => HabitDraft(
    name: name,
    category: 'health',
    targetValue: target,
    unit: 'ml',
    frequencyType: 'daily',
    frequencyConfig: const {},
  );
  Future<String> water(_Device d) => d.writer.createHabitUnchecked(
    name: 'Water',
    type: 'quantity',
    target: '2000.000',
    unit: 'ml',
    category: 'health',
    startLocalDate: today,
  );
  Future<Map<String, dynamic>> confirmedHabit(_Device d, String id) async {
    final row = await (d.db.select(d.db.habits)..where((h) => h.id.equals(id))).getSingle();
    return EntityCodec.habitPayload(row);
  }

  await _scenario('habit-offline', () async {
    final id = await water(a);
    await a.writer.updateHabit(id, drink('Water daily'));
    await a.writer.archiveHabit(id);
    await a.writer.restoreHabit(id);
    _check(
      (await a.outbox()).map((r) => r.operation).join(',') ==
          'habit.create,habit.archive,habit.restore',
      'the edit folded into the unsent create',
    );
    await a.sync();
    final habit = await confirmedHabit(a, id);
    _check(habit['name'] == 'Water daily', 'the folded edit reached the server');
    final ranges = (habit['active_ranges'] as List).cast<Map<String, dynamic>>();
    _check(ranges.length == 2, 'two active ranges (${ranges.length})');
    _check(
      ranges[0]['ends_before'] == ranges[1]['starts_on'] && ranges[1]['ends_before'] == null,
      'adjacent, the second open ($ranges)',
    );
    _check((habit['definitions'] as List).length == 1, "the server's single definition");
    await b.sync();
  });

  late String pendingHabit;
  await _scenario('habit-pending', () async {
    pendingHabit = await water(a);
    await a.sync();
    await a.writer.setLogValue(habitId: pendingHabit, value: '2200.000');
    await a.writer.updateHabit(pendingHabit, drink('Water', target: '2500.000'));
    await a.sync();
    final habit = await confirmedHabit(a, pendingHabit);
    final versions = HabitSchedule.fromWire(habit).versions;
    _check(versions.length == 2, 'a pending version (${versions.length})');
    _check(
      versions.last.effectiveDate.isAfter(today),
      'dated after today: ${versions.last.effectiveDate}',
    );
    final item = (await LocalView(a.db).today(DateTime.now()))!.items
        .singleWhere((i) => i.habit.id == pendingHabit);
    _check(item.complete, "today keeps the 2000 in force: 2200 completes it");
    await b.sync();
  });

  await _scenario('habit-stale', () async {
    await b.sync();
    await a.writer.updateHabit(pendingHabit, drink('Water (A)', target: '2500.000'));
    await a.sync();
    await b.writer.updateHabit(pendingHabit, drink('Water (B)', target: '2500.000'));
    await b.sync();
    final row = (await b.outbox()).single;
    final error = jsonDecode(row.lastError!) as Map;
    _check(row.state == OutboxState.needsAttention, 'kept for review (${row.state})');
    _check(error['code'] == 'version_conflict', 'version_conflict (${error['code']})');
    _check((error['current'] as Map)['name'] == 'Water (A)', "`current` is A's habit");
    _check(await b.writer.discard(row.mutationId), 'discarded');
    await b.sync();
  });

  await _scenario('habit-archived', () async {
    await b.sync();
    await a.writer.archiveHabit(pendingHabit);
    await a.sync();
    // B has not synced since: its check-in goes to a habit the server has archived.
    await b.writer.setLogValue(habitId: pendingHabit, value: '100.000');
    await b.sync();
    final row = (await b.outbox()).single;
    _check(row.state == OutboxState.needsAttention, 'kept for review (${row.state})');
    _check((jsonDecode(row.lastError!) as Map)['code'] == 'habit_archived', 'habit_archived');
    _check(jsonDecode(row.payload)['value'] == '100.000', 'the check-in is kept');
    _check(await b.writer.discard(row.mutationId), 'discarded');
  });

  await _scenario('habit-schedules', () async {
    HabitDraft every(String name, String type, Object target, Map<String, dynamic> config) =>
        HabitDraft(
          name: name,
          category: 'health',
          targetValue: target,
          unit: null,
          frequencyType: type,
          frequencyConfig: config,
        );
    final drafts = {
      'Daily stretch': every('Daily stretch', 'daily', 1, const {}),
      'Gym': every('Gym', 'weekdays', 1, {
        'days': [5, 1, 3],
      }),
      'Swim': every('Swim', 'weekly_count', 1, {'count': 3}),
      'Plants': every('Plants', 'interval', 1, {
        'every_n_days': 2,
        'anchor_date': today.toString(),
      }),
    };
    final ids = <String, String>{};
    for (final d in drafts.values) {
      ids[d.name] = await a.writer.createHabit(d, type: 'binary');
    }
    ids['Pilates'] = await a.writer.createHabit(
      every('Pilates', 'daily', 1800, const {}),
      type: 'duration',
    );
    _check((await a.outbox()).length == 5, 'five creates queued offline');
    await a.sync();
    _check((await a.outbox()).isEmpty, 'every ack accepted (nothing left in the outbox)');
    await b.sync();
    final shownA = {for (final h in await LocalView(a.db).habits()) h.id: h.payload};
    final pulledB = {
      for (final h in await b.db.select(b.db.habits).get()) h.id: EntityCodec.habitPayload(h),
    };
    for (final MapEntry(key: name, value: id) in ids.entries) {
      final shown = shownA[id]!;
      final pulled = pulledB[id]!;
      _check(
        jsonEncode(pulled['frequency_config']) == jsonEncode(shown['frequency_config']) &&
            pulled['frequency_type'] == shown['frequency_type'],
        '$name: B pulled ${pulled['frequency_type']} ${jsonEncode(pulled['frequency_config'])}, '
        'A shows ${shown['frequency_type']} ${jsonEncode(shown['frequency_config'])}',
      );
    }
    _check(
      jsonEncode(pulledB[ids['Gym']]!['frequency_config']) == '{"days":[1,3,5]}',
      'weekdays sorted: ${jsonEncode(pulledB[ids['Gym']]!['frequency_config'])}',
    );
    _check(pulledB[ids['Pilates']]!['target_value'] == 1800, '30 minutes is 1800 seconds');
  });

  Future<OutboxRow> attention(_Device d) async =>
      (await d.outbox()).singleWhere((r) => r.state == OutboxState.needsAttention);
  Future<Object?> valueOn(_Device d, String id) async {
    final log = await d.log(id, today);
    return log.deletedAt == null ? jsonDecode(log.value!) : null;
  }

  late String cups;
  await _scenario('log-increment', () async {
    cups = await water(a);
    await a.sync();
    await b.sync();
    await a.writer.incrementLog(habitId: cups, delta: '250');
    await a.writer.incrementLog(habitId: cups, delta: '0.5');
    await b.writer.incrementLog(habitId: cups, delta: '500');
    _check((await a.outbox()).length == 1, 'A folded its two additions into one row');
    await a.sync();
    await b.sync();
    await a.sync();
    final onA = await valueOn(a, cups);
    final onB = await valueOn(b, cups);
    _check(onA == '750.500' && onB == '750.500', 'the sum on both devices ($onA, $onB)');
    _check((await a.outbox()).isEmpty && (await b.outbox()).isEmpty, 'nothing needs a look');
  });

  await _scenario('log-conflict', () async {
    await a.writer.setLogValue(habitId: cups, value: '1100.000');
    await a.sync();
    await b.writer.setLogValue(habitId: cups, value: '1200.000');
    await b.sync();
    final stale = await attention(b);
    _check(jsonDecode(stale.lastError!)['code'] == 'version_conflict', 'B is stale');
    _check(await b.writer.keepSynced(stale.mutationId) == ResolveResult.done, 'kept synced');
    await b.sync();
    _check(await valueOn(b, cups) == '1100.000', "B shows the server's value");

    final before = (await b.log(cups, today)).version;
    await b.writer.setLogValue(habitId: cups, value: '1400.000');
    await b.sync();
    await a.writer.setLogValue(habitId: cups, value: '1500.000');
    await a.sync();
    final mine = await attention(a);
    final view = (await LocalView(a.db).conflict(mine.mutationId))!;
    _check(
      view.canUseMine && view.serverValue == '1400.000',
      "A sees B's value and may use its own",
    );
    _check(await a.writer.useMine(mine.mutationId) == ResolveResult.done, 'used mine');
    await a.sync();
    await b.sync();
    final onA = await valueOn(a, cups);
    final onB = await valueOn(b, cups);
    final version = (await b.log(cups, today)).version;
    _check(onA == '1500.000' && onB == '1500.000', "both converge on A's value ($onA, $onB)");
    _check(version > before + 1, 'a higher version ($before -> $version)');
  });

  await _scenario('log-deleted', () async {
    await a.writer.deleteLog(habitId: cups, date: today);
    await a.sync();
    await b.writer.incrementLog(habitId: cups, delta: '100');
    await b.sync();
    final kept = await attention(b);
    final error = jsonDecode(kept.lastError!) as Map;
    _check(error['code'] == 'resource_deleted', 'resource_deleted (${error['code']})');
    _check((error['current'] as Map?)?['deleted_at'] != null, 'current is the tombstone');
    _check(await b.writer.useMine(kept.mutationId) == ResolveResult.done, 'used mine');
    await b.sync();
    await a.sync();
    final onA = await valueOn(a, cups);
    final onB = await valueOn(b, cups);
    _check(onA == '100.000' && onB == '100.000', "the day is back with B's amount ($onA, $onB)");
  });

  await _scenario('completion', () async {
    // A46: the engine's AckWatch carries the server's xp_delta for each log mutation.
    final jug = await water(a);
    await a.sync();
    await b.sync();
    Future<int> xpOnB() async {
      await b.sync();
      return (await b.db.select(b.db.rewardState).getSingle()).xp ?? 0;
    }

    final before = await xpOnB();
    Future<int?> deltaOf(Future<LocalWrite> writing) async {
      final write = await writing;
      await a.sync();
      final summary = a.engine.ackWatch.known(write.mutationId);
      _check(summary?.status == 'accepted', 'accepted (${summary?.status})');
      return summary!.xpDelta;
    }

    final completed = await deltaOf(a.writer.incrementLog(habitId: jug, delta: '2000'));
    _check(completed == 10, 'completing yields xp_delta 10 ($completed)');
    final onB = await xpOnB();
    _check(onB == before + 10, 'B holds reward_state with 10 more XP ($before -> $onB)');
    final more = await deltaOf(a.writer.incrementLog(habitId: jug, delta: '250'));
    _check(more == null, 'a further increment on a complete day yields none ($more)');
    final below = await deltaOf(a.writer.setLogValue(habitId: jug, value: '500.000'));
    _check(below == -10, 'below the target yields -10 ($below)');
    final again = await deltaOf(a.writer.setLogValue(habitId: jug, value: '2000.000'));
    _check(again == 10, 'completing again yields +10 ($again)');
    _check(await xpOnB() == before + 10, 'B nets +10 overall');
  });

  await _scenario('insights', () async {
    // A47: GET /insights reflects a synced backdated completion; a not-due check-in raises
    // xp_earned (the ledger) but never the totals. Monday has no closed day in its week, so
    // the month is used then.
    final period = today.isoWeekday == 1 ? 'month' : 'week';
    Future<Map<String, dynamic>> insights() async =>
        ((await a.dio.get<Map<String, dynamic>>(
                  '/insights',
                  queryParameters: {'period': period},
                )).data!['data']
                as Map)
            .cast<String, dynamic>();
    final yesterday = today.addDays(-1);
    _check((await insights())['window']['through'] == yesterday.toString(), 'yesterday is closed');

    final daily = await a.writer.createHabitUnchecked(
      name: 'Insight daily',
      type: 'binary',
      target: 1,
      category: 'learning',
      startLocalDate: yesterday,
      backdate: true,
    );
    await a.sync();
    final before = await insights();
    await a.writer.setLogValue(habitId: daily, value: 1, logDate: yesterday);
    await a.sync();
    final after = await insights();
    int totals(Map<String, dynamic> i, String k) => (i['totals'] as Map)[k] as int;
    _check(
      totals(after, 'completed') == totals(before, 'completed') + 1,
      'the completion counts (${before['totals']} -> ${after['totals']})',
    );
    _check(after['xp_earned'] == (before['xp_earned'] as int) + 10, 'and earns 10 XP');

    // Due only on tomorrow's weekday, so yesterday and today are not due.
    final rare = await a.writer.createHabitUnchecked(
      name: 'Insight rare',
      type: 'binary',
      target: 1,
      category: 'learning',
      frequencyType: 'weekdays',
      frequencyConfig: {
        'days': [today.addDays(1).isoWeekday],
      },
      startLocalDate: yesterday,
      backdate: true,
    );
    await a.sync();
    final beforeRare = await insights();
    await a.writer.setLogValue(habitId: rare, value: 1, logDate: yesterday);
    await a.sync();
    final afterRare = await insights();
    _check(
      afterRare['xp_earned'] == (beforeRare['xp_earned'] as int) + 10,
      'a not-due check-in raises xp_earned',
    );
    _check(
      afterRare['totals'].toString() == beforeRare['totals'].toString(),
      'but not the totals (${beforeRare['totals']} -> ${afterRare['totals']})',
    );
  });

  await _scenario('timer-draft', () async {
    final yoga = await a.writer.createHabitUnchecked(
      name: 'Yoga',
      type: 'duration',
      target: 900,
      category: 'health',
      startLocalDate: today,
    );
    await a.sync();
    await b.sync();
    // Real time, replayed: started 3 minutes ago, paused for a minute, finished now.
    final t0 = DateTime.now().toUtc();
    var clock = t0.subtract(const Duration(minutes: 3));
    final timer = LocalMutationService(a.db, clock: () => clock);
    await timer.startTimer(yoga);
    clock = t0.subtract(const Duration(minutes: 1, seconds: 59, milliseconds: 500));
    await timer.pauseTimer(yoga);
    clock = t0.subtract(const Duration(minutes: 1));
    await timer.resumeTimer(yoga);
    clock = t0;
    await timer.finishTimer(yoga);
    final queued = (await a.outbox()).single;
    _check(queued.operation == 'log.increment', 'one increment (${queued.operation})');
    _check(jsonDecode(queued.payload)['delta'] == 120, 'whole seconds: 60.5 s + 60 s = 120 s');
    _check(await a.db.select(a.db.timerDrafts).get().then((d) => d.isEmpty), 'the draft is gone');
    await a.sync();
    await b.sync();
    final onA = await valueOn(a, yoga);
    final onB = await valueOn(b, yoga);
    _check(onA == 120 && onB == 120, 'both devices agree ($onA, $onB)');
  });

  await _scenario('export', () async {
    final key = Platform.environment['E2E_EXPORT_KEY'] ?? '';
    final colon = key.indexOf(':');
    if (colon < 1) {
      throw StateError('E2E_EXPORT_KEY (kid:secret) is required for the export scenario');
    }
    final (kid, secret) = (key.substring(0, colon), key.substring(colon + 1));
    await a.sync();

    Future<List<int>> export(String format) async {
      final job =
          (await a.dio.post<Map<String, dynamic>>(
                '/exports',
                data: {'format': format},
              )).data!['data']
              as Map;
      _check(job['status'] == 'queued', '$format: queued (${job['status']})');
      await _runCommand('E2E_QUEUE_CMD', 'queue');
      final ready =
          (await a.dio.get<Map<String, dynamic>>('/exports/${job['id']}')).data!['data'] as Map;
      _check(ready['status'] == 'ready', '$format: ready (${ready['status']})');
      return (await a.dio.get<List<int>>(
        ready['download_url'] as String,
        options: Options(responseType: ResponseType.bytes),
      )).data!;
    }

    final files = _unzip(await export('json'));
    final manifest = (jsonDecode(utf8.decode(files['manifest.json']!)) as Map)
        .cast<String, dynamic>();
    _check(manifest['kid'] == kid, 'signed under $kid (${manifest['kid']})');
    final signed = Map.of(manifest)..remove('signature');
    final expected = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(jsonEncode(_canonical(signed)))).toString();
    _check(manifest['signature'] == expected, 'the manifest signature verifies');
    final listed = (manifest['files'] as List).cast<Map<String, dynamic>>();
    for (final f in listed) {
      _check(
        sha256.convert(files[f['name']]!).toString() == f['sha256'],
        '${f['name']} matches its hash',
      );
    }
    _check(
      files.keys.toSet().difference({'manifest.json'}).length == listed.length,
      'every file is listed (${files.keys})',
    );
    final user = (await a.db.select(a.db.syncState).getSingle()).userId;
    _check(manifest['user_id'] == user, 'the manifest binds A');
    final doc = jsonDecode(utf8.decode(files['export.json']!)) as Map;
    final habits = await a.db.select(a.db.habits).get();
    final logs = await (a.db.select(a.db.habitLogs)..where((l) => l.deletedAt.isNull())).get();
    _check(
      (doc['habits'] as List).length == habits.length,
      'habits: ${(doc['habits'] as List).length} exported, ${habits.length} on A',
    );
    _check(
      (doc['logs'] as List).length == logs.length,
      'logs: ${(doc['logs'] as List).length} exported, ${logs.length} on A',
    );

    const formula = '=SUM(A1), now';
    final named = await a.writer.createHabitUnchecked(
      name: formula,
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: today,
    );
    await a.writer.setLogValue(habitId: named, value: 1);
    await a.sync();
    final csv = utf8.decode(await export('csv'));
    _check(csv.contains(',"\'$formula",'), 'the = name comes back quoted and neutralised');
    _check(!csv.contains(',$formula'), 'and never bare');
  });

  await _scenario('delete-account', () async {
    final email = 'e2e-delete+${DateTime.now().millisecondsSinceEpoch}@example.test';
    const password = 'e2e-delete-password-1234';
    final register = {
      'name': 'E2E Delete',
      'email': email,
      'password': password,
      'timezone': 'America/Los_Angeles',
      'terms_version': '2026-10-24',
      'privacy_version': '2026-10-24',
    };
    final c1 = await _Device.signIn(baseUrl, dir, 'C1', '/auth/register', register);
    final c2 = await _Device.signIn(baseUrl, dir, 'C2', '/auth/login', {
      'email': email,
      'password': password,
    });
    await c1.writer.createHabitUnchecked(
      name: 'Walk',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: await c1.today(),
    );
    await c1.sync();
    await c2.sync();

    final wrong = await c1.dio.delete<Object?>(
      '/me',
      data: {'password': 'not the password'},
      options: Options(validateStatus: (_) => true),
    );
    _check(wrong.statusCode == 422, 'a wrong password is 422 (${wrong.statusCode})');
    final accepted = (await c1.dio.delete<Map<String, dynamic>>(
      '/me',
      data: {'password': password},
    ));
    _check(accepted.statusCode == 202, '202 (${accepted.statusCode})');
    final data = accepted.data!['data'] as Map;
    final receipt = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${data['receipt_token']}'},
      ),
    );
    Future<String?> status() async =>
        ((await receipt.get<Map<String, dynamic>>('/account-deletions/${data['id']}')).data!['data']
                as Map)['status']
            as String?;

    final outcome = await c2.engine.run(force: true);
    _check(outcome == SyncOutcome.loggedOut, "C2's next sync is logged out (${outcome.name})");
    _check(await status() == 'queued', 'the receipt reads queued');
    await _runCommand('E2E_QUEUE_CMD', 'queue');
    _check(await status() == 'completed', 'the receipt reads completed after one purge run');

    final anon = Dio(BaseOptions(baseUrl: baseUrl, headers: {'Accept': 'application/json'}));
    final login = await anon.post<Object?>(
      '/auth/login',
      data: {'email': email, 'password': password, 'device_name': 'e2e'},
      options: Options(validateStatus: (_) => true),
    );
    _check(login.statusCode == 422, 'the old credentials fail like a wrong password');
    final again = await anon.post<Object?>(
      '/auth/register',
      data: {...register, 'device_name': 'e2e'},
      options: Options(validateStatus: (_) => true),
    );
    _check(again.statusCode == 201, 'the email registers again (${again.statusCode})');
    await c1.db.close();
    await c2.db.close();
  });

  await _scenario('password-reset', () async {
    final logPath = Platform.environment['E2E_MAIL_LOG'];
    if (logPath == null || logPath.isEmpty) throw StateError('E2E_MAIL_LOG is required');
    // The API creates the file on its first log line, which may be this mail.
    final mailLog = File(logPath);
    final email = 'e2e-reset+${DateTime.now().millisecondsSinceEpoch}@example.test';
    const oldPassword = 'e2e-reset-password-1234';
    const newPassword = 'e2e-reset-new-password-5678';
    final d1 = await _Device.signIn(baseUrl, dir, 'D1', '/auth/register', {
      'name': 'E2E Reset',
      'email': email,
      'password': oldPassword,
      'timezone': 'America/Los_Angeles',
      'terms_version': '2026-10-24',
      'privacy_version': '2026-10-24',
    });
    final d2 = await _Device.signIn(baseUrl, dir, 'D2', '/auth/login', {
      'email': email,
      'password': oldPassword,
    });
    await d1.sync();
    await d2.sync();

    final anon = Dio(BaseOptions(baseUrl: baseUrl, headers: {'Accept': 'application/json'}));
    final before = mailLog.existsSync() ? mailLog.lengthSync() : 0;
    final asked = await anon.post<Object?>('/auth/forgot-password', data: {'email': email});
    _check(asked.statusCode == 202, 'forgot-password is 202 (${asked.statusCode})');
    // The mail is written after the response; give it a moment.
    String? code;
    for (var i = 0; i < 50 && code == null; i++) {
      if (!mailLog.existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      final raf = mailLog.openSync()..setPositionSync(before);
      final added = utf8.decode(raf.readSync(mailLog.lengthSync() - before), allowMalformed: true);
      raf.closeSync();
      code = RegExp(r'Your password reset code is: (\d{6})').allMatches(added).lastOrNull?.group(1);
      if (code == null) await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _check(code != null, 'the code reached the log mailer');

    Future<Response<Object?>> resetWith(String token) => anon.post<Object?>(
      '/auth/reset-password',
      data: {
        'email': email,
        'reset_token': token,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
      options: Options(validateStatus: (_) => true),
    );
    final wrong = await resetWith(code == '000000' ? '000001' : '000000');
    _check(wrong.statusCode == 422, 'a wrong code is 422 (${wrong.statusCode})');
    final done = await resetWith(code!);
    _check(done.statusCode == 204, 'the right code resets (${done.statusCode})');

    final me = await d1.dio.get<Object?>('/me', options: Options(validateStatus: (_) => true));
    _check(me.statusCode == 401, "D1's old token gets 401 on /me (${me.statusCode})");
    final outcome = await d2.engine.run(force: true);
    _check(outcome == SyncOutcome.loggedOut, "D2's next sync is logged out (${outcome.name})");
    final login = await anon.post<Object?>(
      '/auth/login',
      data: {'email': email, 'password': newPassword, 'device_name': 'e2e'},
      options: Options(validateStatus: (_) => true),
    );
    _check(login.statusCode == 200, 'the new password signs in (${login.statusCode})');
    await d1.db.close();
    await d2.db.close();
  });

  await _scenario('habit-delete', () async {
    final email = 'e2e-habit-delete+${DateTime.now().millisecondsSinceEpoch}@example.test';
    const password = 'e2e-habit-delete-1234';
    final e1 = await _Device.signIn(baseUrl, dir, 'E1', '/auth/register', {
      'name': 'E2E Habit Delete',
      'email': email,
      'password': password,
      'timezone': 'America/Los_Angeles',
      'terms_version': '2026-10-25',
      'privacy_version': '2026-10-25',
    });
    final e2 = await _Device.signIn(baseUrl, dir, 'E2', '/auth/login', {
      'email': email,
      'password': password,
    });
    await e1.sync();
    final today = await e1.today();
    final juice = await e1.writer.createHabitUnchecked(
      name: 'Juice',
      type: 'quantity',
      target: '500.000',
      unit: 'ml',
      category: 'health',
      startLocalDate: today.addDays(-2),
      backdate: true,
    );
    await e1.writer.setLogValue(habitId: juice, value: '500.000', logDate: today.addDays(-1));
    await e1.writer.setLogValue(habitId: juice, value: '500.000');
    await e1.sync();
    await e2.sync();
    Future<int> xp(_Device d) async => (await d.db.select(d.db.rewardState).getSingle()).xp ?? 0;
    final earned = await xp(e1);
    _check(earned > 0, 'the check-ins earned XP ($earned)');
    _check(await xp(e2) == earned, 'E2 holds the same XP');
    await e2.writer.incrementLog(habitId: juice, delta: '100');

    await e1.writer.deleteHabit(juice);
    await e1.sync();
    await e2.sync();
    await e1.sync();

    for (final d in [e1, e2]) {
      final habits = await (d.db.select(d.db.habits)..where((h) => h.id.equals(juice))).get();
      final logs = await (d.db.select(d.db.habitLogs)..where((l) => l.habitId.equals(juice))).get();
      _check(habits.isEmpty && logs.isEmpty, '${d.name} has no habit and no check-ins');
      _check(await xp(d) == earned, '${d.name} keeps its XP (${await xp(d)})');
    }
    final kept = (await e2.outbox()).single;
    final error = jsonDecode(kept.lastError!) as Map;
    _check(
      kept.state == OutboxState.needsAttention &&
          error['code'] == 'resource_deleted' &&
          error['entity'] == 'habit',
      "E2's increment waits as deleted on another device (${kept.state} ${error['code']})",
    );
    _check(await e1.outbox().then((o) => o.isEmpty), "E1's delete is acknowledged");
    await e1.db.close();
    await e2.db.close();
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
Future<void> _closePeriods() => _runCommand('E2E_CLOSE_CMD', 'closer');

/// Runs the command line in [variable] once.
Future<void> _runCommand(String variable, String label) async {
  final command = Platform.environment[variable];
  if (command == null || command.isEmpty) throw StateError('$variable is required');
  // One command line, run by the platform shell (a single executable name otherwise).
  final result = Platform.isWindows
      ? await Process.run('cmd', ['/c', command])
      : await Process.run('/bin/sh', ['-c', command]);
  if (result.exitCode != 0) throw StateError('$label failed: ${result.stderr}');
  _say('  $label: ${'${result.stdout}'.trim()}');
}

/// A16: keys sorted at every depth; with jsonEncode (slashes and non-ASCII unescaped), the
/// bytes the server signs.
Object? _canonical(Object? value) => switch (value) {
  Map() => {for (final k in value.keys.cast<String>().toList()..sort()) k: _canonical(value[k])},
  List() => value.map(_canonical).toList(),
  _ => value,
};

/// The entries of a zip (stored or deflated), read through its central directory.
Map<String, List<int>> _unzip(List<int> zip) {
  final bytes = Uint8List.fromList(zip);
  final b = ByteData.sublistView(bytes);
  int u16(int at) => b.getUint16(at, Endian.little);
  int u32(int at) => b.getUint32(at, Endian.little);
  var end = bytes.length - 22;
  while (u32(end) != 0x06054b50) {
    end--;
  }
  var at = u32(end + 16);
  final entries = <String, List<int>>{};
  for (var i = 0; i < u16(end + 10); i++) {
    final nameLength = u16(at + 28);
    final local = u32(at + 42);
    final start = local + 30 + u16(local + 26) + u16(local + 28);
    final data = bytes.sublist(start, start + u32(at + 20));
    entries[utf8.decode(bytes.sublist(at + 46, at + 46 + nameLength))] = u16(at + 10) == 8
        ? ZLibDecoder(raw: true).convert(data)
        : data;
    at += 46 + nameLength + u16(at + 30) + u16(at + 32);
  }
  return entries;
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
    var outcome = await engine.run(force: true);
    // One account, two devices and many scenarios share the API's per-user sync limit (60 a
    // minute by default, as in CI): a 429 waits out its Retry-After and runs again.
    for (var attempt = 0; outcome == SyncOutcome.rateLimited && attempt < 3; attempt++) {
      final until = (await (db.select(db.syncState)).getSingle()).backoffUntil;
      final wait = until == null
          ? const Duration(seconds: 30)
          : Duration(milliseconds: until - DateTime.now().millisecondsSinceEpoch);
      _say('  $name sync: rate limited, waiting ${wait.inSeconds} s');
      await Future<void>.delayed(wait.isNegative ? Duration.zero : wait);
      outcome = await engine.run(force: true);
    }
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
