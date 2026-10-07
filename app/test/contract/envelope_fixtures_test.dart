import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_response.dart';

import '../support/contract_fixtures.dart';

void main() {
  test('parses the success envelope fixture', () {
    final fixture = contractFixture('envelope/success_health.json');
    final body = materialize(fixture['body']) as Map<String, dynamic>;

    final response = ApiResponse.fromJson(body, (d) => (d as Map<String, dynamic>)['status']);

    expect(response.data, 'ok');
    expect(response.meta.apiVersion, 'v1');
    expect(response.meta.serverTime, DateTime.utc(2026, 5, 28, 17, 22));
    expect(response.meta.serverTime!.isUtc, isTrue);
    expect(response.meta.requestId, isNotEmpty);
  });

  final errorFixtures = contractFixtureNames('envelope').where((n) => n.startsWith('error_'));

  test('there are error fixtures to check', () => expect(errorFixtures, isNotEmpty));

  for (final name in errorFixtures) {
    test('maps $name to AppException', () {
      final fixture = contractFixture('envelope/$name.json');
      final body = materialize(fixture['body']) as Map<String, dynamic>;
      final headers = (materialize(fixture['headers'] ?? <String, dynamic>{}) as Map)
          .cast<String, String>();
      final error = body['error'] as Map<String, dynamic>;

      final e = AppException.fromResponse(
        fixture['status'] as int,
        body,
        retryAfterHeader: headers['Retry-After'],
      );

      expect(e.kind, AppErrorKind.api);
      expect(e.statusCode, fixture['status']);
      expect(e.code, error['code']);
      expect(e.message, error['message']);
      expect(e.requestId, (body['meta'] as Map)['request_id']);
      expect(e.details, error, reason: 'unknown error keys are preserved');
      expect(e.fields.keys, (error['fields'] as Map? ?? {}).keys);
      expect(e.current, error['current']);
      if (headers.containsKey('Retry-After')) {
        expect(e.retryAfter, Duration(seconds: int.parse(headers['Retry-After']!)));
      }
    });
  }

  test('409 helpers identify each conflict code', () {
    AppException load(String name) {
      final f = contractFixture('envelope/$name.json');
      return AppException.fromResponse(f['status'] as int, materialize(f['body']));
    }

    expect(load('error_409_version_conflict').isVersionConflict, isTrue);
    expect(load('error_409_version_conflict').current, {'value': '1750.000'});
    expect(load('error_409_idempotency_mismatch').isIdempotencyMismatch, isTrue);
    expect(load('error_409_resource_deleted').isResourceDeleted, isTrue);
    expect(load('error_410_cursor_expired').isCursorExpired, isTrue);
    expect(
      load('error_422_validation_failed').firstFieldError('target_value'),
      'Duration must be greater than zero.',
    );
    expect(load('error_429_rate_limited').isRetriable, isTrue);
    expect(load('error_500_server_error').isRetriable, isTrue);
    expect(load('error_404_not_found').isRetriable, isFalse);
  });

  test('a non-envelope body never crashes the reader', () {
    final e = AppException.fromResponse(502, '<html>Bad gateway</html>');

    expect(e.kind, AppErrorKind.unexpected);
    expect(e.statusCode, 502);
    expect(e.isRetriable, isTrue);
  });
}
