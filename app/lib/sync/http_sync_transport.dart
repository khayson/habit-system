import 'package:dio/dio.dart';

import 'sync_transport.dart';

/// [SyncTransport] over HTTP: `POST /sync` and `GET /sync/bootstrap`. Pure Dart, so the same
/// class serves the app, background isolates and the command-line smoke run.
///
/// [dio] must already carry the base URL and the bearer token (the app passes
/// `ApiClient.dio`). Transport failures become [SyncTransportException]; the engine decides
/// what each one means for the outbox.
class HttpSyncTransport implements SyncTransport {
  final Dio _dio;

  HttpSyncTransport(this._dio);

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    final data = await _send(
      () => _dio.post<Object?>(
        '/sync',
        data: {
          'device_id': deviceId,
          'cursor': cursor,
          'pull_limit': pullLimit,
          'mutations': mutations,
        },
        options: Options(headers: {'X-Capabilities': capabilityHeader(capabilities)}),
      ),
    );
    return SyncPage.fromJson(data);
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) async {
    final data = await _send(
      () => _dio.get<Object?>(
        '/sync/bootstrap',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      ),
    );
    return BootstrapPage.fromJson(data);
  }

  /// The habit types this app can render, as the server's `type.<key>` tokens (A21).
  static String capabilityHeader(Iterable<String> typeKeys) =>
      typeKeys.map((k) => 'type.$k').join(',');

  Future<Map<String, dynamic>> _send(Future<Response<Object?>> Function() request) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw _failure(e);
    }
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      // A 2xx that is not the envelope: a proxy or captive portal, not the API.
      throw const SyncTransportException(SyncFailure.network);
    }
    return data.cast<String, dynamic>();
  }

  static SyncTransportException _failure(DioException e) {
    final response = e.response;
    if (response == null) return const SyncTransportException(SyncFailure.network);
    return switch (response.statusCode ?? 0) {
      401 => const SyncTransportException(SyncFailure.unauthorized),
      410 => const SyncTransportException(SyncFailure.cursorExpired),
      413 => const SyncTransportException(SyncFailure.payloadTooLarge),
      429 => SyncTransportException(
        SyncFailure.rateLimited,
        retryAfter: _retryAfter(response.headers.value('retry-after')),
      ),
      // ASSUMPTION(A2b-request-rejected): a whole-request 4xx other than the above (403, 404,
      // 422) is a client or deployment fault, not a per-mutation answer. Treat it like a 5xx:
      // back off and keep every outbox row; nothing is dropped.
      _ => const SyncTransportException(SyncFailure.server),
    };
  }

  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}
