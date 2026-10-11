import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.2a (A34): habit.update, habit.archive and habit.restore through LocalMutationService.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
  });
  tearDown(() => phone.db.close());

  Future<String> water() => phone.writer.createHabit(
    name: 'Water',
    type: 'quantity',
    target: '2000.000',
    unit: 'ml',
    category: 'health',
    startLocalDate: LocalDate.parse('2026-05-01'),
    backdate: true,
  );

  HabitDraft draft({
    String name = 'Water',
    String category = 'health',
    Object? target = '2000.000',
    String? unit = 'ml',
    String frequencyType = 'daily',
    Map<String, dynamic> config = const {},
  }) => HabitDraft(
    name: name,
    category: category,
    targetValue: target,
    unit: unit,
    frequencyType: frequencyType,
    frequencyConfig: config,
  );

  Future<List<OutboxRow>> habitRows(String id) async =>
      (await phone.outbox()).where((r) => r.entity == 'habit' && r.entityId == id).toList();

  Map<String, dynamic> payload(OutboxRow row) =>
      (jsonDecode(row.payload) as Map).cast<String, dynamic>();

  test('refuses what the server would refuse, by field, and writes nothing', () async {
    final id = await water();
    await phone.sync(force: true);
    final cases = <HabitDraft, HabitDraftProblem>{
      draft(name: '   '): HabitDraftProblem.nameRequired,
      draft(name: 'x' * 101): HabitDraftProblem.nameTooLong,
      draft(category: 'fitness'): HabitDraftProblem.category,
      draft(target: '0'): HabitDraftProblem.target,
      draft(target: 2000.5): HabitDraftProblem.target,
      draft(unit: ' '): HabitDraftProblem.unitRequired,
      draft(unit: 'u' * 25): HabitDraftProblem.unitTooLong,
      draft(
        frequencyType: 'weekdays',
        config: {
          'days': [1, 1],
        },
      ): HabitDraftProblem.weekdays,
      draft(frequencyType: 'weekdays', config: {'days': <int>[]}): HabitDraftProblem.weekdays,
      draft(
        frequencyType: 'weekdays',
        config: {
          'days': [0, 8],
        },
      ): HabitDraftProblem.weekdays,
      draft(frequencyType: 'weekly_count', config: {'count': 8}): HabitDraftProblem.weeklyCount,
      draft(frequencyType: 'interval', config: {'every_n_days': 0, 'anchor_date': '2026-05-01'}):
          HabitDraftProblem.interval,
      draft(frequencyType: 'interval', config: {'every_n_days': 3}):
          HabitDraftProblem.intervalAnchor,
      draft(frequencyType: 'monthly'): HabitDraftProblem.frequencyType,
    };
    for (final MapEntry(key: d, value: problem) in cases.entries) {
      await expectLater(
        phone.writer.updateHabit(id, d),
        throwsA(
          isA<HabitEditFailure>()
              .having((f) => f.kind, 'kind', HabitEditFailureKind.invalid)
              .having((f) => f.problems, 'problems', contains(problem)),
        ),
        reason: '$problem',
      );
    }
    expect(await habitRows(id), isEmpty);
    // A yes/no habit takes no unit.
    final stretch = await phone.habit();
    await expectLater(
      phone.writer.updateHabit(stretch, draft(name: 'Stretch', target: 1, unit: 'reps')),
      throwsA(
        isA<HabitEditFailure>().having((f) => f.problems, 'p', [HabitDraftProblem.unitNotAllowed]),
      ),
    );
  });

  test(
    'a synced habit: six keys, never the type, on the confirmed version; a second edit coalesces',
    () async {
      final id = await water();
      await phone.sync(force: true);

      await phone.writer.updateHabit(id, draft(name: 'Water daily', target: '2500.000'));
      final first = (await habitRows(id)).single;
      expect(first.operation, 'habit.update');
      expect(first.baseVersion, 1);
      expect(payload(first).keys.toSet(), {
        'name',
        'category',
        'target_value',
        'unit',
        'frequency_type',
        'frequency_config',
      });

      await phone.writer.updateHabit(id, draft(name: 'Water daily', target: '3000.000'));
      final rows = await habitRows(id);
      expect(rows, hasLength(1), reason: 'coalesced');
      expect((rows.single.mutationId, rows.single.baseVersion), (first.mutationId, 1));
      expect(payload(rows.single)['target_value'], '3000.000');
    },
  );

  test('an edit equal to what the habit shows writes nothing', () async {
    final id = await water();
    await phone.sync(force: true);
    await phone.writer.updateHabit(id, draft(target: '2000'));
    expect(await habitRows(id), isEmpty, reason: '2000 and 2000.000 are the same target');

    await phone.writer.updateHabit(id, draft(name: 'Water daily'));
    await phone.writer.updateHabit(id, draft(name: 'Water daily'));
    expect((await habitRows(id)).single.operation, 'habit.update');
  });

  test('while the create is unsent the edit folds into it', () async {
    final id = await water();
    await phone.writer.updateHabit(id, draft(name: 'Water daily', target: '2500.000'));

    final rows = await habitRows(id);
    expect(rows.map((r) => r.operation), ['habit.create']);
    expect(
      (
        payload(rows.single)['name'],
        payload(rows.single)['target_value'],
        payload(rows.single)['type'],
      ),
      ('Water daily', '2500.000', 'quantity'),
    );
  });

  test('behind a create in flight the edit waits with no base; behind an acked one it uses its version', () async {
    final id = await water();
    await (phone.db.update(phone.db.outbox))
        .write(const OutboxCompanion(state: Value(OutboxState.inFlight)));
    await phone.writer.updateHabit(id, draft(name: 'Water daily'));
    var update = (await habitRows(id)).last;
    expect((update.operation, update.baseVersion), ('habit.update', null));

    await (phone.db.delete(phone.db.outbox)..where((o) => o.operation.equals('habit.update'))).go();
    await (phone.db.update(phone.db.outbox))
        .write(const OutboxCompanion(state: Value(OutboxState.acked), ackVersion: Value(1)));
    await phone.writer.updateHabit(id, draft(name: 'Water daily'));
    update = (await habitRows(id)).last;
    expect((update.operation, update.baseVersion), ('habit.update', 1));
  });

  test('archive and restore never coalesce and write nothing when already in that state', () async {
    final id = await water();
    await phone.sync(force: true);

    await phone.writer.restoreHabit(id);
    expect(await habitRows(id), isEmpty, reason: 'already active');
    await phone.writer.archiveHabit(id);
    await phone.writer.archiveHabit(id);
    await phone.writer.restoreHabit(id);
    await phone.writer.archiveHabit(id);

    expect((await habitRows(id)).map((r) => r.operation), [
      'habit.archive',
      'habit.restore',
      'habit.archive',
    ]);
  });

  test('never queues behind a change that needs a look', () async {
    final id = await water();
    await phone.sync(force: true);
    await phone.writer.updateHabit(id, draft(name: 'Water daily'));
    await (phone.db.update(phone.db.outbox))
        .write(const OutboxCompanion(state: Value(OutboxState.needsAttention)));

    for (final write in [
      () => phone.writer.updateHabit(id, draft(name: 'Water again')),
      () => phone.writer.archiveHabit(id),
    ]) {
      await expectLater(
        write(),
        throwsA(
          isA<HabitEditFailure>().having(
            (f) => f.kind,
            'kind',
            HabitEditFailureKind.needsAttention,
          ),
        ),
      );
    }
    expect(await habitRows(id), hasLength(1));
  });

  test('an unknown habit is a typed failure', () async {
    await expectLater(
      phone.writer.archiveHabit('0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f'),
      throwsA(
        isA<HabitEditFailure>().having((f) => f.kind, 'kind', HabitEditFailureKind.unknownHabit),
      ),
    );
  });

  test(
    'offline create, edit, archive and restore sync as one create and the queued changes',
    () async {
      final id = await water();
      await phone.writer.updateHabit(id, draft(name: 'Water daily'));
      await phone.writer.archiveHabit(id);
      await phone.writer.restoreHabit(id);

      expect(await phone.sync(force: true), isNotNull);

      final ops = server.sentMutationIds.expand((ids) => ids).length;
      expect(ops, 3, reason: 'the create (with the edit folded in), the archive and the restore');
      final habit = server.habits[id]!;
      expect(
        (habit['name'], habit['archived_at'], (habit['active_ranges'] as List).length),
        ('Water daily', null, 2),
      );
      expect(await phone.outbox(), isEmpty);
    },
  );

  test(
    'L1: an edit after a queued update never folds into a create that went back to pending',
    () async {
      final id = await water();
      // The create is on its way when the first edit is made: that edit is its own row.
      await (phone.db.update(phone.db.outbox))
          .write(const OutboxCompanion(state: Value(OutboxState.inFlight)));
      await phone.writer.updateHabit(id, draft(name: 'Water daily'));
      // The send fails: the create returns to pending, ahead of the queued update.
      server.failNextSync.add(const SyncTransportException(SyncFailure.network));
      await phone.sync(force: true);
      expect((await habitRows(id)).map((r) => (r.operation, r.state)), [
        ('habit.create', OutboxState.pending),
        ('habit.update', OutboxState.pending),
      ]);
      final update = (await habitRows(id)).last;

      await phone.writer.updateHabit(id, draft(name: 'Water, every day'));
      final rows = await habitRows(id);
      expect(rows.map((r) => r.operation), ['habit.create', 'habit.update']);
      expect(payload(rows[0])['name'], 'Water', reason: 'the create is untouched');
      expect(
        (rows[1].mutationId, rows[1].baseVersion, payload(rows[1])['name']),
        (update.mutationId, update.baseVersion, 'Water, every day'),
        reason: 'the queued update is rewritten in place',
      );
      final shown = (await LocalView(phone.db).habits(deviceNow: phone.now)).single;
      expect(shown.payload['name'], 'Water, every day');

      await phone.sync(force: true);
      expect(server.habits[id]!['name'], 'Water, every day');
      expect(await phone.outbox(), isEmpty);
    },
  );

  group('L2: an archived habit cannot be edited', () {
    Matcher archived() => throwsA(
      isA<HabitEditFailure>().having((f) => f.kind, 'kind', HabitEditFailureKind.archived),
    );

    test('a confirmed archive', () async {
      final id = await water();
      await phone.writer.archiveHabit(id);
      await phone.sync(force: true);
      await expectLater(phone.writer.updateHabit(id, draft(name: 'Water daily')), archived());
      expect(await habitRows(id), isEmpty);
    });

    test('a queued archive, until a later restore undoes it', () async {
      final id = await water();
      await phone.sync(force: true);
      await phone.writer.archiveHabit(id);
      await expectLater(phone.writer.updateHabit(id, draft(name: 'Water daily')), archived());
      expect((await habitRows(id)).map((r) => r.operation), ['habit.archive']);

      await phone.writer.restoreHabit(id);
      await phone.writer.updateHabit(id, draft(name: 'Water daily'));
      expect((await habitRows(id)).map((r) => r.operation), [
        'habit.archive',
        'habit.restore',
        'habit.update',
      ]);
    });
  });
}
