import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'profile_view.dart';

/// Phase 3b (A20): the profile photo on this device. Pure Dart (dart:io only): no UI, safe from
/// background isolates.
///
/// A chosen photo shows at once from the account's folder, offline, and waits in
/// pending_uploads until the server acknowledges it. The pointer and the queue row are written
/// in ONE transaction. The square crop and the downscale to at most 1024 px JPEG happen before
/// this, in the picker (image_cropper).
///
/// ASSUMPTION(A3b-upload-supersede): a newer choice (another photo, or removal) replaces an
/// unsent queue row (or a refused one) and its file in the same transaction, so only the
/// latest choice uploads. An acknowledged row is removed by the sync; nothing else drops one.
class PhotoService {
  final AppDatabase db;

  /// The account's folder (one per user id).
  final String filesRoot;
  final DateTime Function() clock;
  final Uuid _uuid;

  PhotoService(this.db, {required this.filesRoot, DateTime Function()? clock, Uuid? uuid})
    : clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  static const folder = 'avatars';

  /// Shows [preparedJpeg] (already square, at most 1024 px) and queues its upload.
  Future<void> choose(String preparedJpeg) async {
    final id = _uuid.v7();
    final relative = p.join(folder, 'local-$id.jpg');
    final target = File(p.join(filesRoot, relative));
    await target.parent.create(recursive: true);
    await File(preparedJpeg).copy(target.path);
    try {
      final replaced = await db.transaction(() async {
        final replaced = await _supersede();
        await db
            .into(db.pendingUploads)
            .insert(
              PendingUploadsCompanion.insert(
                id: id,
                op: 'put',
                localPath: Value(relative),
                state: UploadState.pending,
                createdAt: clock().millisecondsSinceEpoch,
              ),
            );
        await _point(Value(relative));
        return replaced;
      });
      await _deleteFiles(replaced);
    } on Object {
      await _deleteFiles([relative]);
      rethrow;
    }
  }

  /// Initials from now on; the server is told with a queued delete (idempotent there).
  Future<void> remove() async {
    final replaced = await db.transaction(() async {
      final replaced = await _supersede();
      await db
          .into(db.pendingUploads)
          .insert(
            PendingUploadsCompanion.insert(
              id: _uuid.v7(),
              op: 'delete',
              state: UploadState.pending,
              createdAt: clock().millisecondsSinceEpoch,
            ),
          );
      await _point(const Value(null));
      return replaced;
    });
    await _deleteFiles(replaced);
  }

  /// Removes unsent (pending) and refused (rejected) rows; returns their files.
  Future<List<String>> _supersede() async {
    final rows = await db.select(db.pendingUploads).get();
    await db.delete(db.pendingUploads).go();
    return [
      for (final row in rows)
        if (row.localPath != null) row.localPath!,
    ];
  }

  Future<void> _point(Value<String?> file) =>
      (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(avatarFile: file, avatarFileVersion: const Value(null)),
      );

  Future<void> _deleteFiles(List<String> relative) async {
    for (final path in relative) {
      try {
        await File(p.join(filesRoot, path)).delete();
      } on FileSystemException {
        // Already gone; nothing refers to it any more.
      }
    }
  }
}
