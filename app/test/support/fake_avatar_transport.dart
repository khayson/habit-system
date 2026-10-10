import 'package:habit/sync/avatar_transport.dart';

import 'fake_sync_server.dart';

/// The avatar endpoints in memory, journaling through [server] like the real AvatarService
/// (each change bumps avatar_version and the user version). Replays by Idempotency-Key answer
/// the first result.
class FakeAvatarTransport implements AvatarTransport {
  final FakeSyncServer server;

  FakeAvatarTransport(this.server);

  final List<String> putKeys = [];
  final List<List<int>> putBytes = [];
  int deletes = 0;
  int fetches = 0;

  /// The server's current md bytes (another device's upload sets these).
  List<int>? md;

  /// Thrown, in order, by the next calls.
  final List<AvatarTransportException> failNext = [];

  final Map<String, AvatarAck> _receipts = {};

  @override
  Future<AvatarAck> put(String idempotencyKey, List<int> jpeg) async {
    putKeys.add(idempotencyKey);
    if (failNext.isNotEmpty) throw failNext.removeAt(0);
    final replay = _receipts[idempotencyKey];
    if (replay != null) return replay;
    putBytes.add(jpeg);
    server.changeAvatar(present: true);
    md = [...jpeg.reversed]; // "re-encoded": never the uploaded bytes
    return _receipts[idempotencyKey] = AvatarAck(
      avatarVersion: server.avatarVersion,
      version: server.userVersion,
    );
  }

  @override
  Future<AvatarAck> delete() async {
    deletes++;
    if (failNext.isNotEmpty) throw failNext.removeAt(0);
    if (server.hasAvatar) {
      server.changeAvatar(present: false);
      md = null;
    }
    return AvatarAck(avatarVersion: server.avatarVersion, version: server.userVersion);
  }

  @override
  Future<AvatarFetch> fetchMd({String? etag}) async {
    fetches++;
    if (failNext.isNotEmpty) throw failNext.removeAt(0);
    final bytes = md;
    return bytes == null ? const AvatarFetch(notFound: true) : AvatarFetch(bytes: bytes);
  }

  /// Another device uploads a photo.
  void otherDeviceUploads(List<int> bytes) {
    server.changeAvatar(present: true);
    md = bytes;
  }

  /// Another device removes the photo.
  void otherDeviceRemoves() {
    server.changeAvatar(present: false);
    md = null;
  }
}
