import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/photo_service.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/sync/avatar_sync.dart';
import 'package:habit/sync/avatar_transport.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:path/path.dart' as p;

import '../support/fake_avatar_transport.dart';
import '../support/fake_sync_server.dart';
import 'sync_harness.dart';

/// Phase 3b (A20): the photo on this device, its durable upload queue and the cache of other
/// devices' photos, through the real SyncEngine cycle (outbox, uploads, pull).
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late FakeAvatarTransport avatars;
  late Device phone;
  late Directory root;
  late PhotoService photos;

  setUp(() async {
    server = FakeSyncServer();
    avatars = FakeAvatarTransport(server);
    phone = await Device(server).init();
    root = Directory.systemTemp.createTempSync('habit_photo_');
    photos = PhotoService(phone.db, filesRoot: root.path, clock: () => phone.now);
    await phone.sync(force: true);
  });

  tearDown(() async {
    await phone.db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file briefly; the OS cleans temp.
    }
  });

  Future<SyncOutcome> cycle() => phone
      .engine(
        avatars: AvatarSync(
          db: phone.db,
          transport: avatars,
          filesRoot: root.path,
          clock: () => phone.now,
        ),
      )
      .run(force: true);

  Future<ProfileState> profile() async =>
      (await ProfileView(phone.db, filesRoot: root.path).load())!;

  String prepared([String name = 'crop.jpg', List<int> bytes = const [1, 2, 3]]) {
    final file = File(p.join(root.path, name))..writeAsBytesSync(bytes);
    return file.path;
  }

  test('a chosen photo shows at once, offline, and waits in the queue', () async {
    await photos.choose(prepared());

    final state = await profile();
    expect(state.photoPath, isNotNull);
    expect(File(state.photoPath!).readAsBytesSync(), [1, 2, 3]);
    expect((state.uploadPending, state.unsynced), (true, 1));
    expect(avatars.putKeys, isEmpty, reason: 'nothing sent yet');
  });

  test(
    'the cycle uploads with the row id as the Idempotency-Key and keeps the local photo',
    () async {
      await photos.choose(prepared());
      final row = (await phone.db.select(phone.db.pendingUploads).get()).single;

      expect(await cycle(), SyncOutcome.completed);

      expect(avatars.putKeys, [row.id]);
      expect(avatars.putBytes.single, [1, 2, 3]);
      expect(await phone.db.select(phone.db.pendingUploads).get(), isEmpty);
      final state = await profile();
      expect((state.hasAvatar, state.avatarVersion, state.uploadPending), (true, 1, false));
      expect(File(state.photoPath!).readAsBytesSync(), [1, 2, 3], reason: 'still the local file');
      expect(avatars.fetches, 0, reason: 'a device never downloads its own upload');

      await cycle();
      expect(avatars.fetches, 0);
    },
  );

  test('a newer choice replaces the unsent row and its file', () async {
    await photos.choose(prepared('a.jpg', [1]));
    final first = (await phone.db.select(phone.db.pendingUploads).getSingle()).localPath!;
    await photos.choose(prepared('b.jpg', [2]));

    final rows = await phone.db.select(phone.db.pendingUploads).get();
    expect(rows, hasLength(1));
    expect(File(p.join(root.path, first)).existsSync(), isFalse);
    expect(File((await profile()).photoPath!).readAsBytesSync(), [2]);
  });

  test('no answer or a 5xx backs off at least five minutes; nothing is sent sooner', () async {
    await photos.choose(prepared());
    avatars.failNext.add(const AvatarTransportException(AvatarFailure.network));

    await cycle();
    var row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    expect((row.state, row.attempts), (UploadState.pending, 1));
    expect(row.nextAttemptAt, phone.now.millisecondsSinceEpoch + 5 * 60 * 1000);

    phone.now = phone.now.add(const Duration(minutes: 4));
    await cycle();
    expect(avatars.putKeys, hasLength(1), reason: 'not retried inside five minutes');

    phone.now = phone.now.add(const Duration(minutes: 1));
    avatars.failNext.add(const AvatarTransportException(AvatarFailure.server));
    await cycle();
    row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    expect(row.nextAttemptAt, phone.now.millisecondsSinceEpoch + 10 * 60 * 1000, reason: 'doubles');

    phone.now = phone.now.add(const Duration(minutes: 10));
    await cycle();
    expect(await phone.db.select(phone.db.pendingUploads).get(), isEmpty);
    expect(avatars.putKeys.toSet(), hasLength(1), reason: 'the same key every time');
  });

  test('429 honours Retry-After, and never less than five minutes', () async {
    await photos.choose(prepared());
    avatars.failNext.add(
      const AvatarTransportException(AvatarFailure.rateLimited, retryAfter: Duration(minutes: 20)),
    );
    await cycle();
    var row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    expect(row.nextAttemptAt, phone.now.millisecondsSinceEpoch + 20 * 60 * 1000);

    phone.now = phone.now.add(const Duration(minutes: 20));
    avatars.failNext.add(
      const AvatarTransportException(AvatarFailure.rateLimited, retryAfter: Duration(seconds: 30)),
    );
    await cycle();
    row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    expect(row.nextAttemptAt, phone.now.millisecondsSinceEpoch + 5 * 60 * 1000);
  });

  test(
    '413 or 422: rejected, the file is kept, the display goes back to the server photo',
    () async {
      avatars.otherDeviceUploads([9, 9]);
      await cycle();
      expect(File((await profile()).photoPath!).readAsBytesSync(), [9, 9]);

      await photos.choose(prepared());
      avatars.failNext.add(
        const AvatarTransportException(AvatarFailure.rejected, code: 'validation_failed'),
      );
      await cycle();

      final row = (await phone.db.select(phone.db.pendingUploads).get()).single;
      expect(row.state, UploadState.rejected);
      expect(File(p.join(root.path, row.localPath!)).existsSync(), isTrue, reason: 'kept');
      final state = await profile();
      expect((state.uploadRejected, state.uploadPending), (true, false));
      expect(File(state.photoPath!).readAsBytesSync(), [9, 9], reason: 'the server photo again');
    },
  );

  test('401: the session is over; the row stays queued', () async {
    await photos.choose(prepared());
    avatars.failNext.add(const AvatarTransportException(AvatarFailure.unauthorized));

    expect(await cycle(), SyncOutcome.loggedOut);
    final row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    expect(row.state, UploadState.pending);
  });

  test(
    'another device\'s photo is fetched once per version, cached per account, then removed',
    () async {
      // Files written now are older than the collection guard once the clock is moved on.
      phone.now = DateTime.now().toUtc();
      avatars.otherDeviceUploads([7, 7, 7]);

      await cycle();
      var state = await profile();
      expect(avatars.fetches, 1);
      expect(state.photoPath, p.join(root.path, PhotoService.folder, 'user-1', 'md-1.webp'));
      expect(File(state.photoPath!).readAsBytesSync(), [7, 7, 7]);

      await cycle();
      expect(avatars.fetches, 1, reason: 'once per version');

      avatars.otherDeviceUploads([8]);
      phone.now = phone.now.add(AvatarSync.collectAfter + const Duration(minutes: 1));
      await cycle();
      state = await profile();
      expect(state.photoPath, endsWith('md-2.webp'));
      expect(
        File(p.join(root.path, PhotoService.folder, 'user-1', 'md-1.webp')).existsSync(),
        isFalse,
      );

      avatars.otherDeviceRemoves();
      phone.now = phone.now.add(AvatarSync.collectAfter + const Duration(minutes: 1));
      await cycle();
      state = await profile();
      expect((state.hasAvatar, state.photoPath), (false, null));
      expect(
        File(p.join(root.path, PhotoService.folder, 'user-1', 'md-2.webp')).existsSync(),
        isFalse,
      );
      expect(avatars.fetches, 2);
    },
  );

  test(
    'a removed photo\'s downloaded copy is deleted at once; a photo being chosen is not',
    () async {
      avatars.otherDeviceUploads([4, 4]);
      await cycle();
      final cached = (await profile()).photoPath!;
      // A file copied in for a choice whose queue row does not exist yet.
      final choosing = File(p.join(root.path, PhotoService.folder, 'local-in-progress.jpg'))
        ..writeAsBytesSync([1]);

      avatars.otherDeviceRemoves();
      await cycle();

      expect(File(cached).existsSync(), isFalse, reason: 'no waiting period for server copies');
      expect(choosing.existsSync(), isTrue, reason: 'a choice in progress is never collected');
    },
  );

  test('a failed fetch is silent and tried again next cycle', () async {
    avatars.otherDeviceUploads([5]);
    avatars.failNext.add(const AvatarTransportException(AvatarFailure.network));

    expect(await cycle(), SyncOutcome.completed);
    expect((await profile()).photoPath, isNull);

    await cycle();
    expect(File((await profile()).photoPath!).readAsBytesSync(), [5]);
  });

  test('remove queues a delete; initials at once, has_avatar false after the cycle', () async {
    await photos.choose(prepared());
    await cycle();

    await photos.remove();
    expect((await profile()).photoPath, isNull);

    await cycle();
    expect(avatars.deletes, 1);
    final state = await profile();
    expect((state.hasAvatar, state.photoPath, state.uploadPending), (false, null, false));
    expect(avatars.fetches, 0);
  });
}
