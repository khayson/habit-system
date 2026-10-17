import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 5.2c (A46): LocalWrite.completeAfter, read inside the write transaction with Today's
/// provisional rule. It only decides whether a save screen waits for the ack.
void main() {
  setUpAll(Device.loadZones);

  late Device phone;

  setUp(() async {
    phone = await Device(FakeSyncServer()).init();
    await phone.sync();
  });

  tearDown(() => phone.db.close());

  test('incrementLog: partial, then the add that reaches the target, then beyond it', () async {
    final water = await phone.habit(type: 'quantity', target: '2000.000');

    expect((await phone.writer.incrementLog(habitId: water, delta: '1500')).completeAfter, isFalse);
    expect((await phone.writer.incrementLog(habitId: water, delta: '500')).completeAfter, isTrue);
    expect((await phone.writer.incrementLog(habitId: water, delta: '250')).completeAfter, isTrue);
  });

  test('setLogValue: at the target, then below it', () async {
    final water = await phone.habit(type: 'quantity', target: '2000.000');

    expect(
      (await phone.writer.setLogValue(habitId: water, value: '2000.000')).completeAfter,
      isTrue,
    );
    expect(
      (await phone.writer.setLogValue(habitId: water, value: '500.000')).completeAfter,
      isFalse,
    );
  });

  test('a timer finish: short of the target, then reaching it', () async {
    final yoga = await phone.habit(type: 'duration', target: 600);

    await phone.writer.startTimer(yoga);
    phone.now = phone.now.add(const Duration(minutes: 4));
    expect((await phone.writer.finishTimer(yoga))!.completeAfter, isFalse);

    await phone.writer.startTimer(yoga);
    phone.now = phone.now.add(const Duration(minutes: 6));
    expect((await phone.writer.finishTimer(yoga))!.completeAfter, isTrue);
  });

  test('a delete never says complete', () async {
    final water = await phone.habit(type: 'quantity', target: '2000.000');
    await phone.writer.setLogValue(habitId: water, value: '2000.000');
    final today = (await phone.writer.setLogValue(habitId: water, value: '2000.000')).date;

    expect((await phone.writer.deleteLog(habitId: water, date: today)).completeAfter, isFalse);
  });
}
