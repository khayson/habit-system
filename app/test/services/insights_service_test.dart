import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/models/insights.dart';
import 'package:habit/services/insights_service.dart';

import '../core/api_client_test.dart' show CannedAdapter, MemoryTokenStore;
import '../support/contract_fixtures.dart';

/// Phase 5.3a (A47): GET /insights on the app, decoded from contract-fixtures/insights/
/// insights_responses.json. The app displays what the server sent and computes no rule.
void main() {
  final fixture = contractFixture('insights/insights_responses.json');
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> envelope(Object? data) => {
    'data': data,
    'meta': {'api_version': '1', 'server_time': '2026-05-28T20:00:00Z', 'request_id': 'r1'},
  };

  (InsightsService, CannedAdapter) service(Object body, {int status = 200}) {
    final adapter = CannedAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
    return (InsightsService(ApiClient.withDio(dio, MemoryTokenStore('t'))), adapter);
  }

  test('insights_responses declares the Dart suite', () {
    expect(fixture['suites'], contains('dart'));
  });

  for (final c in cases) {
    test('decodes: ${c['name']}', () async {
      final expect_ = (c['expect'] as Map).cast<String, dynamic>();
      final query = (c['query'] as Map).cast<String, dynamic>();
      final (insights, adapter) = service(envelope(expect_));

      final result = await insights.fetch(
        query['period'] as String,
        category: query['category'] as String?,
      );

      expect(adapter.lastRequest!.path, '/insights');
      expect(adapter.lastRequest!.queryParameters, query);
      final window = (expect_['window'] as Map).cast<String, dynamic>();
      final totals = (expect_['totals'] as Map).cast<String, dynamic>();
      expect((result.period, result.category), (expect_['period'], expect_['category']));
      expect(
        (result.window.start, result.window.end, result.window.today, result.window.through),
        (window['start'], window['end'], window['today'], window['through']),
      );
      expect(
        (result.totals.completed, result.totals.eligible, result.totals.percent),
        (totals['completed'], totals['eligible'], totals['percent']),
      );
      expect(result.xpEarned, expect_['xp_earned']);
      expect(
        [for (final r in result.byCategory) (r.category, r.completed, r.eligible, r.percent)],
        [
          for (final r in (expect_['by_category'] as List).cast<Map<String, dynamic>>())
            (r['category'], r['completed'], r['eligible'], r['percent']),
        ],
      );
      final days = expect_['days'] as List?;
      expect(result.days?.length, days?.length);
      if (days != null) {
        for (var i = 0; i < days.length; i++) {
          final d = (days[i] as Map).cast<String, dynamic>();
          final got = result.days![i];
          expect(
            (got.date, got.completed, got.due, got.open),
            (d['date'], d['completed'], d['due'], d['open']),
          );
        }
      }
      expect(
        [for (final o in result.openPeriods ?? <OpenPeriod>[]) (o.habitId, o.completed, o.target)],
        [
          for (final o in (expect_['open_periods'] as List? ?? []).cast<Map<String, dynamic>>())
            (o['habit_id'], o['completed'], o['target']),
        ],
      );
      expect(
        insights.last(query['period'] as String, category: query['category'] as String?),
        same(result),
      );
    });
  }

  test('the empty window keeps percent null, never 0', () async {
    final empty = cases.firstWhere((c) => (c['name'] as String).startsWith('empty'));
    final result = await service(envelope(empty['expect'])).$1.fetch('week');
    expect(result.totals.percent, isNull);
    expect(result.byCategory, isEmpty);
  });

  test('extra fields are ignored; an unknown category word is kept', () async {
    final body = (cases[1]['expect'] as Map).cast<String, dynamic>();
    final data = {
      ...body,
      'season': 3,
      'by_category': [
        {'category': 'fitness', 'completed': 1, 'eligible': 2, 'percent': 50, 'colour': 'teal'},
      ],
    };
    final result = await service(envelope(data)).$1.fetch('month');
    expect(result.byCategory.single.category, 'fitness');
  });

  for (final (what, mutate) in <(String, void Function(Map<String, dynamic>))>[
    ('missing totals', (d) => d.remove('totals')),
    ('a string percent', (d) => (d['totals'] as Map)['percent'] = '60'),
    ('a window without today', (d) => (d['window'] as Map).remove('today')),
  ]) {
    test('$what is unexpected_response, and nothing is kept', () async {
      final data = Map<String, dynamic>.from(materialize(cases[0]['expect']) as Map);
      data['totals'] = Map<String, dynamic>.from(data['totals'] as Map);
      data['window'] = Map<String, dynamic>.from(data['window'] as Map);
      mutate(data);
      final (insights, _) = service(envelope(data));

      await expectLater(
        insights.fetch('week'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'unexpected_response')),
      );
      expect(insights.last('week'), isNull);
    });
  }

  group('bar scale', () {
    InsightsDay day(int? completed, int? due) =>
        InsightsDay(date: '2026-05-25', completed: completed, due: due, open: false);

    test('the largest due of the week, at least 1', () {
      expect(InsightsDay.scale([day(3, 5), day(4, 5), day(null, null)]), 5);
      expect(InsightsDay.scale([day(0, 0), day(null, null)]), 1);
      expect(InsightsDay.scale([]), 1);
    });

    test('a bar is completed over the scale; an empty day is 0', () {
      expect(day(3, 5).barFraction(5), 0.6);
      expect(day(null, null).barFraction(5), 0);
      expect(day(0, 0).barFraction(1), 0);
    });
  });
}
