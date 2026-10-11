import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/habit_draft.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.2a (A34): how habits look with edits, archives and restores queued or confirmed.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late LocalView view;
  late String water;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    view = LocalView(phone.db);
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

  HabitDraft edited(String name, {Object target = '2000.000'}) => HabitDraft(
    name: name,
    category: 'health',
    targetValue: target,
    unit: 'ml',
    frequencyType: 'daily',
    frequencyConfig: const {},
  );

  Future<HabitView> shown() async =>
      (await view.habits(deviceNow: phone.now)).singleWhere((h) => h.id == water);

  test('an unsent edit shows at once, everywhere, and is marked as queued', () async {
    await phone.writer.updateHabit(water, edited('Water daily'));

    final habit = await shown();
    expect(
      (habit.payload['name'], habit.editable!.name, habit.editQueued),
      ('Water daily', 'Water daily', true),
    );
    final today = (await view.today(phone.now))!.items.single;
    expect(today.habit.payload['name'], 'Water daily');
  });

  test('an archive leaves Today and the library at once and lists the habit as archived', () async {
    await phone.writer.archiveHabit(water);

    expect((await shown()).archived, isTrue);
    expect((await view.today(phone.now))!.items, isEmpty);
    expect(await view.watchHabits(deviceNow: () => phone.now).first, isEmpty);
    final archived = await view.watchArchived(deviceNow: () => phone.now).first;
    expect(archived.single.id, water);
    expect(archived.single.archivedOn, isNull, reason: 'not confirmed yet: no date to show');

    await phone.sync(force: true);
    final confirmed = await view.watchArchived(deviceNow: () => phone.now).first;
    expect(
      (confirmed.single.name, confirmed.single.type, confirmed.single.archivedOn),
      ('Water', 'quantity', LocalDate.parse('2026-05-28')),
    );

    await phone.writer.restoreHabit(water);
    expect((await shown()).archived, isFalse);
    expect((await view.today(phone.now))!.items.single.habit.id, water);
  });

  test(
    'a change in needs_attention never hides a habit; an edit there still shows its text',
    () async {
      await phone.writer.updateHabit(water, edited('Water daily'));
      await (phone.db.update(phone.db.outbox))
          .write(const OutboxCompanion(state: Value(OutboxState.needsAttention)));
      var habit = await shown();
      expect(
        (habit.payload['name'], habit.editNeedsAttention, habit.editQueued),
        ('Water daily', true, false),
      );

      await (phone.db.delete(phone.db.outbox)).go();
      await phone.writer.archiveHabit(water);
      await (phone.db.update(phone.db.outbox))
          .write(const OutboxCompanion(state: Value(OutboxState.needsAttention)));
      habit = await shown();
      expect(habit.archived, isFalse, reason: 'it can always be found');
      expect((await view.today(phone.now))!.items.single.habit.id, water);
    },
  );

  test('pendingFrom is the date of a confirmed version that starts later, never a guess', () async {
    await phone.writer.updateHabit(water, edited('Water', target: '2500.000'));
    expect((await shown()).pendingFrom, isNull, reason: 'queued: the server has not dated it');

    await phone.sync(force: true);
    final habit = await shown();
    expect(habit.pendingFrom, LocalDate.parse('2026-05-29'));
    expect(habit.editable!.targetValue, '2500.000', reason: 'the edit form starts from the latest');
    expect(habit.inForceToday!.wire['target_value'], '2000.000', reason: 'today keeps its target');
  });
}
