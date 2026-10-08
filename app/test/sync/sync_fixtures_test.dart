import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// The Dart half of contract-fixtures/sync/*.json (A29): each fixture ack goes through the
/// real engine and must leave the outbox in the state the contract implies.
void main() {
  setUpAll(Device.loadZones);

  /// Answers the next push with the fixture ack (its mutation_id bound to the row actually sent).
  Future<Device> runWithAck(String fixture) async {
    final server = FakeSyncServer();
    final phone = await Device(server).init();
    final habit = await phone.habit();
    await phone.sync();
    await phone.writer.setLogValue(habitId: habit, value: 1);
    final ack =
        materialize(contractFixture('sync/$fixture.json')['expect']) as Map<String, dynamic>;
    await phone.engine(transport: _AckOnce(server, ack)).run();
    return phone;
  }

  for (final name in [
    'ack_server_error',
    'ack_restored',
    'ack_merged_entity_id',
    'ack_delete_natural_key',
  ]) {
    test('$name declares the Dart suite', () {
      expect(contractFixture('sync/$name.json')['suites'], contains('dart'));
    });
  }

  test('ack_server_error: blocked with backoff; retryable lives inside error', () async {
    final phone = await runWithAck('ack_server_error');
    final row = (await phone.outbox()).single;

    expect(row.state, OutboxState.blocked);
    expect(row.attempts, 1);
    expect(row.nextAttemptAt, greaterThan(phone.now.millisecondsSinceEpoch));
    final error = jsonDecode(row.lastError!) as Map<String, dynamic>;
    expect((error['code'], error['retryable']), ('server_error', true));
  });

  test('bootstrap_entities: the derived entities land in their typed tables (A31, A32)', () async {
    final fixture = contractFixture('sync/bootstrap_entities.json');
    expect(fixture['suites'], contains('dart'));
    final server = FakeSyncServer();
    final phone = await Device(server).init();
    final pages = [
      BootstrapPage.fromJson({
        'user': server.user,
        'habits': <Object>[],
        'logs': <Object>[],
        'has_more': true,
        'next_cursor': 'first',
      }),
      BootstrapPage.fromJson(materialize(fixture['progress_page']) as Map<String, dynamic>),
      BootstrapPage.fromJson(materialize(fixture['evaluation_page']) as Map<String, dynamic>),
    ];

    final outcome = await phone.engine(transport: _BootstrapPages(server, pages)).run();

    expect(outcome, SyncOutcome.completed);
    expect(await phone.db.select(phone.db.opaqueEntities).get(), isEmpty);
    final progress = await phone.db.select(phone.db.habitProgress).getSingle();
    expect((progress.current, progress.longest, progress.version), (1, 1, 2));
    final evaluation = await phone.db.select(phone.db.periodEvaluations).getSingle();
    expect(
      (evaluation.periodKey, evaluation.completed, evaluation.revision),
      ('d:2026-05-27', true, 1),
    );
    expect((await phone.state()).cursor, isNotNull, reason: 'the snapshot cursor was saved');
    await phone.db.close();
  });

  test('log_backdate_payload: a past check-in sends date_mode backdate and log_date', () async {
    final fixture = contractFixture('sync/log_backdate_payload.json');
    expect(fixture['suites'], contains('dart'));
    final phone = await Device(FakeSyncServer()).init();
    phone.now = DateTime.parse(fixture['now'] as String);
    final habit = await phone.writer.createHabit(
      name: 'Meditation',
      type: 'binary',
      target: 1,
      category: 'mindful',
      startLocalDate: LocalDate.parse(fixture['habit_start_local_date'] as String),
    );
    final expected = fixture['mutation'] as Map<String, dynamic>;
    final payload = expected['payload'] as Map<String, dynamic>;

    await phone.writer.setLogValue(
      habitId: habit,
      value: payload['value'] as Object,
      logDate: LocalDate.parse(payload['log_date'] as String),
    );

    final row = (await phone.outbox()).last;
    final wire = {
      'mutation_id': row.mutationId,
      'entity': row.entity,
      'entity_id': row.entityId,
      'operation': row.operation,
      'base_version': row.baseVersion,
      'occurred_at': row.occurredAt,
      'captured_timezone': row.capturedTimezone,
      'local_date_hint': row.localDateHint,
      'payload': jsonDecode(row.payload),
    };
    expectContract(expected, wire);
    expect((wire['payload'] as Map)['habit_id'], habit);
    await phone.db.close();
  });

  test('a past check-in the server would refuse writes nothing', () async {
    final phone = await Device(FakeSyncServer()).init();
    final habit = await phone.habit();
    final before = (await phone.outbox()).length;
    for (final date in ['2026-05-29', '2026-04-27']) {
      await expectLater(
        phone.writer.setLogValue(habitId: habit, value: 1, logDate: LocalDate.parse(date)),
        throwsA(isA<DayResolutionException>()),
      );
    }
    expect((await phone.outbox()).length, before);
    await phone.db.close();
  });

  for (final name in ['ack_restored', 'ack_merged_entity_id', 'ack_delete_natural_key']) {
    test('$name: accepted and remapped to the canonical entity_id', () async {
      final phone = await runWithAck(name);
      final expected =
          materialize(contractFixture('sync/$name.json')['expect']) as Map<String, dynamic>;
      final row = (await phone.outbox()).single;

      expect(row.state, OutboxState.acked);
      expect(row.ackVersion, expected['version']);
      expect(row.entityId, expected['entity_id'], reason: 'the ack id is canonical (A29)');
    });
  }
}

/// [expected] with placeholders matched by format ({{uuid}}, {{timestamp}}), the rest exactly.
void expectContract(Object? expected, Object? actual, [String path = r'$']) {
  switch (expected) {
    case '{{uuid}}':
      expect(
        actual,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
        reason: path,
      );
    case '{{timestamp}}':
      expect(
        actual,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$')),
        reason: path,
      );
    case final Map<String, dynamic> map:
      expect(actual, isA<Map<dynamic, dynamic>>(), reason: path);
      expect((actual! as Map).keys.toSet(), map.keys.toSet(), reason: '$path keys');
      for (final e in map.entries) {
        expectContract(e.value, (actual as Map)[e.key], '$path.${e.key}');
      }
    default:
      expect(actual, expected, reason: path);
  }
}

/// Returns [ack] (bound to the first sent mutation) for one push; otherwise the fake server.
class _AckOnce implements SyncTransport {
  _AckOnce(this.server, this.ack);

  final FakeSyncServer server;
  final Map<String, dynamic> ack;
  var _used = false;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    if (_used || mutations.isEmpty) {
      return server.sync(
        deviceId: deviceId,
        cursor: cursor,
        pullLimit: pullLimit,
        mutations: mutations,
        capabilities: capabilities,
      );
    }
    _used = true;
    return SyncPage(
      acks: [
        {...ack, 'mutation_id': mutations.first['mutation_id']},
      ],
      changes: const [],
      nextCursor: cursor ?? 'c:0',
      hasMore: false,
    );
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      server.bootstrap(cursor: cursor, limit: limit);
}

/// Serves [pages] as the bootstrap, then defers /sync to the fake server from a fresh cursor.
class _BootstrapPages implements SyncTransport {
  _BootstrapPages(this.server, this.pages);
  final FakeSyncServer server;
  final List<BootstrapPage> pages;
  var _next = 0;

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) => server.sync(
    deviceId: deviceId,
    cursor: 'c:0',
    pullLimit: pullLimit,
    mutations: mutations,
    capabilities: capabilities,
  );

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) async =>
      pages[_next++];
}
