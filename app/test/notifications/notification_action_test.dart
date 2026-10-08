import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/notifications/notification_action.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// A23 notification-action schema (Phase 3.2b): the exact string form, strict parsing, and one
/// write per slot through LocalMutationService.
void main() {
  setUpAll(Device.loadZones);

  const habit = '01970000-0000-7000-8000-0000000000a1';
  const reminder = '01970000-0000-7000-8000-0000000000c1';
  final action = NotificationAction(
    habitId: habit,
    operation: 'log.set_value',
    value: 1,
    slotDate: LocalDate.parse('2026-05-28'),
    reminderId: reminder,
  );

  test('builds the schema string and parses it back', () {
    final payload = action.build();
    expect(payload, 'log:$habit:log.set_value:1|slot:2026-05-28:$reminder');
    final parsed = NotificationAction.parse(payload)!;
    expect(
      [parsed.habitId, parsed.operation, parsed.value, '${parsed.slotDate}', parsed.reminderId],
      [habit, 'log.set_value', 1, '2026-05-28', reminder],
    );
    expect(
      NotificationAction.parse('log:$habit:log.set_value:0.250|slot:2026-05-28:$reminder')!.value,
      '0.250',
      reason: 'quantities stay decimal strings',
    );
  });

  test('anything off-schema parses to null', () {
    for (final bad in [
      null,
      '',
      'log:$habit:log.set_value:1',
      'log:$habit:log.delete:1|slot:2026-05-28:$reminder',
      'log:$habit:log.set_value:1.5e3|slot:2026-05-28:$reminder',
      'log:$habit:log.set_value:-1|slot:2026-05-28:$reminder',
      'log:$habit:log.set_value:1|slot:2026-02-30:$reminder',
      'log:$habit:log.set_value:1|slot:2026-05-28:$reminder:extra',
      'tick:$habit:log.set_value:1|slot:2026-05-28:$reminder',
      'log:bad id:log.set_value:1|slot:2026-05-28:$reminder',
    ]) {
      expect(NotificationAction.parse(bad), isNull, reason: '$bad');
    }
  });

  test('applies once per slot: a second tap writes nothing', () async {
    final phone = await Device(FakeSyncServer()).init();
    final id = await phone.habit();
    final mine = NotificationAction(
      habitId: id,
      operation: 'log.set_value',
      value: 1,
      slotDate: LocalDate.parse('2026-05-28'),
      reminderId: reminder,
    );

    expect(await mine.apply(phone.writer), isTrue);
    expect(await mine.apply(phone.writer), isFalse);

    final logs = (await phone.outbox()).where((r) => r.entity == 'habit_log').toList();
    expect(logs, hasLength(1));
    expect(jsonDecode(logs.single.payload)['log_date'], '2026-05-28');
    expect(logs.single.localDateHint, '2026-05-28');
    await phone.db.close();
  });
}
