import 'package:flutter_test/flutter_test.dart';
import 'package:habit/services/habit_actions.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

void main() {
  setUpAll(Device.loadZones);

  late Device phone;
  late HabitActions actions;
  late int writes;

  setUp(() async {
    phone = await Device(FakeSyncServer()).init();
    writes = 0;
    actions = HabitActions(phone.writer, onLocalWrite: () => writes++, clock: () => phone.now);
  });

  tearDown(() => phone.db.close());

  test('the minimal editor creates a one-tap daily habit starting today', () async {
    final id = await actions.createOneTapHabit(name: '  Stretch ', category: 'mindfulness');

    final habit = (await phone.view.habits()).single;
    expect(habit.id, id);
    expect(habit.payload['name'], 'Stretch');
    expect(habit.payload['type'], phone.view.types.all.firstWhere((r) => r.oneTap).key);
    expect(habit.payload['frequency_type'], 'daily');
    expect(habit.payload['start_local_date'], '2026-05-28');
    expect(writes, 1);
  });

  test('toggle checks in, then undoes', () async {
    await actions.createOneTapHabit(name: 'Stretch', category: 'health');
    var item = (await phone.view.today(phone.now))!.items.single;
    expect(item.complete, isFalse);

    await actions.toggle(item);
    item = (await phone.view.today(phone.now))!.items.single;
    expect((item.complete, item.pending), (true, true));

    await actions.toggle(item);
    item = (await phone.view.today(phone.now))!.items.single;
    expect(item.complete, isFalse);
    expect(writes, 3);
  });

  test('toggle refuses a habit-day that needs a decision', () async {
    final habit = await actions.createOneTapHabit(name: 'Stretch', category: 'health');
    await phone.writer.setLogValue(habitId: habit, value: 1);
    await phone.db.customStatement(
      "UPDATE outbox SET state = '${OutboxState.needsAttention}' WHERE entity = 'habit_log'",
    );
    final item = (await phone.view.today(phone.now))!.items.single;

    expect(item.needsAttention, isTrue);
    await expectLater(actions.toggle(item), throwsStateError);
    expect(await phone.outbox(), hasLength(2), reason: 'nothing queued behind it');
  });
}
