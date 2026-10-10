/// Phase 3b (A20): the avatar endpoints as the sync engine sees them. Pure Dart.
abstract interface class AvatarTransport {
  /// PUT /me/avatar (multipart "photo") with [idempotencyKey].
  Future<AvatarAck> put(String idempotencyKey, List<int> jpeg);

  /// DELETE /me/avatar.
  Future<AvatarAck> delete();

  /// GET /me/avatar/md with If-None-Match [etag].
  Future<AvatarFetch> fetchMd({String? etag});
}

class AvatarAck {
  final int avatarVersion;
  final int version;

  const AvatarAck({required this.avatarVersion, required this.version});
}

class AvatarFetch {
  /// Null when not modified (304) or absent (404).
  final List<int>? bytes;
  final String? etag;
  final bool notFound;

  const AvatarFetch({this.bytes, this.etag, this.notFound = false});
}

enum AvatarFailure {
  /// No answer: retry later.
  network,

  /// 5xx: retry later.
  server,

  /// 429: retry after [AvatarTransportException.retryAfter].
  rateLimited,

  /// 401: the session is over; never touch tokens here (G1).
  unauthorized,

  /// 413, 422 and other 4xx: the server will never take this request.
  rejected,
}

class AvatarTransportException implements Exception {
  final AvatarFailure kind;
  final Duration? retryAfter;
  final String? code;

  const AvatarTransportException(this.kind, {this.retryAfter, this.code});

  @override
  String toString() => 'AvatarTransportException($kind, $code)';
}
