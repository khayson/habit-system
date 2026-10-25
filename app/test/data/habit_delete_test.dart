import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/conflicts.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 6.6 (A51): deleting a habit through LocalMutationService, and the pulled tombstone on
/// another device. Against contract-fixtures/habit/habit_delete.json.
void main() {
  setUpAll(Device.loadZones);

  final fixture = contractFixture('habit/habit_delete.json');
  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
  });
  tearDown(() => phone.db.close());

  Future<String> yoga(Device d) => d.writer.createHabitUnchecked(
    name: 'Yoga',
    type: 'duration',
    target: 900,
    category: 'health',
    startLocalDate: LocalDate.parse('2026-05-20'),
    backdate: true,
  );

  Future<Map<String, int>> localRows(Device d, String habitId) async {
    Future<int> count(String table) async =>
        (await d.db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM $table WHERE habit_id = ?',
                  variables: [Variable(habitId)],
                )
                .getSingle())
            .read<int>('n');
    return {
      'habits':
          (await d.db
                  .customSelect(
                    'SELECT COUNT(*) AS n FROM habits WHERE id = ?',
                    variables: [Variable(habitId)],
                  )
                  .getSingle())
              .read<int>('n'),
      for (final t in [
        'habit_logs',
        'habit_progress',
        'period_evaluations',
        'reminders',
        'timer_drafts',
      ])
        t: await count(t),
    };
  }

  test('the fixture declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

  test('deletes a synced habit: one habit.delete on the confirmed version; its unsent rows and '
      'local data go', () async {
    final id = await yoga(phone);
    await phone.writer.setLogValue(habitId: id, value: 600, logDate: LocalDate.parse('2026-05-21'));
    await phone.writer.createReminder(habitId: id, localTime: '08:00', daysOfWeek: [1, 2, 3]);
    await phone.sync(force: true);
    final confirmed = (await phone.db.select(phone.db.habits).getSingle()).version;
    await phone.writer.setLogValue(habitId: id, value: 900);
    await phone.writer.startTimer(id);
    await phone.writer.archiveHabit(id);
    expect((await localRows(phone, id)).values.where((n) => n > 0), isNotEmpty);

    await phone.writer.deleteHabit(id);

    final outbox = await phone.outbox();
    expect(outbox.map((r) => r.operation), ['habit.delete']);
    final row = outbox.single;
    expect((row.entity, row.entityId, row.baseVersion), ('habit', id, confirmed));
    expect(jsonDecode(row.payload), (fixture['delete'] as Map)['mutation']['payload']);
    expect((await localRows(phone, id)).values.every((n) => n == 0), isTrue);

    await phone.sync(force: true);
    expect(server.habits[id]!['deleted_at'], isNotNull);
    expect(server.logs.values.where((l) => l['habit_id'] == id), isEmpty);
    expect((await localRows(phone, id)).values.every((n) => n == 0), isTrue);
    expect(await phone.outbox(), isEmpty);
  });

  test('deleting a habit that never left the device sends nothing', () async {
    final id = await yoga(phone);
    await phone.writer.setLogValue(habitId: id, value: 300);

    await phone.writer.deleteHabit(id);

    expect(await phone.outbox(), isEmpty);
    expect((await localRows(phone, id)).values.every((n) => n == 0), isTrue);
    await phone.sync(force: true);
    expect(server.habits, isEmpty);
  });

  test('an unsent edit is dropped too, so the delete is not stale', () async {
    final id = await yoga(phone);
    await phone.sync(force: true);
    await phone.writer.archiveHabit(id);
    await phone.writer.restoreHabit(id);

    await phone.writer.deleteHabit(id);
    await phone.sync(force: true);

    expect(server.habits[id]!['deleted_at'], isNotNull);
    expect(await phone.outbox(), isEmpty);
  });

  test("a pulled tombstone removes the habit on another device; that device's unsent check-in "
      'comes back as deleted on another device, discard only', () async {
    final id = await yoga(phone);
    await phone.writer.setLogValue(habitId: id, value: 600, logDate: LocalDate.parse('2026-05-21'));
    await phone.writer.createReminder(habitId: id, localTime: '08:00', daysOfWeek: [1, 2, 3]);
    await phone.sync(force: true);
    final tablet = await Device(server).init();
    addTearDown(tablet.db.close);
    await tablet.sync(force: true);
    expect((await localRows(tablet, id))['habits'], 1);
    await tablet.writer.setLogValue(habitId: id, value: 900);

    await phone.writer.deleteHabit(id);
    await phone.sync(force: true);
    await tablet.sync(force: true);

    expect((await localRows(tablet, id)).values.every((n) => n == 0), isTrue);
    final kept = (await tablet.outbox()).single;
    expect(kept.state, OutboxState.needsAttention);
    final error = jsonDecode(kept.lastError!) as Map;
    expect((error['code'], error['entity'], error['habit_id']), ('resource_deleted', 'habit', id));
    expect(reviewable(kept), isFalse, reason: 'discard only');
  });

  // 6.6 review L1: a delete's intent cannot be misread, so a stale one is re-sent once on the
  // server's version; a second conflict needs attention.
  test('a delete made stale by an edit elsewhere is re-sent once and lands', () async {
    final id = await yoga(phone);
    await phone.sync(force: true);
    // Another device archives it after this phone's last sync.
    server.habits[id]!
      ..['archived_at'] = '2026-05-28T18:00:00Z'
      ..['version'] = (server.habits[id]!['version'] as int) + 1;

    await phone.writer.deleteHabit(id);
    await phone.sync(force: true);

    expect(server.habits[id]!['deleted_at'], isNotNull);
    expect(await phone.outbox(), isEmpty);
  });

  test('a second conflict after the one re-send needs a look, discard only', () async {
    final id = await yoga(phone);
    await phone.sync(force: true);
    // Edited elsewhere before each attempt: the re-sent delete is stale again.
    server.alwaysStaleHabits.add(id);

    await phone.writer.deleteHabit(id);
    await phone.sync(force: true);
    await phone.sync(force: true);

    final kept = (await phone.outbox()).single;
    expect(kept.state, OutboxState.needsAttention);
    expect(reviewable(kept), isFalse, reason: 'the habit is gone here: discard only');
  });
}
