import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/services/rewards_service.dart';

import '../core/api_client_test.dart' show CannedAdapter, MemoryTokenStore;
import '../support/contract_fixtures.dart';

/// Phase 5.2b: GET /rewards and GET /freezes on the app (contract-fixtures/rewards/
/// rewards_response.json and freezes_response.json). Read-only; tolerant of unknown words.
void main() {
  Map<String, dynamic> envelope(Object? data) => {
    'data': data,
    'meta': {'api_version': '1', 'server_time': '2026-05-28T17:22:00Z', 'request_id': 'r1'},
  };

  (RewardsService, CannedAdapter) service(Object body, {int status = 200}) {
    final adapter = CannedAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
    return (RewardsService(ApiClient.withDio(dio, MemoryTokenStore('t'))), adapter);
  }

  Map<String, dynamic> rewardsData() =>
      materialize(contractFixture('rewards/rewards_response.json')['response']['data'])
          as Map<String, dynamic>;
  Map<String, dynamic> freezesData() =>
      materialize(contractFixture('rewards/freezes_response.json')['response']['data'])
          as Map<String, dynamic>;

  group('rewards_response', () {
    test('declares the Dart suite and decodes into a typed page', () async {
      expect(contractFixture('rewards/rewards_response.json')['suites'], contains('dart'));
      final data = rewardsData();
      final (rewards, adapter) = service(envelope(data));

      final page = await rewards.fetchRewards();

      expect(adapter.lastRequest!.path, '/rewards');
      expect(adapter.lastRequest!.queryParameters, {'limit': 20});
      final entry = page.ledger.single;
      final wire = (data['ledger'] as List).single as Map<String, dynamic>;
      expect(
        (entry.id, entry.delta, entry.reason, entry.habitId, entry.logDate),
        (wire['id'], 10, 'completion', wire['habit_id'], '2026-05-28'),
      );
      expect(entry.createdAt, DateTime.utc(2026, 5, 28, 17, 22));
      expect(page.nextCursor, data['next_cursor']);
    });

    test('sends the cursor and limit; keeps an unknown reason; ignores extra fields', () async {
      final data = rewardsData();
      final ledger = (data['ledger'] as List).cast<Map<String, dynamic>>();
      data['ledger'] = [
        {...ledger.single, 'reason': 'streak_bonus', 'colour': 'teal'},
      ];
      data['next_cursor'] = null;
      final (rewards, adapter) = service(envelope({...data, 'season': 3}));

      final page = await rewards.fetchRewards(cursor: 'abc', limit: 5);

      expect(adapter.lastRequest!.queryParameters, {'limit': 5, 'cursor': 'abc'});
      expect(page.ledger.single.reason, 'streak_bonus');
      expect(page.nextCursor, isNull);
    });

    for (final (what, mutate) in <(String, void Function(Map<String, dynamic>))>[
      ('a missing delta', (e) => e.remove('delta')),
      ('a string delta', (e) => e['delta'] = '10'),
      ('a bad created_at', (e) => e['created_at'] = 'yesterday'),
    ]) {
      test('$what is unexpected_response', () async {
        final data = rewardsData();
        mutate(((data['ledger'] as List).single as Map).cast<String, dynamic>());
        final (rewards, _) = service(envelope(data));

        await expectLater(
          rewards.fetchRewards(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'unexpected_response')
                .having((e) => e.kind, 'kind', AppErrorKind.unexpected),
          ),
        );
      });
    }
  });

  group('freezes_response', () {
    test('declares the Dart suite and decodes the wallet and its history', () async {
      expect(contractFixture('rewards/freezes_response.json')['suites'], contains('dart'));
      final data = freezesData();
      final (rewards, adapter) = service(envelope(data));

      final page = await rewards.fetchFreezes();

      expect(adapter.lastRequest!.path, '/freezes');
      expect(
        (page.freezeBalance, page.cap, page.autoFreeze, page.nextRefillOn),
        (1, 2, true, '2026-06-01'),
      );
      expect(page.ledger.map((e) => (e.kind, e.delta, e.reason, e.periodKey)), [
        ('spend', -1, 'missed_period', 'd:2026-05-27'),
        ('grant', 2, 'signup', null),
      ]);
      expect(page.ledger.last.habitId, isNull);
      expect(page.nextCursor, data['next_cursor']);
    });

    test('keeps an unknown kind and reason as strings', () async {
      final data = freezesData();
      final first = ((data['ledger'] as List).first as Map).cast<String, dynamic>();
      first['kind'] = 'gift';
      first['reason'] = 'birthday';

      final page = await service(envelope(data)).$1.fetchFreezes();

      expect((page.ledger.first.kind, page.ledger.first.reason), ('gift', 'birthday'));
    });

    test('a wrong-typed cap is unexpected_response', () async {
      final data = freezesData()..['cap'] = 'two';

      await expectLater(
        service(envelope(data)).$1.fetchFreezes(),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'unexpected_response')),
      );
    });
  });

  test('an API error passes through unchanged', () async {
    final (rewards, _) = service({
      'error': {'code': 'validation_failed', 'message': 'This cursor is not valid.'},
      'meta': {'request_id': 'r2'},
    }, status: 422);

    await expectLater(
      rewards.fetchRewards(cursor: 'bad'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'validation_failed')),
    );
  });
}
