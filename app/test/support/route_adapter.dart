import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP answer.
class Reply {
  final int status;
  final Object? body;
  final Map<String, List<String>> headers;

  /// Null [status] means no answer at all (connection error).
  const Reply(this.status, [this.body, this.headers = const {}]);

  const Reply.offline() : status = 0, body = null, headers = const {};

  bool get isOffline => status == 0;
}

/// Answers by `METHOD /path` from a queue per route, recording every request sent.
class RouteAdapter implements HttpClientAdapter {
  final Map<String, List<Reply>> _routes = {};
  final List<RequestOptions> requests = [];

  void on(String route, Reply reply) => _routes.putIfAbsent(route, () => []).add(reply);

  List<RequestOptions> sent(String route) =>
      requests.where((r) => '${r.method} ${r.path}' == route).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = '${options.method} ${options.path}';
    final queue = _routes[route];
    if (queue == null || queue.isEmpty) throw StateError('No reply scripted for $route');
    final reply = queue.length == 1 ? queue.first : queue.removeAt(0);
    if (reply.isOffline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> envelope(Object? data) => {
  'data': data,
  'meta': {'api_version': 'v1', 'request_id': 'req-1', 'server_time': '2026-05-28T10:00:00Z'},
};

Map<String, Object?> errorEnvelope(String code) => {
  'error': {'code': code, 'message': code},
  'meta': {'request_id': 'req-1', 'server_time': '2026-05-28T10:00:00Z'},
};
