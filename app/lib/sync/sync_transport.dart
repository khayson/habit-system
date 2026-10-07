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

/// Re-authentication hooks the engine uses on 401 (A6).
abstract interface class AuthSession {
  /// One refresh attempt; true when a new token is stored.
  Future<bool> refresh();

  /// Ends the session but keeps the per-account database and its outbox.
  Future<void> logout();
}

enum SyncFailure {
  /// 401: missing, expired or revoked token.
  unauthorized,

  /// 410: the cursor cannot be honoured; bootstrap (A29).
  cursorExpired,

  /// HTTP 413: too many mutations in one request. Not the ack-level payload_too_large.
  payloadTooLarge,

  /// 429: honour Retry-After.
  rateLimited,

  /// 5xx.
  server,

  /// No response at all.
  network,
}

class SyncTransportException implements Exception {
  final SyncFailure kind;
  final Duration? retryAfter;

  const SyncTransportException(this.kind, {this.retryAfter});

  @override
  String toString() => 'SyncTransportException($kind)';
}

class SyncPage {
  final List<Map<String, dynamic>> acks;
  final List<Map<String, dynamic>> changes;
  final String nextCursor;
  final bool hasMore;

  const SyncPage({
    required this.acks,
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  factory SyncPage.fromJson(Map<String, dynamic> data) => SyncPage(
    acks: _maps(data['acks']),
    changes: _maps(data['changes']),
    nextCursor: data['next_cursor'] as String,
    hasMore: data['has_more'] as bool? ?? false,
  );
}

class BootstrapPage {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> habits;
  final List<Map<String, dynamic>> logs;
  final bool hasMore;
  final String? nextCursor;
  final String? syncCursor;

  /// List-valued keys this app version does not know (a newer server's entity collections),
  /// kept so they can be stored opaquely instead of dropped (invariant 13).
  final Map<String, List<Map<String, dynamic>>> unknownCollections;

  const BootstrapPage({
    this.user,
    this.habits = const [],
    this.logs = const [],
    required this.hasMore,
    this.nextCursor,
    this.syncCursor,
    this.unknownCollections = const {},
  });

  static const _known = {
    'user',
    'habits',
    'logs',
    'has_more',
    'next_cursor',
    'sync_cursor',
    'snapshot_seq',
  };

  factory BootstrapPage.fromJson(Map<String, dynamic> data) => BootstrapPage(
    user: (data['user'] as Map?)?.cast<String, dynamic>(),
    habits: _maps(data['habits']),
    logs: _maps(data['logs']),
    hasMore: data['has_more'] as bool? ?? false,
    nextCursor: data['next_cursor'] as String?,
    syncCursor: data['sync_cursor'] as String?,
    unknownCollections: {
      for (final e in data.entries)
        if (!_known.contains(e.key) && e.value is List) e.key: _maps(e.value),
    },
  );
}

List<Map<String, dynamic>> _maps(Object? list) => [
  for (final item in (list as List<dynamic>? ?? const [])) (item as Map).cast<String, dynamic>(),
];
