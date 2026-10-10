import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/notifications/reminder_scheduling.dart';

import '../support/fake_notification_scheduler.dart';
import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 4.2a, Part B: what the reminder planner reacts to (pulled changes, archives, renames)
/// and what it leaves out (archived habits, a met weekly goal), on the real engine and fakes.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late Device tablet;
  late FakeNotificationScheduler os;
  late ReminderScheduling scheduling;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    tablet = await Device(server, deviceId: '01970000-0000-7000-8000-00000000d002').init();
    os = FakeNotificationScheduler();
    scheduling = ReminderScheduling(
      db: phone.db,
      view: LocalView(phone.db),
      scheduler: os,
      accountKey: 'user-1',
      deviceZone: () async => 'America/Los_Angeles',
      title: (name) => name,
      body: 'A gentle reminder for today.',
      hiddenTitle: 'A habit reminder',
      clock: () => phone.now,
      debounce: const Duration(milliseconds: 1),
    );
  });

  tearDown(() async {
    await scheduling.dispose();
    await phone.db.close();
    await tablet.db.close();
  });

  /// A habit with an every-day reminder at [time], synced to both devices.
  Future<(String, String)> habitWithReminder({String time = '20:00'}) async {
    final habit = await phone.writer.createHabit(
      name: 'Water',
      type: 'quantity',
      target: '2000.000',
      unit: 'ml',
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
      backdate: true,
    );
    final reminder = await phone.writer.createReminder(
      habitId: habit,
      localTime: time,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    );
    await phone.sync(force: true);
    await tablet.sync(force: true);
    return (habit, reminder);
  }

  /// Lets the watch fire and the debounced replan finish.
  Future<void> settleReplan() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await scheduling.replan();
  }

  test('B1: a reminder edit pulled from another device replans, though no count changed', () async {
    final (_, reminder) = await habitWithReminder();
    scheduling.start();
    await settleReplan();
    expect(os.pending.values.every((p) => p.$1.fireAt.toUtc().minute == 0), isTrue);
    final scheduled = os.calls.length;

    // Another device moves the reminder to 20:30 (counts stay the same).
    server.serverEditReminder(reminder, (r) => r['local_time'] = '20:30');
    await phone.sync(force: true);
    // Only the watch may start this replan: wait for it, do not call replan() here.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(os.calls.length, greaterThan(scheduled), reason: 'the pulled change was seen');
    expect(os.pending.values.every((p) => p.$1.fireAt.toUtc().minute == 30), isTrue);
  });

  test('B2: an archived habit gets no notifications; restoring brings them back', () async {
    final (habit, _) = await habitWithReminder();
    await scheduling.replan();
    expect(os.pending, isNotEmpty);

    await phone.writer.archiveHabit(habit);
    await settleReplan();
    expect(os.pending, isEmpty, reason: 'an unsent archive already counts (A2 rule)');

    await phone.sync(force: true);
    await settleReplan();
    expect(os.pending, isEmpty, reason: 'confirmed archived');

    await phone.writer.restoreHabit(habit);
    await settleReplan();
    expect(os.pending, isNotEmpty);
  });

  test('B3: a rename pulled from another device replaces the scheduled text, same ids', () async {
    final (habit, _) = await habitWithReminder();
    scheduling.start();
    await settleReplan();
    final ids = os.pending.keys.toSet();
    expect(os.pending.values.map((p) => p.$2).toSet(), {'Water'});

    server.serverEditHabit(habit, (h) => h['name'] = 'Water daily');
    await phone.sync(force: true);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(os.pending.keys.toSet(), ids, reason: 'same notification ids, no duplicates');
    expect(os.pending.values.map((p) => p.$2).toSet(), {'Water daily'});
    expect((await phone.db.select(phone.db.scheduledNotifications).get()).length, ids.length);
  });

  test('B3: with habit names hidden a rename changes nothing', () async {
    final (habit, _) = await habitWithReminder();
    await scheduling.setHideHabitNames(true);
    final calls = os.calls.length;

    server.serverEditHabit(habit, (h) => h['name'] = 'Water daily');
    await phone.sync(force: true);
    await settleReplan();

    expect(os.calls.length, calls, reason: 'the text has no name: nothing to replace');
  });

  test(
    'B5: a weekly goal met on Wednesday plans nothing Thursday to Sunday, then next Monday',
    () async {
      // Wednesday 27 May 2026, 10:00 in Los Angeles.
      phone.now = DateTime.utc(2026, 5, 27, 17);
      final habit = await phone.writer.createHabit(
        name: 'Run',
        type: 'binary',
        target: 1,
        category: 'health',
        frequencyType: 'weekly_count',
        frequencyConfig: const {'count': 3},
        startLocalDate: LocalDate.parse('2026-05-01'),
        backdate: true,
      );
      await phone.writer.createReminder(
        habitId: habit,
        localTime: '20:00',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      );
      Set<String> planned() => {for (final p in os.pending.values) '${p.$1.slotDate}'};

      await scheduling.replan();
      expect(planned(), contains('2026-05-28'), reason: 'not met yet: Thursday is planned');

      for (final day in ['2026-05-25', '2026-05-26', '2026-05-27']) {
        await phone.writer.setLogValue(habitId: habit, value: 1, logDate: LocalDate.parse(day));
      }
      await scheduling.replan();
      expect(
        planned().intersection({'2026-05-28', '2026-05-29', '2026-05-30', '2026-05-31'}),
        isEmpty,
      );
      expect(planned(), contains('2026-06-01'), reason: 'the next week starts over');

      // An undo that drops it below the count brings the rest of the week back.
      await phone.writer.setLogValue(
        habitId: habit,
        value: 0,
        logDate: LocalDate.parse('2026-05-26'),
      );
      await scheduling.replan();
      expect(planned(), contains('2026-05-28'));
    },
  );
}
