import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/reminder_view.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// The Dart half of contract-fixtures/sync/reminder_mutations.json and reminder_entity.json
/// (Phase 3.2b): the writer builds the mutations the server takes, the engine keeps reminders
/// typed, tombstones included, and the overlay shows what this device intends.
void main() {
  setUpAll(Device.loadZones);

  final mutations = contractFixture('sync/reminder_mutations.json');
  final entity = contractFixture('sync/reminder_entity.json');

  test('both fixtures declare the Dart suite', () {
    expect(mutations['suites'], contains('dart'));
    expect(entity['suites'], contains('dart'));
  });

  Map<String, Object?> wire(dynamic row) => {
    'mutation_id': row.mutationId,
    'entity': row.entity,
    'entity_id': row.entityId,
    'operation': row.operation,
    'base_version': row.baseVersion,
    'occurred_at': row.occurredAt,
    'captured_timezone': row.capturedTimezone,
    'local_date_hint': row.localDateHint,
    'payload': jsonDecode(row.payload as String),
  };

  test('create, update and delete go out exactly as the fixture says, and are acked', () async {
    final server = FakeSyncServer();
    final phone = await Device(server).init();
    phone.now = DateTime.parse(mutations['now'] as String);
    final habit = await phone.habit();
    await phone.sync();

    Future<void> step(String name, Future<void> Function() write) async {
      await write();
      final row = (await phone.outbox()).last;
      final expected = (mutations[name] as Map)['mutation'] as Map<String, dynamic>;
      expectContract(expected, wire(row), name);
      await phone.engine(transport: _Recording(server)).run();
      expectContract((mutations[name] as Map)['expect'], _Recording.lastAck, '$name ack');
    }

    late String id;
    final create = (mutations['create'] as Map)['mutation']['payload'] as Map<String, dynamic>;
    await step('create', () async {
      id = await phone.writer.createReminder(
        habitId: habit,
        localTime: create['local_time'] as String,
        daysOfWeek: (create['days_of_week'] as List).cast<int>(),
      );
    });
    final update = (mutations['update'] as Map)['mutation']['payload'] as Map<String, dynamic>;
    await step(
      'update',
      () => phone.writer.updateReminder(
        reminderId: id,
        localTime: update['local_time'] as String,
        daysOfWeek: (update['days_of_week'] as List).cast<int>(),
        timezoneMode: update['timezone_mode'] as String,
      ),
    );
    await step('delete', () => phone.writer.deleteReminder(id));

    final row = await phone.db.select(phone.db.reminders).getSingle();
    expect((row.version, row.deletedAt != null), (3, true), reason: 'the tombstone is kept');
    expect(await phone.outbox(), isEmpty, reason: 'acked and reflected: pruned');
    expect(await phone.view.reminders(), isEmpty);
    await phone.db.close();
  });

  test('the entity fixture lands typed; the tombstone hides it', () async {
    final server = FakeSyncServer();
    final phone = await Device(server).init();
    await phone.sync();
    final change = materialize(entity['change']) as Map<String, dynamic>;
    final payload = change['payload'] as Map<String, dynamic>;
    server.journalEntity('reminder', change['id'] as String, 1, payload);
    await phone.sync();

    final shown = (await phone.view.reminders()).single;
    expect(
      [shown.localTime, shown.daysOfWeek, shown.timezoneMode, shown.enabled],
      ['08:00', [1, 2, 3, 4, 5], 'habit_zone', true],
    );

    final tombstone = materialize(entity['tombstone']) as Map<String, dynamic>;
    server.journalEntity(
      'reminder',
      change['id'] as String,
      3,
      tombstone['payload'] as Map<String, dynamic>,
      operation: 'delete',
    );
    await phone.sync();
    expect((await phone.db.select(phone.db.reminders).getSingle()).deletedAt, isNotNull);
    expect(await phone.view.reminders(), isEmpty);
    await phone.db.close();
  });

  test('unsent edits coalesce into the create; the overlay shows them at once', () async {
    final phone = await Device(FakeSyncServer()).init();
    final habit = await phone.habit();
    final id = await phone.writer.createReminder(
      habitId: habit,
      localTime: '08:00',
      daysOfWeek: [5, 1],
    );
    await phone.writer.updateReminder(reminderId: id, localTime: '09:15', daysOfWeek: [2]);

    final rows = await phone.outbox();
    final reminderRows = rows.where((r) => r.entity == 'reminder').toList();
    expect(reminderRows.single.operation, 'reminder.create');
    expect(jsonDecode(reminderRows.single.payload)['local_time'], '09:15');
    final view = (await phone.view.reminders()).single;
    expect([view.localTime, view.daysOfWeek, view.provisional], ['09:15', [2], true]);
    expect(reminderRows.single.state, OutboxState.pending);
    await phone.db.close();
  });
}

/// Passes through to the fake server and keeps the last ack it returned.
class _Recording implements SyncTransport {
  _Recording(this.server);
  final FakeSyncServer server;
  static Map<String, dynamic>? lastAck;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    final page = await server.sync(
      deviceId: deviceId,
      cursor: cursor,
      pullLimit: pullLimit,
      mutations: mutations,
      capabilities: capabilities,
    );
    if (page.acks.isNotEmpty) lastAck = page.acks.last;
    return page;
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}
