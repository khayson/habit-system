import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/core/storage/token_store.dart';
import 'package:habit/services/health_service.dart';

import '../support/contract_fixtures.dart';

class MemoryTokenStore implements TokenStore {
  String? token;
  MemoryTokenStore([this.token]);

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> clear() async => token = null;
}

/// Answers every request with one canned response and records what was sent.
class CannedAdapter implements HttpClientAdapter {
  final int status;
  final Object body;
  final Map<String, List<String>> headers;
  RequestOptions? lastRequest;

  CannedAdapter(this.status, this.body, {this.headers = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Replaces the stored token while the request is "in flight", then answers.
class _SwapTokenThenAdapter implements HttpClientAdapter {
  final MemoryTokenStore tokens;
  final String replacement;
  final HttpClientAdapter inner;

  _SwapTokenThenAdapter(this.tokens, this.replacement, this.inner);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    tokens.token = replacement;
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> fixtureBody(String name) =>
    materialize(contractFixture('envelope/$name.json')['body']) as Map<String, dynamic>;

void main() {
  late Dio dio;

  setUp(() => dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1')));

  test('health check returns server_time from the envelope', () async {
    final adapter = CannedAdapter(200, fixtureBody('success_health'));
    dio.httpClientAdapter = adapter;

    final status = await HealthService(ApiClient.withDio(dio, MemoryTokenStore())).check();

    expect(status.status, 'ok');
    expect(status.serverTime, DateTime.utc(2026, 5, 28, 17, 22));
    expect(adapter.lastRequest!.path, '/health');
    expect(adapter.lastRequest!.headers['Accept'], 'application/json');
  });

  test('sends the stored bearer token', () async {
    final adapter = CannedAdapter(200, fixtureBody('success_health'));
    dio.httpClientAdapter = adapter;

    await HealthService(ApiClient.withDio(dio, MemoryTokenStore('secret-token'))).check();

    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer secret-token');
  });

  test('401 clears only the token and notifies the session', () async {
    dio.httpClientAdapter = CannedAdapter(401, fixtureBody('error_401_unauthenticated'));
    final tokens = MemoryTokenStore('expired');
    var notified = false;
    final api = ApiClient.withDio(dio, tokens)..onUnauthenticated = () => notified = true;

    await expectLater(
      HealthService(api).check(),
      throwsA(isA<AppException>().having((e) => e.isUnauthenticated, 'isUnauthenticated', isTrue)),
    );
    expect(tokens.token, isNull);
    expect(notified, isTrue);
  });

  test('a late 401 from an old session does not clear the new session token', () async {
    final tokens = MemoryTokenStore('old-session');
    // The 401 arrives after the user logged out and back in while the request was in flight.
    dio.httpClientAdapter = _SwapTokenThenAdapter(
      tokens,
      'new-session',
      CannedAdapter(401, fixtureBody('error_401_unauthenticated')),
    );
    var notified = false;
    final api = ApiClient.withDio(dio, tokens)..onUnauthenticated = () => notified = true;

    await expectLater(HealthService(api).check(), throwsA(isA<AppException>()));
    expect(tokens.token, 'new-session');
    expect(notified, isFalse);
  });

  test('a 401 on a request sent without a token ends no session', () async {
    final tokens = MemoryTokenStore();
    dio.httpClientAdapter = _SwapTokenThenAdapter(
      tokens,
      'fresh-login',
      CannedAdapter(401, fixtureBody('error_401_unauthenticated')),
    );
    var notified = false;
    final api = ApiClient.withDio(dio, tokens)..onUnauthenticated = () => notified = true;

    await expectLater(HealthService(api).check(), throwsA(isA<AppException>()));
    expect(tokens.token, 'fresh-login');
    expect(notified, isFalse);
  });

  test('429 surfaces Retry-After', () async {
    dio.httpClientAdapter = CannedAdapter(
      429,
      fixtureBody('error_429_rate_limited'),
      headers: {
        'retry-after': ['42'],
      },
    );

    await expectLater(
      HealthService(ApiClient.withDio(dio, MemoryTokenStore())).check(),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'rate_limited')
            .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42)),
      ),
    );
  });

  test('connection failure is a retriable network error', () {
    final e = AppException.fromDioException(
      DioException.connectionError(
        requestOptions: RequestOptions(path: '/health'),
        reason: 'refused',
      ),
    );

    expect(e.kind, AppErrorKind.network);
    expect(e.isRetriable, isTrue);
  });
}
