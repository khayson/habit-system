import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/account_calendar.dart';
import 'package:habit/data/entity_codec.dart';

import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 3.2a: the A32 entities in their typed tables, and calendar_history merged into
/// calendar_entries (A26, D1).
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
    await phone.sync();
  });

  tearDown(() => phone.db.close());

  Map<String, dynamic> entry(String at, String zone) => {
    'effective_at': at,
    'timezone': zone,
    'day_start_offset_minutes': 0,
  };

  Future<List<String>> entries() async => [
    for (final e in await phone.db.select(phone.db.calendarEntries).get())
      '${DateTime.fromMillisecondsSinceEpoch(e.effectiveAt, isUtc: true).toIso8601String()} '
          '${e.timezone}',
  ];

  Future<void> publish(List<Map<String, dynamic>> history) async {
    server.journalUser({
      'id': 'user-1',
      'timezone': 'America/Los_Angeles',
      'day_start_offset_minutes': 0,
      'calendar_history': history,
    });
    await phone.sync();
  }

  group('calendar_history', () {
    test('a pending change is replaced, then cancelled; settled entries stay', () async {
      await publish([
        entry('2026-01-01T00:00:00Z', 'America/Los_Angeles'),
        entry('2026-05-29T07:00:00Z', 'Europe/Paris'),
      ]);
      expect(await entries(), [
        '2026-01-01T00:00:00.000Z America/Los_Angeles',
        '2026-05-29T07:00:00.000Z Europe/Paris',
      ]);

      await publish([
        entry('2026-01-01T00:00:00Z', 'America/Los_Angeles'),
        entry('2026-05-29T07:00:00Z', 'Asia/Tokyo'),
      ]);
      expect(await entries(), [
        '2026-01-01T00:00:00.000Z America/Los_Angeles',
        '2026-05-29T07:00:00.000Z Asia/Tokyo',
      ], reason: 'replaced');

      // Cancelled; and a server list that no longer reaches the oldest settled entry.
      await publish([entry('2026-03-01T08:00:00Z', 'America/Los_Angeles')]);
      expect(await entries(), [
        '2026-01-01T00:00:00.000Z America/Los_Angeles',
        '2026-03-01T08:00:00.000Z America/Los_Angeles',
      ], reason: 'pending gone, settled entries never deleted');
    });

    test('settled entries older than 120 days are pruned to the newest of them', () async {
      // Today is 28 May 2026, so the cut-off is 28 January.
      await publish([
        entry('2025-06-01T00:00:00Z', 'Europe/London'),
        entry('2025-09-01T00:00:00Z', 'America/New_York'),
        entry('2026-01-01T00:00:00Z', 'America/Los_Angeles'),
        entry('2026-03-01T08:00:00Z', 'America/Denver'),
      ]);

      expect(await entries(), [
        '2026-01-01T00:00:00.000Z America/Los_Angeles', // newest of the old ones: still governs
        '2026-03-01T08:00:00.000Z America/Denver',
      ]);
    });

    test('a pending change takes effect at its boundary without a sync', () async {
      await publish([
        entry('2026-01-01T00:00:00Z', 'America/Los_Angeles'),
        entry('2026-05-29T07:00:00Z', 'Europe/Paris'),
      ]);
      final calendar = (await AccountCalendar.load(phone.db, deviceNow: phone.now))!;

      final before = DateTime.utc(2026, 5, 29, 6, 59);
      final after = DateTime.utc(2026, 5, 29, 7, 0);
      expect(
        (calendar.zoneNow(before), calendar.today(before).toString()),
        ('America/Los_Angeles', '2026-05-28'),
      );
      expect(
        (calendar.zoneNow(after), calendar.today(after).toString(), calendar.localNow(after).hour),
        ('Europe/Paris', '2026-05-29', 9),
      );
      expect(calendar.pendingAfter(before)?.timezone, 'Europe/Paris');
      expect(calendar.pendingAfter(after), isNull);
    });

    test('an invalid history falls back to its settled entries and says so', () async {
      // Auckland -> Los Angeles at an arbitrary instant moves dates backwards (D1).
      await publish([
        entry('2026-01-01T00:00:00Z', 'Pacific/Auckland'),
        entry('2026-03-10T12:00:00Z', 'America/Los_Angeles'),
      ]);
      final calendar = await AccountCalendar.load(phone.db, deviceNow: DateTime.utc(2026, 3, 1));

      expect(calendar!.zoneNow(DateTime.utc(2026, 3, 1)), 'Pacific/Auckland');
      expect((await phone.state()).lastError, contains('calendar_invalid'));
    });

    test('without calendar_history the single entry from the user entity is used', () async {
      await phone.db.close();
      server = FakeSyncServer()..sendCalendarHistory = false;
      phone = await Device(server).init();
      await phone.sync();
      final calendar = await AccountCalendar.load(phone.db, deviceNow: phone.now);
      expect(await entries(), isEmpty);
      expect(calendar!.zoneNow(phone.now), 'America/Los_Angeles');
    });
  });

  group('A32 entities', () {
    Map<String, dynamic> progress(int current) => {
      'habit_id': 'h1',
      'current': current,
      'longest': 5,
      'unit': 'days',
      'computed_through': '2026-05-27',
      'colour': 'teal',
    };

    test('habit_progress follows the version rule, keeps unknown fields, goes on delete', () async {
      server.journalEntity('habit_progress', 'h1', 3, progress(3));
      await phone.sync();
      server.journalEntity('habit_progress', 'h1', 2, progress(2)); // older: ignored
      await phone.sync();

      final row = await phone.db.select(phone.db.habitProgress).getSingle();
      expect((row.current, row.version), (3, 3));
      expect(EntityCodec.progressPayload(row)['colour'], 'teal');

      server.journalEntity('habit_progress', 'h1', 4, progress(3), operation: 'delete');
      await phone.sync();
      expect(await phone.db.select(phone.db.habitProgress).get(), isEmpty);
    });

    test('a newer period_evaluation revision replaces the older one', () async {
      Map<String, dynamic> evaluation(bool completed, int revision) => {
        'id': 'e1',
        'habit_id': 'h1',
        'period_key': 'd:2026-05-27',
        'start_date': '2026-05-27',
        'end_date': '2026-05-27',
        'completed': completed,
        'protected': false,
        'definition_version': 1,
        'timezone': 'America/Los_Angeles',
        'revision': revision,
      };
      server.journalEntity('period_evaluation', 'e1', 1, evaluation(false, 1));
      await phone.sync();
      server.journalEntity('period_evaluation', 'e1', 2, evaluation(true, 2));
      await phone.sync();

      final row = await phone.db.select(phone.db.periodEvaluations).getSingle();
      expect((row.completed, row.revision), (true, 2));
    });
  });
}
