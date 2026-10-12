import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:path/path.dart' as p;

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

import 'dart:io';

/// Phase 4.3a Part B: timer drafts (A36). Local only; finishing queues one log.increment.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;
  late String yoga;

  Future<String> habit(String type, {Object target = 600}) => phone.writer.createHabitUnchecked(
    name: type,
    type: type,
    target: target,
    category: 'health',
    startLocalDate: LocalDate.parse('2026-05-01'),
    backdate: true,
  );

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    yoga = await habit('duration');
    await phone.sync(force: true);
  });
  tearDown(() => phone.db.close());

  void advance(Duration d) => phone.now = phone.now.add(d);

  Matcher failure(TimerFailureKind kind) =>
      throwsA(isA<TimerFailure>().having((f) => f.kind, 'kind', kind));

  Future<List<Map<String, dynamic>>> increments() async => [
    for (final r in await phone.outbox())
      if (r.operation == 'log.increment') jsonDecode(r.payload) as Map<String, dynamic>,
  ];

  test('B2: only duration supports a timer', () {
    expect(
      {for (final r in ProvisionalTypeRegistry.builtins().all) r.key: r.supportsTimer},
      {'binary': false, 'quantity': false, 'duration': true},
    );
  });

  test('B4: start, pause, resume, finish queues whole seconds and removes the draft', () async {
    await phone.writer.startTimer(yoga);
    advance(const Duration(seconds: 90, milliseconds: 400));
    await phone.writer.pauseTimer(yoga);
    advance(const Duration(minutes: 10)); // paused: not counted
    await phone.writer.resumeTimer(yoga);
    advance(const Duration(seconds: 30, milliseconds: 900));
    final draft = (await phone.writer.watchTimer(yoga).first)!;
    expect(
      (draft.state, draft.elapsed(phone.now)),
      ('running', const Duration(milliseconds: 121300)),
    );

    final write = await phone.writer.finishTimer(yoga);
    expect(write, isNotNull);
    expect(await increments(), [
      {'habit_id': yoga, 'delta': 121},
    ]);
    expect(await phone.writer.watchTimer(yoga).first, isNull);
    await phone.sync(force: true);
    expect(server.logs.values.single['value'], 121);
  });

  test('B3: start is idempotent; pause and resume are idempotent', () async {
    final a = await phone.writer.startTimer(yoga);
    advance(const Duration(seconds: 5));
    final b = await phone.writer.startTimer(yoga);
    expect((b.createdAt, b.runningSince), (a.createdAt, a.runningSince), reason: 'unchanged');
    await phone.writer.pauseTimer(yoga);
    final paused = await phone.writer.pauseTimer(yoga);
    expect((paused.state, paused.elapsedMs), ('paused', 5000));
    advance(const Duration(seconds: 3));
    await phone.writer.resumeTimer(yoga);
    final running = await phone.writer.resumeTimer(yoga);
    expect((running.state, running.runningSince), ('running', phone.now.millisecondsSinceEpoch));
  });

  test('B4: zero elapsed writes nothing and removes the draft', () async {
    await phone.writer.startTimer(yoga);
    advance(const Duration(milliseconds: 999));
    expect(await phone.writer.finishTimer(yoga), isNull);
    expect(await increments(), isEmpty);
    expect(await phone.writer.watchTimer(yoga).first, isNull);
  });

  test('B4: a clock set backwards never shrinks elapsed', () async {
    await phone.writer.startTimer(yoga);
    advance(const Duration(seconds: 40));
    await phone.writer.pauseTimer(yoga);
    await phone.writer.resumeTimer(yoga);
    advance(const Duration(hours: -2));
    final draft = (await phone.writer.watchTimer(yoga).first)!;
    expect(draft.elapsed(phone.now), const Duration(seconds: 40));
    advance(const Duration(hours: 2, seconds: 5));
    expect(draft.elapsed(phone.now), const Duration(seconds: 45));
  });

  test('B4: over a day\'s limit the draft stays and finish says tooLong', () async {
    await phone.writer.startTimer(yoga);
    advance(const Duration(hours: 25, seconds: 1));
    await expectLater(phone.writer.finishTimer(yoga), failure(TimerFailureKind.tooLong));
    expect(await phone.writer.watchTimer(yoga).first, isNotNull);
    expect(await increments(), isEmpty);
  });

  test('B4: a refused increment (the day would pass its limit) leaves the draft', () async {
    await phone.writer.setLogValue(habitId: yoga, value: 25 * 3600 - 10);
    await phone.writer.startTimer(yoga);
    advance(const Duration(seconds: 20));
    await expectLater(phone.writer.finishTimer(yoga), throwsA(isA<LogFailure>()));
    expect(await phone.writer.watchTimer(yoga).first, isNotNull);
    expect(await increments(), isEmpty);
  });

  test('B3: no timer for other types, archived habits, or without a draft', () async {
    final water = await habit('quantity', target: '2.000');
    await expectLater(phone.writer.startTimer(water), failure(TimerFailureKind.notSupported));
    await expectLater(phone.writer.pauseTimer(yoga), failure(TimerFailureKind.noDraft));
    await expectLater(phone.writer.finishTimer(yoga), failure(TimerFailureKind.noDraft));
    await phone.writer.archiveHabit(yoga);
    await expectLater(phone.writer.startTimer(yoga), failure(TimerFailureKind.archived));
  });

  test('B4: the app killed while running still counts the running span', () async {
    final dir = Directory.systemTemp.createTempSync('habit_timer_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may hold the file briefly.
      }
    });
    final file = File(p.join(dir.path, 'account.sqlite'));
    final first = await Device(server, executor: NativeDatabase(file)).init();
    final id = await first.writer.createHabitUnchecked(
      name: 'Yoga',
      type: 'duration',
      target: 600,
      category: 'health',
      startLocalDate: LocalDate.parse('2026-05-01'),
      backdate: true,
    );
    await first.writer.startTimer(id);
    await first.db.close();

    final reopened = Device(server, executor: NativeDatabase(file));
    addTearDown(reopened.db.close);
    reopened.now = first.now.add(const Duration(minutes: 3));
    final draft = (await reopened.writer.watchTimer(id).first)!;
    expect((draft.state, draft.elapsed(reopened.now)), ('running', const Duration(minutes: 3)));
  });

  test('B5: a draft belongs to its account', () async {
    await phone.writer.startTimer(yoga);
    final other = await Device(FakeSyncServer()).init();
    addTearDown(other.db.close);
    expect(await other.writer.watchTimer(yoga).first, isNull);
    expect(await other.db.select(other.db.timerDrafts).get(), isEmpty);
  });

  test('L2 (4.3b review): pause works on an archived habit and keeps the time', () async {
    await phone.writer.startTimer(yoga);
    advance(const Duration(seconds: 40));
    await phone.writer.archiveHabit(yoga);
    final paused = await phone.writer.pauseTimer(yoga);
    expect((paused.state, paused.elapsedMs), ('paused', 40000));
    await expectLater(phone.writer.resumeTimer(yoga), failure(TimerFailureKind.archived));
  });
}
