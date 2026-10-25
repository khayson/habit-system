import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/entity_codec.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/domain/habit_schedule.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 4.2a (A34): how the engine settles habit.update / archive / restore answers, and the
/// fixture's requests and entities as the app builds and reads them.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late String water;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    water = await phone.writer.createHabitUnchecked(
      name: 'Water',
      type: 'quantity',
      target: '2000.000',
      unit: 'ml',
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
      backdate: true,
    );
    await phone.sync(force: true);
  });
  tearDown(() => phone.db.close());

  HabitDraft draft(String name, {Object target = '2000.000'}) => HabitDraft(
    name: name,
    category: 'health',
    targetValue: target,
    unit: 'ml',
    frequencyType: 'daily',
    frequencyConfig: const {},
  );

  Future<ConfirmedHabit> confirmed() =>
      (phone.db.select(phone.db.habits)..where((h) => h.id.equals(water))).getSingle();

  Map<String, dynamic> errorOf(OutboxRow row) =>
      (jsonDecode(row.lastError!) as Map).cast<String, dynamic>();

  test('accepted edit, archive and restore: rows pruned, definitions and ranges whole', () async {
    await phone.writer.updateHabit(water, draft('Water', target: '2500.000'));
    await phone.sync(force: true);
    await phone.writer.archiveHabit(water);
    await phone.sync(force: true);
    await phone.writer.restoreHabit(water);
    await phone.sync(force: true);

    expect(await phone.outbox(), isEmpty);
    final habit = EntityCodec.habitPayload(await confirmed());
    final schedule = HabitSchedule.fromWire(habit);
    expect(schedule.versions.map((v) => (v.version, '${v.effectiveDate}')), [
      (1, '2026-05-01'),
      (2, '2026-05-29'),
    ]);
    expect(schedule.ranges, hasLength(2), reason: 'archived and restored the same day');
    expect(habit['archived_at'], isNull);
  });

  test(
    "a stale edit is kept for review with the server's current habit; nothing is confirmed",
    () async {
      server.serverEditHabit(water, (h) => h['name'] = 'Water (other phone)');
      await phone.writer.updateHabit(water, draft('Water daily'));

      await phone.sync(force: true);

      final row = (await phone.outbox()).single;
      expect((row.state, errorOf(row)['code']), (OutboxState.needsAttention, 'version_conflict'));
      expect(
        (errorOf(row)['current'] as Map)['name'],
        'Water (other phone)',
        reason: 'current kept',
      );
      expect(jsonDecode(row.payload)['name'], 'Water daily', reason: 'the edit is kept');
      expect((await confirmed()).name, 'Water (other phone)', reason: 'only the pulled change');
    },
  );

  test('habit_archived for a check-in is kept for review with its payload', () async {
    server.serverEditHabit(water, (h) => h['archived_at'] = '2026-05-28T18:00:00Z');
    await phone.writer.setLogValue(habitId: water, value: '250.000');

    await phone.sync(force: true);

    final row = (await phone.outbox()).single;
    expect((row.state, errorOf(row)['code']), (OutboxState.needsAttention, 'habit_archived'));
    expect(jsonDecode(row.payload)['value'], '250.000');
  });

  test('habit_archived for a habit edit is kept for review with its payload', () async {
    server.forceErrorFor['habit.update'] = {'code': 'habit_archived', 'message': 'x'};
    await phone.writer.updateHabit(water, draft('Water daily'));

    await phone.sync(force: true);

    final row = (await phone.outbox()).single;
    expect(
      (row.operation, row.state, errorOf(row)['code']),
      ('habit.update', OutboxState.needsAttention, 'habit_archived'),
    );
    expect(jsonDecode(row.payload)['name'], 'Water daily');
  });

  test('not_found and an unknown code both wait for the person (tolerant)', () async {
    for (final code in ['not_found', 'habit_in_orbit']) {
      server.forceErrorFor['habit.archive'] = {'code': code, 'message': 'x'};
      await phone.writer.archiveHabit(water);
      await phone.sync(force: true);
      final row = (await phone.outbox()).single;
      expect((row.state, errorOf(row)['code']), (OutboxState.needsAttention, code));
      await phone.db.delete(phone.db.outbox).go();
    }
  });

  test("the app builds the fixture's habit.update requests and reads its habits without loss", () {
    final fixture = contractFixture('habit/habit_mutations.json');
    expect(fixture['suites'], contains('dart'));
    const keys = {
      'name',
      'category',
      'target_value',
      'unit',
      'frequency_type',
      'frequency_config',
      'icon',
    };
    var updates = 0;
    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      final habit = (c['habit'] as Map).cast<String, dynamic>();
      final name = c['name'] as String;
      for (final step in (c['steps'] as List).cast<Map<String, dynamic>>()) {
        final change = (step['payload'] as Map).cast<String, dynamic>();
        if (step['operation'] == 'habit.update' && !change.containsKey('type')) {
          final payload = HabitDraft.fromWire({'name': 'Morning plan', ...habit, ...change})
              .toPayload();
          expect(payload.keys.toSet(), keys, reason: name);
          for (final MapEntry(:key, :value) in change.entries) {
            expect(jsonEncode(payload[key]), jsonEncode(value), reason: '$name: $key');
          }
          updates++;
        }
        final expected = step['habit'];
        if (expected is Map && expected['definitions'] is List) {
          final definitions = [
            for (final d in (expected['definitions'] as List).cast<Map<String, dynamic>>())
              {...habit, ...d},
          ];
          final schedule = HabitSchedule.fromWire({...habit, 'definitions': definitions});
          expect(
            schedule.versions.map((v) => '${v.version}@${v.effectiveDate}'),
            definitions.map((d) => '${d['version']}@${d['effective_date']}'),
            reason: name,
          );
        }
        if (expected is Map && expected['active_ranges'] is List) {
          final ranges = [
            for (final r in (expected['active_ranges'] as List).cast<List<dynamic>>())
              {'starts_on': r[0], 'ends_before': r[1]},
          ];
          final schedule = HabitSchedule.fromWire({
            ...habit,
            'definitions': [
              {...habit, 'version': 1, 'effective_date': '2026-05-01'},
            ],
            'active_ranges': ranges,
          });
          expect(schedule.ranges, hasLength(ranges.length), reason: name);
        }
      }
    }
    expect(updates, greaterThan(5));
  });
}
