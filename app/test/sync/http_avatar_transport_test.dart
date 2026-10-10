import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/photo_service.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/sync/avatar_sync.dart';
import 'package:habit/sync/avatar_transport.dart';
import 'package:habit/sync/http_avatar_transport.dart';
import 'package:path/path.dart' as p;

import '../support/fake_sync_server.dart';
import '../support/route_adapter.dart';
import 'sync_harness.dart';

/// R2: which answers mean "the server will never take this photo" (rejected, kept for the
/// note) and which mean "try again later" (backoff).
void main() {
  setUpAll(Device.loadZones);

  Map<String, Object?> error(String code) => {
    'error': {'code': code, 'message': 'x'},
    'meta': {'request_id': 'r', 'server_time': '2026-05-28T17:22:00Z'},
  };

  (RouteAdapter, HttpAvatarTransport) transport() {
    final http = RouteAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
    return (http, HttpAvatarTransport(dio));
  }

  test('maps each answer to a failure kind', () async {
    final expected = <int, AvatarFailure>{
      400: AvatarFailure.server,
      401: AvatarFailure.unauthorized,
      403: AvatarFailure.server,
      404: AvatarFailure.server,
      405: AvatarFailure.server,
      409: AvatarFailure.rejected,
      410: AvatarFailure.server,
      413: AvatarFailure.rejected,
      415: AvatarFailure.rejected,
      422: AvatarFailure.rejected,
      429: AvatarFailure.rateLimited,
      500: AvatarFailure.server,
      503: AvatarFailure.server,
    };
    final seen = <int, AvatarFailure>{};
    for (final status in expected.keys) {
      final (http, avatars) = transport();
      http.on('PUT /me/avatar', Reply(status, error('x')));
      try {
        await avatars.put('0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f', const [1, 2, 3]);
      } on AvatarTransportException catch (e) {
        seen[status] = e.kind;
      }
    }
    expect(seen, expected);
  });

  test('a 404 or a 403 leaves the photo queued and shown, and backs off', () async {
    for (final status in [404, 403]) {
      final server = FakeSyncServer();
      final phone = await Device(server).init();
      final root = Directory.systemTemp.createTempSync('habit_r2_');
      await phone.sync(force: true);
      final crop = File(p.join(root.path, 'crop.jpg'))..writeAsBytesSync(const [1, 2, 3]);
      await PhotoService(phone.db, filesRoot: root.path, clock: () => phone.now).choose(crop.path);
      final (http, avatars) = transport();
      http.on('PUT /me/avatar', Reply(status, error('not_found')));

      await phone
          .engine(
            avatars: AvatarSync(
              db: phone.db,
              transport: avatars,
              filesRoot: root.path,
              clock: () => phone.now,
            ),
          )
          .run(force: true);

      final row = (await phone.db.select(phone.db.pendingUploads).get()).single;
      expect(row.state, UploadState.pending, reason: '$status');
      expect(
        row.nextAttemptAt,
        greaterThan(phone.now.millisecondsSinceEpoch),
        reason: '$status backs off',
      );
      final shown = (await ProfileView(phone.db, filesRoot: root.path).load())!;
      expect((shown.photoPath != null, shown.uploadRejected), (true, false), reason: '$status');
      await phone.db.close();
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may hold a file briefly; the OS cleans temp.
      }
    }
  });
}
