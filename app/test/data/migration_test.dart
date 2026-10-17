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
    'v9 -> v10 types reward_state and lifts protected_in_streak; outbox and data survive',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      await dropV10(current);
      await current.customStatement('PRAGMA user_version = 9');
      await current.customStatement(
        'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
        "state, created_at) VALUES ('m1', 'habit_log', 'l1', 'log.set_value', "
        "'2026-05-28T00:00:00Z', '{}', 'pending', 0)",
      );
      await current.customStatement(
        "INSERT INTO habits (id, name, version) VALUES ('h1', 'Water', 2)",
      );
      await current.customStatement(
        'INSERT INTO habit_progress (habit_id, current, longest, unit, computed_through, '
        "version, extra) VALUES ('h1', 4, 6, 'days', '2026-05-27', 3, "
        "'{\"protected_in_streak\":1,\"colour\":\"teal\"}')",
      );
      await current.customStatement(
        'INSERT INTO opaque_entities (entity_type, entity_id, version, operation, payload) '
        "VALUES ('reward_state', 'u1', 5, 'upsert', "
        "'{\"xp\":10,\"level\":1,\"progress_into_level\":10,\"next_level_threshold\":100,\"freeze_balance\":2}')",
      );
      await current.customStatement(
        'INSERT INTO opaque_entities (entity_type, entity_id, version, operation, payload) '
        "VALUES ('weekly_review', 'w1', 1, 'upsert', '{}')",
      );
      await current.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final rewards = await upgraded.select(upgraded.rewardState).getSingle();
      expect((rewards.id, rewards.xp, rewards.freezeBalance, rewards.version), ('u1', 10, 2, 5));
      final progress = await upgraded.select(upgraded.habitProgress).getSingle();
      expect((progress.current, progress.protectedInStreak), (4, 1));
      expect(EntityCodec.progressPayload(progress)['colour'], 'teal');
      expect(progress.extra.contains('protected_in_streak'), isFalse);
      final opaque = await upgraded.select(upgraded.opaqueEntities).get();
      expect(opaque.map((o) => o.entityType), ['weekly_review'], reason: 'the rest stays');
      expect((await upgraded.select(upgraded.outbox).getSingle()).operation, 'log.set_value');
      expect((await upgraded.select(upgraded.habits).getSingle()).version, 2);
      await upgraded.close();
    },
  );

  test('v9 -> v10 keeps a non-integer protected_in_streak in extra and an undecodable '
      'reward_state opaque', () async {
    final current = AppDatabase(NativeDatabase(file));
    await dropV10(current);
    await current.customStatement('PRAGMA user_version = 9');
    await current.customStatement(
      'INSERT INTO habit_progress (habit_id, current, version, extra) '
      "VALUES ('h1', 4, 3, '{\"protected_in_streak\":\"one\"}')",
    );
    await current.customStatement(
      'INSERT INTO opaque_entities (entity_type, entity_id, version, operation, payload) '
      "VALUES ('reward_state', 'u1', 5, 'upsert', '{\"xp\":\"ten\",\"level\":1}')",
    );
    await current.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final progress = await upgraded.select(upgraded.habitProgress).getSingle();
    expect(progress.protectedInStreak, isNull);
    expect(EntityCodec.progressPayload(progress)['protected_in_streak'], isNull);
    expect(progress.extra, '{"protected_in_streak":"one"}');
    expect(await upgraded.select(upgraded.rewardState).get(), isEmpty);
    final opaque = await upgraded.select(upgraded.opaqueEntities).getSingle();
    expect((opaque.entityType, opaque.entityId, opaque.version), ('reward_state', 'u1', 5));
    await upgraded.close();
  });

  test('v8 -> v9 adds timer drafts; outbox, scheduled rows and the cursor survive', () async {
    final v9 = AppDatabase(NativeDatabase(file));
    await v9.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:12')",
    );
    await v9.customStatement(
      'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
      "state, created_at) VALUES ('m1', 'habit_log', 'l1', 'log.increment', "
      "'2026-05-28T00:00:00Z', '{}', 'pending', 0)",
    );
    await v9.customStatement(
      'INSERT INTO scheduled_notifications (platform_id, reminder_id, habit_id, slot_date, '
      "fire_at, content_key) VALUES (7, 'r1', 'h1', '2026-05-29', 1780000000000, 'k')",
    );
    await dropV9(v9);
    await v9.customStatement('PRAGMA user_version = 8');
    await v9.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    expect(await upgraded.select(upgraded.timerDrafts).get(), isEmpty);
    await upgraded
        .into(upgraded.timerDrafts)
        .insert(
          TimerDraftsCompanion.insert(
            habitId: 'h1',
            state: 'paused',
            elapsedMs: 5000,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    expect((await upgraded.select(upgraded.timerDrafts).getSingle()).elapsedMs, 5000);
    expect((await upgraded.select(upgraded.outbox).getSingle()).operation, 'log.increment');
    expect((await upgraded.select(upgraded.scheduledNotifications).getSingle()).contentKey, 'k');
    expect((await upgraded.select(upgraded.syncState).getSingle()).cursor, 'c:12');
    await upgraded.close();
  });

  test(
    'v7 -> v8 adds the notification text key; scheduled rows, outbox and data survive',
    () async {
      final v8 = AppDatabase(NativeDatabase(file));
      await v8.customStatement(
        "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:12')",
      );
      await v8.customStatement(
        'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
        "state, created_at) VALUES ('m1', 'habit', 'h1', 'habit.archive', "
        "'2026-05-28T00:00:00Z', '{}', 'pending', 0)",
      );
      await v8.customStatement(
        'INSERT INTO scheduled_notifications (platform_id, reminder_id, habit_id, slot_date, fire_at) '
        "VALUES (7, 'r1', 'h1', '2026-05-29', 1780000000000)",
      );
      await dropV8(v8);
      await v8.customStatement('PRAGMA user_version = 7');
      await v8.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final row = await upgraded.select(upgraded.scheduledNotifications).getSingle();
      expect((row.platformId, row.fireAt, row.contentKey), (7, 1780000000000, null));
      expect((await upgraded.select(upgraded.outbox).getSingle()).operation, 'habit.archive');
      expect((await upgraded.select(upgraded.syncState).getSingle()).cursor, 'c:12');
      await upgraded.close();
    },
  );

  test('v6 -> v7 adds the photo pointer and the upload queue; outbox and data survive', () async {
    final v7 = AppDatabase(NativeDatabase(file));
    await v7.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor, user_payload) "
      "VALUES (1, 'u', 'd', 'c:11', '{\"id\":\"u\",\"name\":\"Maya\",\"version\":4}')",
    );
    await v7.customStatement(
      'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
      "state, created_at) VALUES ('m1', 'user', 'u', 'profile.set_timezone', "
      "'2026-05-28T00:00:00Z', '{\"timezone\":\"Africa/Accra\"}', 'pending', 0)",
    );
    await v7.customStatement(
      "INSERT INTO reminders (id, habit_id, local_time, days_of_week, version) "
      "VALUES ('r1', 'h1', '08:00', '[1]', 2)",
    );
    await dropV7(v7);
    await v7.customStatement('PRAGMA user_version = 6');
    await v7.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final state = await upgraded.select(upgraded.syncState).getSingle();
    expect((state.cursor, state.avatarFile, state.avatarFileVersion), ('c:11', null, null));
    expect(state.userPayload, contains('"name":"Maya"'));
    final row = await upgraded.select(upgraded.outbox).getSingle();
    expect((row.mutationId, row.operation, row.state), ('m1', 'profile.set_timezone', 'pending'));
    expect((await upgraded.select(upgraded.reminders).getSingle()).id, 'r1');
    expect(await upgraded.select(upgraded.pendingUploads).get(), isEmpty);
    await upgraded.close();
  });

  test('v5 -> v6 adds reminders and the schedule record; opaque reminders become typed', () async {
    final v6 = AppDatabase(NativeDatabase(file));
    await v6.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:9')",
    );
    await v6.customStatement(
      'INSERT INTO outbox (mutation_id, entity, entity_id, operation, occurred_at, payload, '
      "state, created_at) VALUES ('m1', 'habit_log', 'l1', 'log.set_value', "
      "'2026-05-28T00:00:00Z', '{\"value\":1}', 'pending', 0)",
    );
    await v6.customStatement(
      "INSERT INTO habit_progress (habit_id, \"current\", longest, version) VALUES ('h1', 2, 5, 3)",
    );
    Future<void> opaque(String id, int version, String payload) => v6.customStatement(
      'INSERT INTO opaque_entities (entity_type, entity_id, version, operation, payload) '
      "VALUES ('reminder', '$id', $version, 'upsert', '$payload')",
    );
    await opaque(
      'r1',
      2,
      '{"id":"r1","habit_id":"h1","local_time":"08:00","days_of_week":[1,3,5],'
          '"timezone_mode":"habit_zone","timezone":null,"enabled":true,"version":2,'
          '"deleted_at":null,"snooze":10}',
    );
    await opaque('r-bad', 1, '{"id":"r-bad","days_of_week":"weekdays"}');
    await dropV7(v6);
    for (final table in ['reminders', 'scheduled_notifications']) {
      await v6.customStatement('DROP TABLE $table');
    }
    await v6.customStatement('PRAGMA user_version = 5');
    await v6.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    expect((await upgraded.select(upgraded.outbox).getSingle()).mutationId, 'm1');
    expect((await upgraded.select(upgraded.syncState).getSingle()).cursor, 'c:9');
    expect((await upgraded.select(upgraded.habitProgress).getSingle()).current, 2);
    final reminder = await upgraded.select(upgraded.reminders).getSingle();
    expect(
      (reminder.id, reminder.localTime, reminder.daysOfWeek, reminder.version),
      ('r1', '08:00', '[1,3,5]', 2),
    );
    expect(EntityCodec.reminderPayload(reminder)['snooze'], 10, reason: 'unknown fields kept');
    final left = await upgraded.select(upgraded.opaqueEntities).get();
    expect(left.map((o) => o.entityId), ['r-bad'], reason: 'what does not decode stays opaque');
    expect(await upgraded.select(upgraded.scheduledNotifications).get(), isEmpty);
    await upgraded.close();
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
      await dropV7(v5);
      for (final table in [
        'calendar_entries',
        'habit_progress',
        'period_evaluations',
        'local_settings',
        'reminders',
        'scheduled_notifications',
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
    await dropV7(v4);
    for (final table in [
      'calendar_entries',
      'habit_progress',
      'period_evaluations',
      'local_settings',
      'reminders',
      'scheduled_notifications',
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
    await dropV7(v3);
    for (final table in [
      'calendar_entries',
      'habit_progress',
      'period_evaluations',
      'local_settings',
      'reminders',
      'scheduled_notifications',
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

/// Takes a current database back to v9: drops what v10 added.
Future<void> dropV10(AppDatabase db) async {
  await db.customStatement('DROP TABLE reward_state');
  await db.customStatement('ALTER TABLE habit_progress DROP COLUMN protected_in_streak');
}

/// Takes a current database back to v8: drops what v9 and v10 added.
Future<void> dropV9(AppDatabase db) async {
  await dropV10(db);
  await db.customStatement('DROP TABLE timer_drafts');
}

/// Takes a current database back to v7: drops what v8 and v9 added.
Future<void> dropV8(AppDatabase db) async {
  await dropV9(db);
  await db.customStatement('ALTER TABLE scheduled_notifications DROP COLUMN content_key');
}

/// Takes a current database back to v6: drops what v7 and v8 added.
Future<void> dropV7(AppDatabase db) async {
  await dropV8(db);
  await db.customStatement('DROP TABLE pending_uploads');
  for (final column in ['avatar_file', 'avatar_file_version']) {
    await db.customStatement('ALTER TABLE sync_state DROP COLUMN $column');
  }
}
