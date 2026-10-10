import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../sync/outbox_states.dart';
import 'app_database.dart';
import 'entity_codec.dart';

/// Screen 20's data (A20): the confirmed user entity (sync_state.user_payload) with an unsent
/// profile.update laid over it (provisional, never written into the confirmed row, invariant
/// 9), the photo this device shows and the upload queue. Pure Dart.
///
/// Tolerant reader (invariant 13): a server before 3b sends no city, country_code,
/// avatar_version or has_avatar; they read as null, null, 0 and false.
class ProfileView {
  final AppDatabase db;

  /// The account's folder; [ProfileState.photoPath] is resolved against it.
  final String filesRoot;

  const ProfileView(this.db, {required this.filesRoot});

  Stream<ProfileState?> watch() => db
      .customSelect(
        'SELECT (SELECT COUNT(*) FROM outbox) + (SELECT COUNT(*) FROM pending_uploads) AS n',
        readsFrom: {db.syncState, db.outbox, db.pendingUploads},
      )
      .watch()
      .asyncMap((_) => load());

  Future<ProfileState?> load() async {
    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingleOrNull();
    if (state == null) return null;
    final decoded = EntityCodec.decodeJson(state.userPayload);
    final user = decoded is Map ? decoded.cast<String, dynamic>() : const <String, dynamic>{};

    final queued =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.operation.equals('profile.update') & o.state.isIn([...OutboxState.unacked]),
              )
              ..orderBy([(o) => OrderingTerm.desc(o.seq)])
              ..limit(1))
            .getSingleOrNull();
    final edit = queued == null
        ? null
        : (jsonDecode(queued.payload) as Map).cast<String, dynamic>();

    final uploads = await (db.select(
      db.pendingUploads,
    )..orderBy([(u) => OrderingTerm.desc(u.createdAt)])).get();
    final unsynced =
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM outbox WHERE state IN (${OutboxState.unacked.map((_) => '?').join(', ')})',
                  variables: [for (final s in OutboxState.unacked) Variable(s)],
                  readsFrom: {db.outbox},
                )
                .getSingle())
            .read<int>('n') +
        uploads.where((u) => u.state == UploadState.pending).length;

    return ProfileState(
      name: _string(edit?['name']) ?? _string(user['name']) ?? '',
      email: _string(user['email']),
      city: edit != null ? _string(edit['city']) : _string(user['city']),
      countryCode: edit != null ? _string(edit['country_code']) : _string(user['country_code']),
      avatarVersion: user['avatar_version'] is int ? user['avatar_version'] as int : 0,
      hasAvatar: user['has_avatar'] == true,
      editQueued: queued != null,
      editNeedsAttention: queued?.state == OutboxState.needsAttention,
      photoPath: state.avatarFile == null ? null : p.join(filesRoot, state.avatarFile),
      uploadPending: uploads.any((u) => u.state == UploadState.pending),
      uploadRejected: uploads.any((u) => u.state == UploadState.rejected),
      unsynced: unsynced,
    );
  }

  static String? _string(Object? v) => v is String && v.isNotEmpty ? v : null;
}

/// pending_uploads states.
abstract final class UploadState {
  static const pending = 'pending';
  static const rejected = 'rejected';
}

class ProfileState {
  final String name;
  final String? email;
  final String? city;
  final String? countryCode;
  final int avatarVersion;
  final bool hasAvatar;

  /// A profile.update written here and not yet acknowledged.
  final bool editQueued;
  final bool editNeedsAttention;

  /// The photo to show (absolute path), or null for initials.
  final String? photoPath;
  final bool uploadPending;

  /// The server refused the last photo chosen here (413/422): "Choose another."
  final bool uploadRejected;

  /// Changes not yet on the server: unacknowledged outbox rows plus pending photo changes.
  final int unsynced;

  const ProfileState({
    required this.name,
    required this.email,
    required this.city,
    required this.countryCode,
    required this.avatarVersion,
    required this.hasAvatar,
    required this.editQueued,
    required this.editNeedsAttention,
    required this.photoPath,
    required this.uploadPending,
    required this.uploadRejected,
    required this.unsynced,
  });

  /// Initials for the avatar fallback: the first letters of the first two words.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    return words.map((w) => String.fromCharCode(w.runes.first).toUpperCase()).join();
  }
}
