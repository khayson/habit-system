import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/conflicts.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.3a Part C: the conflict read model and resolution (A37), one test per rule.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late Device tablet;
  late String water;
  final today = LocalDate.parse('2026-05-28');

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    water = await phone.writer.createHabitUnchecked(
      name: 'Water',
      type: 'quantity',
      target: '2.000',
      unit: 'L',
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
      backdate: true,
    );
    await phone.writer.setLogValue(habitId: water, value: '1.000');
    await phone.sync(force: true);
    tablet = await Device(server, deviceId: '01970000-0000-7000-8000-00000000d002').init();
    await tablet.sync(force: true);
  });
  tearDown(() async {
    await phone.db.close();
    await tablet.db.close();
  });

  Future<OutboxRow> attentionRow(Device d) async =>
      (await d.outbox()).singleWhere((r) => r.state == OutboxState.needsAttention);

  int sentCount(String mutationId) =>
      server.sentMutationIds.expand((ids) => ids).where((id) => id == mutationId).length;

  /// Phone writes against a day the tablet changed first.
  Future<OutboxRow> staleSetValue() async {
    await tablet.writer.setLogValue(habitId: water, value: '2.000');
    await tablet.sync(force: true);
    await phone.writer.setLogValue(habitId: water, value: '3.000');
    await phone.sync(force: true);
    return attentionRow(phone);
  }

  Future<void> tabletDeletesDay() async {
    await tablet.writer.deleteLog(habitId: water, date: today);
    await tablet.sync(force: true);
  }

  test(
    'version_conflict on log.set_value: use mine is a new id on current.version and lands',
    () async {
      final old = await staleSetValue();
      final view = (await phone.view.conflict(old.mutationId))!;
      expect(
        (
          view.kind,
          view.mineWire,
          view.mineUnits,
          view.serverValue,
          view.serverVersion,
          view.canUseMine,
        ),
        (ConflictKind.staleValue, '3.000', 3000, '2.000', 2, true),
      );
      expect((view.habitName, view.localDate, view.baseVersion), ('Water', today, 1));

      expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
      final fresh = (await phone.outbox()).single;
      expect(fresh.mutationId, isNot(old.mutationId));
      expect(
        (fresh.state, fresh.baseVersion, fresh.occurredAt, fresh.lastError, fresh.operation),
        (OutboxState.pending, 2, old.occurredAt, null, 'log.set_value'),
      );
      expect(await phone.db.select(phone.db.discardedMutations).get(), hasLength(1));

      await phone.sync(force: true);
      await tablet.sync(force: true);
      expect(server.logs.values.single['value'], '3.000');
      expect((await tablet.view.log(water, '2026-05-28')).value, '3.000');
      expect(sentCount(old.mutationId), 1, reason: 'the old id is never sent again');
    },
  );

  test('keep synced on a stale value discards and keeps the server value', () async {
    final old = await staleSetValue();
    expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
    await phone.sync(force: true);
    expect(await phone.outbox(), isEmpty);
    expect((await phone.view.log(water, '2026-05-28')).value, '2.000');
    expect(sentCount(old.mutationId), 1);
  });

  test('a deleted day with a set_value: use mine restores it on the tombstone', () async {
    await tabletDeletesDay();
    await phone.writer.setLogValue(habitId: water, value: '1.500');
    await phone.sync(force: true);
    final old = await attentionRow(phone);
    final view = (await phone.view.conflict(old.mutationId))!;
    expect(
      (view.kind, view.serverDeleted, view.serverVersion, view.canUseMine),
      (ConflictKind.deletedDay, true, 2, true),
    );
    expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
    await phone.sync(force: true);
    expect(
      (server.logs.values.single['value'], server.logs.values.single['deleted_at']),
      ('1.500', null),
    );
  });

  test(
    'a deleted day with an increment: use mine becomes a set_value restore of the amount',
    () async {
      await tabletDeletesDay();
      await phone.writer.incrementLog(habitId: water, delta: '0.5');
      await phone.sync(force: true);
      final old = await attentionRow(phone);
      expect(old.operation, 'log.increment');
      final view = (await phone.view.conflict(old.mutationId))!;
      expect((view.kind, view.mineWire, view.canUseMine), (ConflictKind.deletedDay, '0.500', true));
      expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
      final fresh = (await phone.outbox()).single;
      expect((fresh.operation, fresh.baseVersion), ('log.set_value', 2));
      await phone.sync(force: true);
      expect(server.logs.values.single['value'], '0.500');
    },
  );

  test('keep synced on a deleted day leaves it deleted', () async {
    await tabletDeletesDay();
    await phone.writer.setLogValue(habitId: water, value: '1.500');
    await phone.sync(force: true);
    final old = await attentionRow(phone);
    expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
    await phone.sync(force: true);
    expect((await phone.view.log(water, '2026-05-28')).deleted, isTrue);
  });

  test(
    'habit_archived: use mine waits until the habit shows active, then keeps its own base',
    () async {
      await tablet.writer.archiveHabit(water);
      await tablet.sync(force: true);
      await phone.writer.setLogValue(habitId: water, value: '1.750');
      await phone.sync(force: true);
      final old = await attentionRow(phone);
      var view = (await phone.view.conflict(old.mutationId))!;
      expect((view.kind, view.canUseMine), (ConflictKind.archivedHabit, false));
      expect(await phone.writer.useMine(old.mutationId), ResolveResult.notAllowed);

      await phone.writer.restoreHabit(water);
      view = (await phone.view.conflict(old.mutationId))!;
      expect(view.canUseMine, isTrue);
      expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
      final fresh = (await phone.outbox()).singleWhere((r) => r.operation == 'log.set_value');
      expect((fresh.operation, fresh.baseVersion), ('log.set_value', old.baseVersion));
      await phone.sync(force: true);
      expect(await phone.outbox(), isEmpty);
      expect(server.logs.values.single['value'], '1.750');
    },
  );

  test('keep synced on an archived-habit refusal drops the check-in', () async {
    await tablet.writer.archiveHabit(water);
    await tablet.sync(force: true);
    await phone.writer.setLogValue(habitId: water, value: '1.750');
    await phone.sync(force: true);
    final old = await attentionRow(phone);
    expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
    expect(await phone.outbox(), isEmpty);
  });

  HabitDraft renamed(String name) => HabitDraft(
    name: name,
    category: 'health',
    targetValue: '2.000',
    unit: 'L',
    frequencyType: 'daily',
    frequencyConfig: const {},
  );

  test(
    'version_conflict on habit.update: use mine on current.version wins; keep synced does not',
    () async {
      await tablet.writer.updateHabit(water, renamed('Water (tablet)'));
      await tablet.sync(force: true);
      await phone.writer.updateHabit(water, renamed('Water (phone)'));
      await phone.sync(force: true);
      final old = await attentionRow(phone);
      final view = (await phone.view.conflict(old.mutationId))!;
      expect(
        (view.kind, view.mineHabit?.name, view.serverHabit?.name, view.canUseMine),
        (ConflictKind.staleHabitEdit, 'Water (phone)', 'Water (tablet)', true),
      );
      expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
      expect((await phone.outbox()).single.baseVersion, view.serverVersion);
      await phone.sync(force: true);
      expect(server.habits[water]!['name'], 'Water (phone)');
    },
  );

  test('keep synced on a stale habit edit keeps the other device\'s name', () async {
    await tablet.writer.updateHabit(water, renamed('Water (tablet)'));
    await tablet.sync(force: true);
    await phone.writer.updateHabit(water, renamed('Water (phone)'));
    await phone.sync(force: true);
    final old = await attentionRow(phone);
    expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
    await phone.sync(force: true);
    expect((await phone.view.habits()).single.payload['name'], 'Water (tablet)');
  });

  test('a second conflict returns the new row to needs_attention with a new error', () async {
    final old = await staleSetValue();
    expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
    await tablet.writer.setLogValue(habitId: water, value: '4.000');
    await tablet.sync(force: true);
    await phone.sync(force: true);
    final again = await attentionRow(phone);
    expect(again.mutationId, isNot(old.mutationId));
    expect((await phone.view.conflict(again.mutationId))!.serverValue, '4.000');
  });

  test('a code outside the three is discard only', () async {
    server.forceErrorFor['log.set_value'] = {'code': 'not_found', 'message': 'x'};
    await phone.writer.setLogValue(habitId: water, value: '1.250');
    await phone.sync(force: true);
    final old = await attentionRow(phone);
    final view = (await phone.view.conflict(old.mutationId))!;
    expect((view.kind, view.canUseMine), (ConflictKind.other, false));
    expect(await phone.writer.useMine(old.mutationId), ResolveResult.notAllowed);
    expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
    expect(await phone.writer.useMine(old.mutationId), ResolveResult.gone);
  });

  test('watchConflicts lists every row that needs a look', () async {
    await staleSetValue();
    final list = await phone.view.watchConflicts().first;
    expect(list.map((c) => c.kind), [ConflictKind.staleValue]);
  });

  group('M1 (4.3a review): use mine keeps the person\'s order of changes', () {
    test('a stale value with an increment behind it: mine, then the increment', () async {
      final old = await staleSetValue();
      await phone.writer.incrementLog(habitId: water, delta: '0.5');
      final before = (await phone.view.log(water, '2026-05-28')).value;
      expect(await phone.writer.useMine(old.mutationId), ResolveResult.done);
      expect((await phone.view.log(water, '2026-05-28')).value, before, reason: 'no jump');
      final sent = <String>[];
      server.onMutation = (m) => sent.add(m['operation']! as String);
      await phone.sync(force: true);
      expect(sent, ['log.set_value', 'log.increment']);
      expect(server.logs.values.single['value'], '3.500');
      expect(before, '3.500');
    });

    test('keep synced with an increment behind it adds to the server value', () async {
      final old = await staleSetValue();
      await phone.writer.incrementLog(habitId: water, delta: '0.5');
      expect(await phone.writer.keepSynced(old.mutationId), ResolveResult.done);
      await phone.sync(force: true);
      expect(server.logs.values.single['value'], '2.500');
      expect(await phone.outbox(), isEmpty);
    });
  });
}
