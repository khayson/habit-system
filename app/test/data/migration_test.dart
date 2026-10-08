import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
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

  test('v3 -> v4 adds the app version and keeps everything else', () async {
    final v4 = AppDatabase(NativeDatabase(file));
    await v4.customStatement(
      "INSERT INTO sync_state (id, user_id, device_id, cursor) VALUES (1, 'u', 'd', 'c:7')",
    );
    await v4.customStatement('ALTER TABLE sync_state DROP COLUMN app_version');
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
