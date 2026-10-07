import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/sync/http_sync_transport.dart';
import 'package:habit/sync/sync_transport.dart';

import '../support/route_adapter.dart';

void main() {
  late RouteAdapter http;
  late HttpSyncTransport transport;

  setUp(() {
    http = RouteAdapter();
    transport = HttpSyncTransport(
      Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http,
    );
  });

  Future<SyncPage> push() => transport.sync(
    deviceId: 'd',
    cursor: 'c:1',
    pullLimit: 50,
    mutations: const [
      {'mutation_id': 'm1'},
    ],
    capabilities: const ['binary', 'quantity'],
  );

  test('POST /sync sends the batch and the capability header; parses acks and changes', () async {
    http.on(
      'POST /sync',
      Reply(
        200,
        envelope({
          'acks': [
            {'mutation_id': 'm1', 'status': 'accepted'},
          ],
          'changes': [],
          'next_cursor': 'c:2',
          'has_more': true,
        }),
      ),
    );

    final page = await push();

    final sent = http.sent('POST /sync').single;
    expect(sent.headers['X-Capabilities'], 'type.binary,type.quantity');
    expect(jsonDecode(jsonEncode(sent.data)), {
      'device_id': 'd',
      'cursor': 'c:1',
      'pull_limit': 50,
      'mutations': [
        {'mutation_id': 'm1'},
      ],
    });
    expect((page.acks.single['status'], page.nextCursor, page.hasMore), ('accepted', 'c:2', true));
    expect(page.serverTime, DateTime.utc(2026, 5, 28, 10), reason: 'meta.server_time (F10)');
  });

  test('GET /sync/bootstrap omits a null cursor and keeps unknown collections', () async {
    http.on(
      'GET /sync/bootstrap',
      Reply(
        200,
        envelope({
          'habits': [],
          'logs': [],
          'routines': [
            {'id': 'r1'},
          ],
          'entities': [
            {'entity': 'routine', 'id': 'r2', 'version': 1, 'payload': <String, Object>{}},
          ],
          'has_more': false,
          'sync_cursor': 'c:9',
        }),
      ),
    );

    final page = await transport.bootstrap(cursor: null, limit: 100);

    expect(http.requests.single.queryParameters, {'limit': 100});
    expect(page.syncCursor, 'c:9');
    expect(page.unknownCollections.keys, ['routines']);
    expect(page.entities.single['entity'], 'routine', reason: 'A31');
  });

  test('a whole-request 4xx carries the server code (F7)', () async {
    http.on('POST /sync', Reply(403, errorEnvelope('forbidden')));
    await expectLater(
      push(),
      throwsA(
        isA<SyncTransportException>()
            .having((e) => e.kind, 'kind', SyncFailure.requestRejected)
            .having((e) => e.code, 'code', 'forbidden'),
      ),
    );
  });

  final cases = <(Reply, SyncFailure, Duration?)>[
    (Reply(401, errorEnvelope('unauthenticated')), SyncFailure.unauthorized, null),
    (Reply(410, errorEnvelope('cursor_expired')), SyncFailure.cursorExpired, null),
    (Reply(413, errorEnvelope('payload_too_large')), SyncFailure.payloadTooLarge, null),
    (
      Reply(429, errorEnvelope('rate_limited'), {
        'retry-after': ['42'],
      }),
      SyncFailure.rateLimited,
      const Duration(seconds: 42),
    ),
    (Reply(503, errorEnvelope('maintenance')), SyncFailure.server, null),
    (Reply(422, errorEnvelope('validation_failed')), SyncFailure.requestRejected, null),
    (const Reply(404, '<html>not found</html>'), SyncFailure.requestRejected, null),
    (const Reply.offline(), SyncFailure.network, null),
    (const Reply(200, '<html>captive portal</html>'), SyncFailure.network, null),
  ];
  for (final (reply, kind, retryAfter) in cases) {
    test('HTTP ${reply.status} maps to $kind', () async {
      http.on('POST /sync', reply);
      await expectLater(
        push(),
        throwsA(
          isA<SyncTransportException>()
              .having((e) => e.kind, 'kind', kind)
              .having((e) => e.retryAfter, 'retryAfter', retryAfter),
        ),
      );
    });
  }
}
