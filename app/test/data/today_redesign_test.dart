import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// A56: Today's redesign shows each habit's confirmed streak (never computed on the device,
/// invariant 9) and a reminder card while no reminder is set.
void main() {
  setUpAll(loadTestZones);

  test('a habit carries its confirmed streak; none until the server sends one', () async {
    final server = FakeSyncServer();
    final account = await testAccount(server);
    final db = account.session.db;
    final id = await account.writer.createHabitUnchecked(
      name: 'Water',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-20'),
      backdate: true,
    );
    var today = (await account.view.today(testNow))!;
    expect(today.items.single.streak, isNull);

    await db
        .into(db.habitProgress)
        .insert(HabitProgressCompanion.insert(habitId: id, version: 3, current: const Value(6)));
    today = (await account.view.today(testNow))!;
    expect(today.items.single.streak, 6);
    account.dispose();
    await db.close();
  });

  test('hasReminders is false until a live, enabled reminder exists', () async {
    final server = FakeSyncServer();
    final account = await testAccount(server);
    final id = await account.writer.createHabitUnchecked(
      name: 'Water',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-20'),
      backdate: true,
    );
    expect((await account.view.today(testNow))!.hasReminders, isFalse);
    await account.writer.createReminder(habitId: id, localTime: '08:00', daysOfWeek: [1, 2, 3]);
    expect((await account.view.today(testNow))!.hasReminders, isTrue);
    account.dispose();
    await account.session.db.close();
  });
}
