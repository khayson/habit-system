import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:path/path.dart' as p;

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// LocalMutationService: the only local writer (A23, invariants 8, 9, 16).
void main() {
  setUpAll(Device.loadZones);

  late Device phone;

  setUp(() async => phone = await Device(FakeSyncServer()).init());
  tearDown(() => phone.db.close());

  final v7 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('writes outbox rows with UUIDv7 ids and the server calendar zone (A5)', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);

    final rows = await phone.outbox();
    expect(habit, matches(v7));
    expect(rows.map((r) => r.mutationId), everyElement(matches(v7)));
    expect(rows.map((r) => r.capturedTimezone).toSet(), {'America/Los_Angeles'});
    expect(rows.map((r) => r.state).toSet(), {OutboxState.pending});
    expect(
      await phone.db.select(phone.db.habitLogs).get(),
      isEmpty,
      reason: 'confirmed rows are untouched (invariant 9)',
    );
  });

  test('the habit-day comes from the server calendar, not the device zone or UTC', () async {
    final habit = await phone.habit();
    // 06:30 UTC on 29 May is still 28 May in Los Angeles (spec 08 example).
    await phone.writer.setLogValue(habitId: habit, value: 1, at: DateTime.utc(2026, 5, 29, 6, 30));

    expect((await phone.outbox()).last.localDateHint, '2026-05-28');
  });

  test('coalesces repeated edits of an unsent habit-day into one row', () async {
    final habit = await phone.habit();
    final first = await phone.writer.setLogValue(habitId: habit, value: 1);
    final second = await phone.writer.setLogValue(habitId: habit, value: 0);

    final logs = (await phone.outbox()).where((r) => r.entity == 'habit_log').toList();
    expect(second.coalesced, isTrue);
    expect(second.mutationId, first.mutationId);
    expect(logs, hasLength(1));
    expect(jsonDecode(logs.single.payload)['value'], 0);
  });

  test('never coalesces into a row that was sent (in flight or acked)', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await (phone.db.update(phone.db.outbox)..where((o) => o.entity.equals('habit_log'))).write(
      const OutboxCompanion(state: Value(OutboxState.inFlight)),
    );

    final next = await phone.writer.setLogValue(habitId: habit, value: 0);

    final logs = (await phone.outbox()).where((r) => r.entity == 'habit_log').toList();
    expect(next.coalesced, isFalse);
    expect(logs.map((r) => (r.state, jsonDecode(r.payload)['value'])).toList(), [
      (OutboxState.inFlight, 1),
      (OutboxState.pending, 0),
    ]);
    expect(logs.last.baseVersion, 1, reason: 'based on the in-flight write landing first');
  });

  test('bases a write on the confirmed version; on a tombstone it restores (A29)', () async {
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await phone.sync(); // confirmed v1
    await phone.writer.deleteLog(habitId: habit, date: LocalDate.parse('2026-05-28'));
    await phone.sync(); // confirmed tombstone v2

    await phone.writer.setLogValue(habitId: habit, value: 1);
    final row = (await phone.outbox()).single;
    expect((row.operation, row.baseVersion), ('log.set_value', 2));
  });

  test('a delete carries habit_id + log_date for the natural-key fallback (A29)', () async {
    final habit = await phone.habit();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await phone.writer.deleteLog(habitId: habit, date: LocalDate.parse('2026-05-28'));

    final delete = (await phone.outbox()).last;
    expect(jsonDecode(delete.payload), {'habit_id': habit, 'log_date': '2026-05-28'});
    expect(delete.baseVersion, 1);
  });

  test('refuses to write before the server calendar is known', () async {
    final fresh = Device(FakeSyncServer());
    await expectLater(fresh.habit(), throwsStateError);
    expect(await fresh.db.select(fresh.db.outbox).get(), isEmpty, reason: 'nothing half-written');
    await fresh.db.close();
  });

  test('the writer, view, codec and engine are pure Dart (no Flutter imports)', () {
    final files = [
      'lib/data/local_mutation_service.dart',
      'lib/data/local_view.dart',
      'lib/data/entity_codec.dart',
      ...Directory('lib/sync')
          .listSync()
          .whereType<File>()
          .map((f) => p.posix.joinAll(p.split(f.path))),
      ...Directory('lib/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.posix.joinAll(p.split(f.path))),
    ];
    final offenders = files
        .where((f) => File(f).readAsStringSync().contains('package:flutter/'))
        .toList();
    expect(offenders, isEmpty);
  });
}
