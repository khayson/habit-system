import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/data/reminder_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/notifications/reminder_scheduling.dart';
import 'package:habit/sync/sync_engine.dart';

import '../support/fake_notification_scheduler.dart';
import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 3.2b: scheduling through the fake. Replans replace rather than duplicate, a completed
/// habit-day drops its notification, and a logout cancels only that account's notifications.
void main() {
  setUpAll(Device.loadZones);

  // 28 May 2026, 10:22 in Los Angeles.
  final now = DateTime.utc(2026, 5, 28, 17, 22);

  Future<(AppDatabase, LocalMutationService, ReminderScheduling)> account(
    String userId,
    FakeNotificationScheduler os,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await initAccountState(db, userId: userId, deviceId: 'd-$userId', user: FakeSyncServer().user);
    final writer = LocalMutationService(db, clock: () => now);
    final scheduling = ReminderScheduling(
      db: db,
      view: LocalView(db),
      scheduler: os,
      accountKey: userId,
      deviceZone: () async => 'America/Los_Angeles',
      title: (name) => name,
      clock: () => now,
    );
    return (db, writer, scheduling);
  }

  Future<String> habitWithReminder(LocalMutationService writer, String time) async {
    final habit = await writer.createHabit(
      name: 'Stretch',
      type: 'binary',
      target: 1,
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
    );
    await writer.createReminder(habitId: habit, localTime: time, daysOfWeek: [1, 2, 3, 4, 5, 6, 7]);
    return habit;
  }

  test('a replan schedules the horizon once; an edit replaces, never duplicates', () async {
    final os = FakeNotificationScheduler();
    final (db, writer, scheduling) = await account('user-1', os);
    await habitWithReminder(writer, '18:00');

    await scheduling.replan();
    expect(os.pending, hasLength(14), reason: 'today 18:00 is still ahead, then 13 more days');
    final firstIds = os.pending.keys.toSet();

    await scheduling.replan();
    expect(os.calls.where((c) => c.startsWith('schedule')), hasLength(14), reason: 'no-op');

    final reminder = (await LocalView(db).reminders()).single;
    await writer.updateReminder(
      reminderId: reminder.id,
      localTime: '19:30',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    );
    await scheduling.replan();
    expect(os.pending, hasLength(14));
    expect(os.pending.keys.toSet(), firstIds, reason: 'same slots keep their ids');
    expect(os.pending.values.every((p) => p.$1.fireAt.toUtc().minute == 30), isTrue);
    expect((await db.select(db.scheduledNotifications).get()).length, 14);
    await db.close();
  });

  test("completing today's habit-day cancels today's notification", () async {
    final os = FakeNotificationScheduler();
    final (db, writer, scheduling) = await account('user-1', os);
    final habit = await habitWithReminder(writer, '18:00');
    await scheduling.replan();
    final today = os.pending.values.firstWhere((p) => p.$1.slotDate.toString() == '2026-05-28');

    await writer.setLogValue(habitId: habit, value: 1);
    await scheduling.replan();

    expect(os.pending.containsKey(today.$1.id), isFalse);
    expect(os.calls, contains('cancel ${today.$1.id}'));
    expect(os.pending, hasLength(13));
    await db.close();
  });

  test('logout cancels only that account; login replans', () async {
    final os = FakeNotificationScheduler(); // one device, one OS
    final (dbA, writerA, a) = await account('user-a', os);
    final (dbB, writerB, b) = await account('user-b', os);
    await habitWithReminder(writerA, '18:00');
    await habitWithReminder(writerB, '08:00');
    await a.replan();
    await b.replan();
    final ofA = (await dbA.select(dbA.scheduledNotifications).get())
        .map((r) => r.platformId)
        .toSet();
    final ofB = (await dbB.select(dbB.scheduledNotifications).get())
        .map((r) => r.platformId)
        .toSet();
    expect(ofA.intersection(ofB), isEmpty);
    expect(os.pending.keys.toSet(), {...ofA, ...ofB});

    await a.cancelAll();

    expect(os.pending.keys.toSet(), ofB, reason: "B's reminders are untouched");
    expect(await dbA.select(dbA.scheduledNotifications).get(), isEmpty);
    await a.replan();
    expect(os.pending.keys.toSet(), ofB, reason: 'a logged-out account never schedules again');

    final aAgain = ReminderScheduling(
      db: dbA,
      view: LocalView(dbA),
      scheduler: os,
      accountKey: 'user-a',
      deviceZone: () async => 'America/Los_Angeles',
      title: (name) => name,
      clock: () => now,
    );
    await aAgain.replan();
    expect(os.pending.keys.toSet(), {...ofA, ...ofB}, reason: 'login replans');
    await dbA.close();
    await dbB.close();
  });
}
