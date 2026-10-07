import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/sync/outbox_states.dart';
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
