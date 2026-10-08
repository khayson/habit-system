import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:path/path.dart' as p;

/// Upgrades keep every queued row and add the new columns with their defaults.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('habit_migration_');
    file = File(p.join(dir.path, 'account.sqlite'));
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold the file briefly; the OS cleans temp.
    }
  });

  test(
    'v4 -> v5 adds the calendar, typed A32 tables and settings; opaque rows become typed',
    () async {
      final v5 = AppDatabase(NativeDatabase(file));
      await v5.customStatement(
        "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:7')",
      );
      await v5.customStatement(
        'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
        "state, created_at) VALUES ('m1', 'habit', 'h1', 'habit.create', '2026-05-28T00:00:00Z', "
        "'{}', 'pending', 0)",
      );
      Future<void> opaque(String type, String id, int version, String payload) =>
          v5.customStatement(
            'INSERT INTO opaque_entities (entity_type, entity_id, version, operation, payload) '
            "VALUES ('$type', '$id', $version, 'upsert', '$payload')",
          );
      await opaque(
        'habit_progress',
        'h1',
        3,
        '{"habit_id":"h1","current":2,"longest":5,"unit":"days","computed_through":"2026-05-27","colour":"teal"}',
      );
      await opaque(
        'period_evaluation',
        'e1',
        2,
        '{"id":"e1","habit_id":"h1","period_key":"d:2026-05-27","start_date":"2026-05-27",'
            '"end_date":"2026-05-27","completed":true,"protected":false,"definition_version":1,'
            '"timezone":"America/Los_Angeles","revision":2}',
      );
      await opaque('habit_progress', 'h-bad', 1, '{"habit_id":"h-bad","current":"two"}');
      await opaque('weekly_review', 'w1', 1, '{"id":"w1"}');
      for (final table in [
        'calendar_entries',
        'habit_progress',
        'period_evaluations',
        'local_settings',
      ]) {
        await v5.customStatement('DROP TABLE $table');
      }
      await v5.customStatement('PRAGMA user_version = 4');
      await v5.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      expect((await upgraded.select(upgraded.outbox).get()).single.mutationId, 'm1');
      expect((await upgraded.select(upgraded.syncState).getSingle()).cursor, 'c:7');
      final progress = await upgraded.select(upgraded.habitProgress).getSingle();
      expect(
        (progress.habitId, progress.current, progress.longest, progress.version),
        ('h1', 2, 5, 3),
      );
      expect(
        EntityCodec.progressPayload(progress)['colour'],
        'teal',
        reason: 'unknown fields kept',
      );
      final evaluation = await upgraded.select(upgraded.periodEvaluations).getSingle();
      expect(
        (evaluation.periodKey, evaluation.completed, evaluation.revision),
        ('d:2026-05-27', true, 2),
      );
      final left = await upgraded.select(upgraded.opaqueEntities).get();
      expect(left.map((o) => '${o.entityType}/${o.entityId}').toSet(), {
        'habit_progress/h-bad',
        'weekly_review/w1',
      });
      await upgraded.close();
    },
  );

  test('v3 -> v4 adds the app version and keeps everything else', () async {
    final v4 = AppDatabase(NativeDatabase(file));
    await v4.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:7')",
    );
    await v4.customStatement('ALTER TABLE sync_state DROP COLUMN app_version');
    for (final table in [
      'calendar_entries',
      'habit_progress',
      'period_evaluations',
      'local_settings',
    ]) {
      await v4.customStatement('DROP TABLE $table');
    }
    await v4.customStatement('PRAGMA user_version = 3');
    await v4.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final state = await upgraded.select(upgraded.syncState).getSingle();
    expect((state.cursor, state.appVersion), ('c:7', null));
    await upgraded.close();
  });

  test('v2 -> v3 adds sync health columns and the discard record, keeping the outbox', () async {
    // Build a v2 file: today's schema minus what v3 added.
    final v3 = AppDatabase(NativeDatabase(file));
    await v3.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:7')",
    );
    await v3.customStatement(
      'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
      "state, created_at) VALUES ('m1', 'habit', 'h1', 'habit.create', '2026-05-28T00:00:00Z', "
      "'{}', 'pending', 0)",
    );
    for (final column in [
      'app_version',
      'consecutive_failures',
      'backoff_until',
      'request_rejections',
      'status',
      'status_code',
      'last_error',
      'clock_skew_ms',
    ]) {
      await v3.customStatement('ALTER TABLE sync_state DROP COLUMN $column');
    }
    await v3.customStatement('DROP TABLE discarded_mutations');
    for (final table in [
      'calendar_entries',
      'habit_progress',
      'period_evaluations',
      'local_settings',
    ]) {
      await v3.customStatement('DROP TABLE $table');
    }
    await v3.customStatement('PRAGMA user_version = 2');
    await v3.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final state = await upgraded.select(upgraded.syncState).getSingle();
    expect(
      (state.cursor, state.status, state.consecutiveFailures, state.clockSkewMs),
      ('c:7', 'active', 0, 0),
    );
    expect((await upgraded.select(upgraded.outbox).get()).single.mutationId, 'm1');
    expect(await upgraded.select(upgraded.discardedMutations).get(), isEmpty);
    await upgraded.close();
  });
}
