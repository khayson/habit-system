/// The engine's view of the server (`POST /sync`, `GET /sync/bootstrap`). Pure Dart, so the
/// engine runs in tests, background isolates and the command-line smoke run alike.
abstract interface class SyncTransport {
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  });

  Future<BootstrapPage> bootstrap({required String? cursor, required int limit});
}

enum SyncFailure {
  /// 401: missing, expired or revoked token. The ApiClient has already ended the session
  /// unless [SyncTransportException.tokenRotated] (G1).
  unauthorized,

  /// 410: the cursor cannot be honoured; bootstrap (A29).
  cursorExpired,

  /// HTTP 413: too many mutations in one request. Not the ack-level payload_too_large.
  payloadTooLarge,

  /// 429: honour Retry-After.
  rateLimited,

  /// 5xx.
  server,

  /// A whole-request 4xx other than 401/410/413/429 (403, 404, 422, ...): the request itself
  /// was refused, not one mutation. Counted toward the paused status (F7).
  requestRejected,

  /// No response at all.
  network,
}

class SyncTransportException implements Exception {
  final SyncFailure kind;
  final Duration? retryAfter;

  /// The server's error code, when it sent the error envelope.
  final String? code;

  /// `meta.server_time` of the error response, when there was one (F10).
  final DateTime? serverTime;

  /// For a 401: the stored token is no longer the one this request carried (another caller
  /// rotated it meanwhile), so one retry with the stored token is worth it (G1).
  final bool tokenRotated;

  const SyncTransportException(
    this.kind, {
    this.retryAfter,
    this.code,
    this.serverTime,
    this.tokenRotated = false,
  });

  @override
  String toString() => 'SyncTransportException($kind${code == null ? '' : ', $code'})';
}

class SyncPage {
  final List<Map<String, dynamic>> acks;
  final List<Map<String, dynamic>> changes;

  /// Null when the server omitted it (a protocol fault): the engine keeps its cursor.
  final String? nextCursor;
  final bool hasMore;

  /// `meta.server_time` of the response (F10).
  final DateTime? serverTime;

  const SyncPage({
    required this.acks,
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    this.serverTime,
  });

  factory SyncPage.fromJson(Map<String, dynamic> data, {DateTime? serverTime}) => SyncPage(
    acks: _maps(data['acks']),
    changes: _maps(data['changes']),
    nextCursor: _string(data['next_cursor']),
    hasMore: data['has_more'] == true,
    serverTime: serverTime,
  );
}

class BootstrapPage {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> habits;
  final List<Map<String, dynamic>> logs;
  final bool hasMore;
  final String? nextCursor;
  final String? syncCursor;

  /// Entity types added after v1, as `{entity, id, version, payload}` (A31).
  final List<Map<String, dynamic>> entities;

  /// Other list-valued keys this app version does not know, kept so they are stored opaquely
  /// as `bootstrap:<key>` instead of dropped (A31, invariant 13).
  final Map<String, List<Map<String, dynamic>>> unknownCollections;

  /// `meta.server_time` of the response (F10).
  final DateTime? serverTime;

  const BootstrapPage({
    this.serverTime,
    this.user,
    this.habits = const [],
    this.logs = const [],
    this.entities = const [],
    required this.hasMore,
    this.nextCursor,
    this.syncCursor,
    this.unknownCollections = const {},
  });

  static const _known = {
    'user',
    'habits',
    'logs',
    'entities',
    'has_more',
    'next_cursor',
    'sync_cursor',
    'snapshot_seq',
  };

  factory BootstrapPage.fromJson(Map<String, dynamic> data, {DateTime? serverTime}) =>
      BootstrapPage(
        serverTime: serverTime,
        user: data['user'] is Map ? (data['user'] as Map).cast<String, dynamic>() : null,
        habits: _maps(data['habits']),
        logs: _maps(data['logs']),
        entities: _maps(data['entities']),
        hasMore: data['has_more'] == true,
        nextCursor: _string(data['next_cursor']),
        syncCursor: _string(data['sync_cursor']),
        unknownCollections: {
          for (final e in data.entries)
            if (!_known.contains(e.key) && e.value is List) e.key: _maps(e.value),
        },
      );
}

/// Items that are not objects are wrapped as `{"_raw": item}` so the engine stores them as
/// undecodable instead of failing the whole page (F2).
List<Map<String, dynamic>> _maps(Object? list) => [
  if (list is List)
    for (final item in list)
      item is Map ? item.cast<String, dynamic>() : <String, dynamic>{'_raw': item},
];

String? _string(Object? value) => value is String ? value : null;

/// `meta.server_time` of an envelope, or null.
DateTime? serverTimeOf(Object? body) {
  final meta = body is Map ? body['meta'] : null;
  final time = meta is Map ? meta['server_time'] : null;
  return time is String ? DateTime.tryParse(time)?.toUtc() : null;
}
