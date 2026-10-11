import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/habit_detail_view.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.3a Part A: log.increment in the app (A35).
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
  });
  tearDown(() => phone.db.close());

  final today = LocalDate.parse('2026-05-28');

  Future<String> water() => phone.writer.createHabitUnchecked(
    name: 'Water',
    type: 'quantity',
    target: '2000.000',
    unit: 'ml',
    category: 'health',
    startLocalDate: LocalDate.parse('2026-05-01'),
    backdate: true,
  );

  Future<List<OutboxRow>> logRows() async =>
      (await phone.outbox()).where((r) => r.entity == 'habit_log').toList();

  Map<String, dynamic> payload(OutboxRow r) =>
      (jsonDecode(r.payload) as Map).cast<String, dynamic>();

  Matcher failure(LogFailureKind kind) =>
      throwsA(isA<LogFailure>().having((f) => f.kind, 'kind', kind));

  test('A1: log.increment with no base version, filed under the habit-day', () async {
    final id = await water();
    await phone.sync(force: true);
    final write = await phone.writer.incrementLog(habitId: id, delta: '250');
    final row = (await logRows()).single;
    expect(
      (row.operation, row.baseVersion, row.localDateHint, write.date),
      ('log.increment', null, '2026-05-28', today),
    );
    expect(payload(row), {'habit_id': id, 'delta': '250.000'});
  });

  test(
    'A1: a backdated increment carries date_mode and log_date; a date too old is refused',
    () async {
      final id = await water();
      await phone.sync(force: true);
      await phone.writer.incrementLog(
        habitId: id,
        delta: '0.5',
        logDate: LocalDate.parse('2026-05-20'),
      );
      expect(payload((await logRows()).single), {
        'habit_id': id,
        'delta': '0.500',
        'date_mode': 'backdate',
        'log_date': '2026-05-20',
      });
      await expectLater(
        phone.writer.incrementLog(habitId: id, delta: '1', logDate: LocalDate.parse('2026-04-01')),
        throwsA(anything),
      );
      expect(await logRows(), hasLength(1));
    },
  );

  test('A1/A5: an invalid delta and a yes / no habit write nothing', () async {
    final id = await water();
    final stretch = await phone.writer.createHabitUnchecked(
      name: 'Stretch',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: today,
    );
    for (final delta in ['0', '-1', '1.2345', 'abc', 2.5]) {
      await expectLater(
        phone.writer.incrementLog(habitId: id, delta: delta),
        failure(LogFailureKind.invalidDelta),
        reason: '$delta',
      );
    }
    await expectLater(
      phone.writer.incrementLog(habitId: stretch, delta: 1),
      failure(LogFailureKind.invalidDelta),
    );
    expect(await logRows(), isEmpty);
  });

  test(
    'A2: increments fold into a pending increment by the type rule, newest occurred_at',
    () async {
      final id = await water();
      await phone.sync(force: true);
      final first = await phone.writer.incrementLog(habitId: id, delta: '0.25');
      phone.now = phone.now.add(const Duration(minutes: 5));
      final second = await phone.writer.incrementLog(habitId: id, delta: '0.125');
      final row = (await logRows()).single;
      expect((second.mutationId, second.coalesced), (first.mutationId, true));
      expect(payload(row)['delta'], '0.375');
      expect(row.occurredAt, '2026-05-28T17:27:00Z');
    },
  );

  test('A2: never into an in-flight row, never across kinds', () async {
    final id = await water();
    await phone.sync(force: true);
    await phone.writer.incrementLog(habitId: id, delta: '1');
    await (phone.db.update(phone.db.outbox))
        .write(const OutboxCompanion(state: Value(OutboxState.inFlight)));
    await phone.writer.incrementLog(habitId: id, delta: '2');
    await phone.writer.setLogValue(habitId: id, value: '5.000');
    await phone.writer.incrementLog(habitId: id, delta: '3');
    expect(
      (await logRows()).map((r) => (r.operation, payload(r)['delta'] ?? payload(r)['value'])),
      [
        ('log.increment', '1.000'),
        ('log.increment', '2.000'),
        ('log.set_value', '5.000'),
        ('log.increment', '3.000'),
      ],
    );
  });

  test(
    'A3: on a day that shows deleted, an increment is a set_value restore on the tombstone',
    () async {
      final id = await water();
      await phone.writer.setLogValue(habitId: id, value: '1.000');
      await phone.sync(force: true);
      await phone.writer.deleteLog(habitId: id, date: today);
      await phone.sync(force: true);
      final tombstone = (await phone.db.select(phone.db.habitLogs).get()).single;
      await phone.writer.incrementLog(habitId: id, delta: '0.5');
      final row = (await logRows()).single;
      expect(
        (row.operation, row.baseVersion, payload(row)['value']),
        ('log.set_value', tombstone.version, '0.500'),
      );
      await phone.sync(force: true);
      expect(server.logs.values.single['value'], '0.500');
    },
  );

  test('A1/A5: an increment on an unsent create waits for it, then lands', () async {
    final id = await water();
    await phone.writer.incrementLog(habitId: id, delta: '0.75');
    await phone.sync(force: true);
    expect(await phone.outbox(), isEmpty);
    expect(server.logs.values.single['value'], '0.750');
  });

  test(
    'A1: rows behind an unacked increment send in order and the increment never gets a base',
    () async {
      final id = await water();
      await phone.writer.setLogValue(habitId: id, value: '1.000');
      await phone.sync(force: true);
      await phone.writer.incrementLog(habitId: id, delta: '0.25');
      await phone.writer.setLogValue(habitId: id, value: '3.000');
      await phone.writer.incrementLog(habitId: id, delta: '0.5');
      final sent = <Map<String, Object?>>[];
      server.onMutation = sent.add;
      await phone.sync(force: true);
      expect(await phone.outbox(), isEmpty);
      expect(
        [for (final m in sent) (m['operation'], m['base_version'])],
        [('log.increment', null), ('log.set_value', 2), ('log.increment', null)],
      );
      expect(server.logs.values.single['value'], '3.500');
    },
  );

  test('A5: two devices add to the same habit-day offline: the server holds the sum', () async {
    final id = await water();
    await phone.sync(force: true);
    final tablet = await Device(server, deviceId: '01970000-0000-7000-8000-00000000d002').init();
    addTearDown(tablet.db.close);
    await tablet.sync(force: true);
    await phone.writer.incrementLog(habitId: id, delta: '0.25');
    await tablet.writer.incrementLog(habitId: id, delta: '0.5');
    await phone.sync(force: true);
    await tablet.sync(force: true);
    await phone.sync(force: true);
    expect(server.logs.values.single['value'], '0.750');
    expect((await phone.outbox()).isEmpty && (await tablet.outbox()).isEmpty, isTrue);
    for (final d in [phone, tablet]) {
      expect((await d.view.log(id, '2026-05-28')).value, '0.750');
    }
  });

  test(
    'A5: an increment on a day another device deleted ends in needs_attention, current kept',
    () async {
      final id = await water();
      await phone.writer.setLogValue(habitId: id, value: '1.000');
      await phone.sync(force: true);
      final tablet = await Device(server, deviceId: '01970000-0000-7000-8000-00000000d002').init();
      addTearDown(tablet.db.close);
      await tablet.sync(force: true);
      await tablet.writer.deleteLog(habitId: id, date: today);
      await tablet.sync(force: true);
      await phone.writer.incrementLog(habitId: id, delta: '0.5');
      await phone.sync(force: true);
      final row = (await logRows()).single;
      final error = jsonDecode(row.lastError!) as Map;
      expect((row.state, error['code']), (OutboxState.needsAttention, 'resource_deleted'));
      expect((error['current'] as Map)['deleted_at'], isNotNull);
    },
  );

  group('A4: every reader applies queued rows through the one shared step', () {
    Future<String> sequence() async {
      // Target 3.5 L: only the increments make the day complete.
      final id = await phone.writer.createHabitUnchecked(
        name: 'Water',
        type: 'quantity',
        target: '3.500',
        unit: 'L',
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      );
      await phone.writer.setLogValue(habitId: id, value: '1.000');
      await phone.sync(force: true);
      server.failNextSync.addAll(List.filled(5, const SyncTransportException(SyncFailure.network)));
      await phone.writer.incrementLog(habitId: id, delta: '0.250');
      await phone.writer.setLogValue(habitId: id, value: '3.000');
      await phone.writer.incrementLog(habitId: id, delta: '0.500');
      return id;
    }

    test('confirmed 1.000, +0.250, set 3.000, +0.500: every reader shows 3.500', () async {
      final id = await sequence();
      final log = await phone.view.log(id, '2026-05-28');
      final item = (await phone.view.today(phone.now))!.items.single;
      final detail = (await phone.view.detail(id, phone.now))!;
      expect(
        (log.value, item.log.value, item.complete, detail.logOn(today)!.value),
        ('3.500', '3.500', true, '3.500'),
      );
      expect(log.syncState, OutboxState.pending);
    });

    test('an increment in needs_attention still shows, marked', () async {
      final id = await sequence();
      await (phone.db.update(phone.db.outbox)..where((o) => o.operation.equals('log.increment')))
          .write(const OutboxCompanion(state: Value(OutboxState.needsAttention)));
      final log = await phone.view.log(id, '2026-05-28');
      expect((log.value, log.syncState), ('3.500', OutboxState.needsAttention));
    });

    test('a delta the rules refuse is ignored in the overlay', () async {
      final id = await sequence();
      final row = (await logRows()).last;
      await (phone.db.update(phone.db.outbox)..where((o) => o.seq.equals(row.seq))).write(
        OutboxCompanion(payload: Value(jsonEncode({'habit_id': id, 'delta': '-9.000'}))),
      );
      expect((await phone.view.log(id, '2026-05-28')).value, '3.000');
    });
  });
}
