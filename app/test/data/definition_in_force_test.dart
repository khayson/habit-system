import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// P3 (A34): a habit's top-level fields are its LATEST definition, which may start tomorrow.
/// Today, the weekly progress and the library use the definition in force on the date.
void main() {
  setUpAll(Device.loadZones);

  test('a version starting tomorrow changes nothing today, and applies on its date', () async {
    final server = FakeSyncServer();
    final phone = await Device(server).init();
    final water = await phone.writer.createHabit(
      name: 'Water',
      type: 'quantity',
      target: '2000.000',
      unit: 'ml',
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
      backdate: true,
    );
    await phone.writer.setLogValue(habitId: water, value: '2500.000');
    await phone.sync(force: true);
    // Another device raises the target from tomorrow (28 May is today in Los Angeles).
    server.serverEditHabit(water, (h) {
      final v1 = (h['definitions'] as List).first as Map<String, dynamic>;
      h['target_value'] = '3000.000';
      h['definition_version'] = 2;
      h['definitions'] = [
        v1,
        {...v1, 'version': 2, 'effective_date': '2026-05-29', 'target_value': '3000.000'},
      ];
    });
    await phone.sync(force: true);

    final view = LocalView(phone.db);
    final today = (await view.today(phone.now))!.items.single;
    expect(
      today.complete,
      isTrue,
      reason: '2500 meets the 2000 in force today, not tomorrow\'s 3000',
    );
    final habit = (await view.habits()).single;
    expect(habit.schedule.targetOn(LocalDate.parse('2026-05-28')), '2000.000');
    expect(habit.schedule.targetOn(LocalDate.parse('2026-05-29')), '3000.000');

    phone.now = DateTime.utc(2026, 5, 29, 17, 22);
    await phone.writer.setLogValue(habitId: water, value: '2500.000');
    final tomorrow = (await view.today(phone.now))!.items.single;
    expect(tomorrow.complete, isFalse, reason: 'from its date, 3000 is the target');
    await phone.db.close();
  });
}
