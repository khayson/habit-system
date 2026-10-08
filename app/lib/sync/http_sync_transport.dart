import 'package:dio/dio.dart';

import 'sync_transport.dart';

/// [SyncTransport] over HTTP: `POST /sync` and `GET /sync/bootstrap`. Pure Dart, so the same
/// class serves the app, background isolates and the command-line smoke run.
///
/// [dio] must already carry the base URL and the bearer token (the app passes
/// `ApiClient.dio`, whose interceptor owns ending a session on 401). Transport failures become
/// [SyncTransportException]; the engine decides what each one means for the outbox.
///
/// [currentToken] reads the stored token, so a 401 can tell "this request's token was rotated
/// meanwhile" (retry once) from "the session is over" (G1).
class HttpSyncTransport implements SyncTransport {
  final Dio _dio;
  final Future<String?> Function()? _currentToken;

  HttpSyncTransport(this._dio, {this._currentToken});

  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) async {
    final (data, time) = await _send(
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
    return SyncPage.fromJson(data, serverTime: time);
  }

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) async {
    final (data, time) = await _send(
      () => _dio.get<Object?>(
        '/sync/bootstrap',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      ),
    );
    return BootstrapPage.fromJson(data, serverTime: time);
  }

  /// The habit types this app can render, as the server's `type.<key>` tokens (A21).
  static String capabilityHeader(Iterable<String> typeKeys) =>
      typeKeys.map((k) => 'type.$k').join(',');

  Future<(Map<String, dynamic>, DateTime?)> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw await _failure(e);
    }
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      // A 2xx that is not the envelope: a proxy or captive portal, not the API.
      throw const SyncTransportException(SyncFailure.network);
    }
    return (data.cast<String, dynamic>(), serverTimeOf(body));
  }

  Future<SyncTransportException> _failure(DioException e) async {
    final response = e.response;
    if (response == null) return const SyncTransportException(SyncFailure.network);
    final time = serverTimeOf(response.data);
    return switch (response.statusCode ?? 0) {
      401 => SyncTransportException(
        SyncFailure.unauthorized,
        serverTime: time,
        tokenRotated: await _rotated(e.requestOptions),
      ),
      410 => SyncTransportException(SyncFailure.cursorExpired, serverTime: time),
      413 => SyncTransportException(SyncFailure.payloadTooLarge, serverTime: time),
      429 => SyncTransportException(
        SyncFailure.rateLimited,
        retryAfter: _retryAfter(response.headers.value('retry-after')),
        serverTime: time,
      ),
      final status when status >= 400 && status < 500 => SyncTransportException(
        SyncFailure.requestRejected,
        code: _code(response.data) ?? 'http_$status',
        serverTime: time,
      ),
      _ => SyncTransportException(SyncFailure.server, serverTime: time),
    };
  }

  Future<bool> _rotated(RequestOptions request) async {
    final current = await _currentToken?.call();
    if (current == null) return false;
    return request.headers['Authorization'] != 'Bearer $current';
  }

  static String? _code(Object? body) {
    final error = body is Map ? body['error'] : null;
    final code = error is Map ? error['code'] : null;
    return code is String ? code : null;
  }

  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}
