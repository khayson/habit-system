import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import '../data/entity_codec.dart';
import '../data/photo_service.dart';
import '../data/profile_view.dart';
import 'avatar_transport.dart';

enum UploadRun {
  /// Nothing was due, or everything due was answered or deferred.
  done,

  /// The server acknowledged at least one change; the caller pulls the user entity next.
  acknowledged,

  /// 401: the session is over. Rows stay queued.
  loggedOut,
}

/// Phase 3b (A20): the profile photo's side of a sync cycle. Pure Dart, run by the SyncEngine
/// (foreground and background alike) while it holds the lease: the outbox first, then
/// [upload], then the pull, then [refreshCache].
///
/// The server counts every PUT toward 10 an hour (replays and failures included), so an upload
/// is never retried sooner than [minGap], a 429's Retry-After is honoured, and failures back off.
class AvatarSync {
  static const Duration minGap = Duration(minutes: 5);
  static const Duration maxBackoff = Duration(hours: 6);

  final AppDatabase db;
  final AvatarTransport transport;
  final String filesRoot;
  final DateTime Function() clock;

  AvatarSync({
    required this.db,
    required this.transport,
    required this.filesRoot,
    DateTime Function()? clock,
  }) : clock = clock ?? (() => DateTime.now().toUtc());

  int get _now => clock().millisecondsSinceEpoch;

  /// Sends due pending changes one at a time, oldest first.
  Future<UploadRun> upload() async {
    var acknowledged = false;
    for (var i = 0; i < 10; i++) {
      final row =
          await (db.select(db.pendingUploads)
                ..where(
                  (u) =>
                      u.state.equals(UploadState.pending) &
                      (u.nextAttemptAt.isNull() | u.nextAttemptAt.isSmallerOrEqualValue(_now)),
                )
                ..orderBy([(u) => OrderingTerm.asc(u.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      if (row == null) break;
      try {
        final ack = row.op == 'put' ? await _put(row) : await transport.delete();
        await _acknowledge(row, ack);
        acknowledged = true;
      } on AvatarTransportException catch (e) {
        switch (e.kind) {
          case AvatarFailure.unauthorized:
            await _defer(row, minGap, 'reauth_needed');
            return UploadRun.loggedOut;
          case AvatarFailure.rejected:
            await _reject(row, e.code ?? 'rejected');
          case AvatarFailure.rateLimited:
            final wait = e.retryAfter ?? minGap;
            await _defer(row, wait > minGap ? wait : minGap, 'rate_limited');
            return acknowledged ? UploadRun.acknowledged : UploadRun.done;
          case AvatarFailure.network || AvatarFailure.server:
            await _defer(row, _backoff(row.attempts + 1), e.kind.name);
            return acknowledged ? UploadRun.acknowledged : UploadRun.done;
        }
      } on FileSystemException {
        // The prepared file is gone (cleared storage): nothing can ever be sent for this row.
        await _reject(row, 'file_missing');
      }
    }
    return acknowledged ? UploadRun.acknowledged : UploadRun.done;
  }

  Future<AvatarAck> _put(PendingUpload row) async {
    final bytes = await File(p.join(filesRoot, row.localPath!)).readAsBytes();
    return transport.put(row.id, bytes);
  }

  /// Acknowledged: the row goes; a photo chosen here stays the shown one, now tied to the
  /// server's version, so this device never downloads its own upload.
  Future<void> _acknowledge(PendingUpload row, AvatarAck ack) => db.transaction(() async {
    final current = await (db.select(
      db.pendingUploads,
    )..where((u) => u.id.equals(row.id))).getSingleOrNull();
    await (db.delete(db.pendingUploads)..where((u) => u.id.equals(row.id))).go();
    if (current == null) return; // replaced by a newer choice while in flight
    final state = await _state();
    if (row.op == 'put' && state.avatarFile == row.localPath) {
      await _updateState(SyncStateCompanion(avatarFileVersion: Value(ack.avatarVersion)));
    } else if (row.op == 'delete' && state.avatarFile == null) {
      await _updateState(SyncStateCompanion(avatarFileVersion: Value(ack.avatarVersion)));
    }
  });

  /// 413 / 422: kept with its file for the note on screen 20; the display goes back to the
  /// server's photo (fetched by [refreshCache]) or initials.
  Future<void> _reject(PendingUpload row, String code) => db.transaction(() async {
    await (db.update(db.pendingUploads)..where((u) => u.id.equals(row.id))).write(
      PendingUploadsCompanion(
        state: const Value(UploadState.rejected),
        attempts: Value(row.attempts + 1),
        lastError: Value(jsonEncode({'code': code})),
      ),
    );
    if ((await _state()).avatarFile == row.localPath) {
      await _updateState(
        const SyncStateCompanion(avatarFile: Value(null), avatarFileVersion: Value(null)),
      );
    }
  });

  Future<void> _defer(PendingUpload row, Duration wait, String code) =>
      (db.update(db.pendingUploads)..where((u) => u.id.equals(row.id))).write(
        PendingUploadsCompanion(
          attempts: Value(row.attempts + 1),
          nextAttemptAt: Value(_now + wait.inMilliseconds),
          lastError: Value(jsonEncode({'code': code})),
        ),
      );

  /// 5, 10, 20 minutes … up to 6 hours; never under [minGap].
  static Duration _backoff(int attempts) {
    final minutes = minGap.inMinutes * pow(2, min(attempts - 1, 10)).toInt();
    return Duration(minutes: min(minutes, maxBackoff.inMinutes));
  }

  /// Other devices' photo changes, from the confirmed user entity. Silent on failure (the next
  /// cycle tries again). Skipped while a photo chosen here waits to upload.
  Future<void> refreshCache() async {
    final pending = await (db.select(
      db.pendingUploads,
    )..where((u) => u.state.equals(UploadState.pending))).get();
    if (pending.isNotEmpty) return;
    final state = await _state();
    final decoded = EntityCodec.decodeJson(state.userPayload);
    final user = decoded is Map ? decoded : const {};
    final version = user['avatar_version'];
    final has = user['has_avatar'];
    if (version is! int || has is! bool) return; // a server before 3b
    if (!has) {
      if (state.avatarFile != null || state.avatarFileVersion != version) {
        await _updateState(
          SyncStateCompanion(avatarFile: const Value(null), avatarFileVersion: Value(version)),
        );
      }
      await _collect();
      return;
    }
    final reconciled = state.avatarFileVersion;
    if (reconciled != null && version <= reconciled) return;

    try {
      final fetched = await transport.fetchMd();
      if (fetched.notFound) {
        await _updateState(
          SyncStateCompanion(avatarFile: const Value(null), avatarFileVersion: Value(version)),
        );
      } else if (fetched.bytes != null) {
        final relative = p.join(PhotoService.folder, state.userId, 'md-$version.webp');
        final file = File(p.join(filesRoot, relative));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(fetched.bytes!, flush: true);
        await _updateState(
          SyncStateCompanion(avatarFile: Value(relative), avatarFileVersion: Value(version)),
        );
      }
      await _collect();
    } on AvatarTransportException {
      // Silent: retried next cycle.
    } on FileSystemException {
      // Silent: retried next cycle.
    }
  }

  /// A file newer than this is never collected: a photo being chosen right now is copied in
  /// before its queue row exists.
  static const Duration collectAfter = Duration(minutes: 10);

  /// Deletes photo files nothing points at any more (older downloads, replaced choices).
  Future<void> _collect() async {
    final state = await _state();
    final kept = {
      ?state.avatarFile,
      for (final row in await db.select(db.pendingUploads).get()) ?row.localPath,
    };
    final dir = Directory(p.join(filesRoot, PhotoService.folder));
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: filesRoot);
      final age = clock().difference((await entity.stat()).modified.toUtc());
      if (!kept.contains(relative) && age >= collectAfter) {
        try {
          await entity.delete();
        } on FileSystemException {
          // In use or gone; the next collection tries again.
        }
      }
    }
  }

  Future<SyncStateRow> _state() =>
      (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();

  Future<void> _updateState(SyncStateCompanion values) =>
      (db.update(db.syncState)..where((s) => s.id.equals(1))).write(values);
}
