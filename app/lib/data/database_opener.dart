import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import 'app_database.dart';

/// How every isolate opens an account database (A23). See docs/adr/0001-multi-isolate-drift.md.
///
/// - One database file per account: `habit_<accountKey>.sqlite` in app support storage.
///   Logout or account switch never shares or purges another owner's data.
/// - `shareAcrossIsolates`: the first isolate to open the file spawns a drift server isolate
///   and registers it with `IsolateNameServer`; the UI isolate, background sync and
///   notification-action callbacks in the same process all connect to that one server. One
///   writer, and stream queries update across isolates.
/// - [configureConnection] runs on the server's connection: WAL plus a busy timeout, so even
///   a second, independent connection (another process, or a lost name-server race) is safe.
AppDatabase openAccountDatabase(String accountKey, {Future<Object> Function()? directory}) {
  return AppDatabase(
    driftDatabase(
      name: databaseNameFor(accountKey),
      native: DriftNativeOptions(
        shareAcrossIsolates: true,
        databaseDirectory: directory ?? getApplicationSupportDirectory,
        setup: configureConnection,
      ),
    ),
  );
}

/// File name (without extension) for an account. The key is the server user id (UUID).
String databaseNameFor(String accountKey) {
  final key = accountKey.toLowerCase();
  if (!RegExp(r'^[0-9a-f-]{1,64}$').hasMatch(key)) {
    throw ArgumentError.value(accountKey, 'accountKey', 'must be a UUID');
  }
  return 'habit_$key';
}

/// Applied to every raw connection. Must stay a top-level function: it is sent to the
/// server isolate.
///
/// busy_timeout must come first: switching to WAL takes a lock, and without a timeout a
/// connection opening while another isolate holds that lock fails at once with SQLITE_BUSY
/// (found by the spike test).
void configureConnection(CommonDatabase db) {
  // 15 s: a waiter can be starved for a while by back-to-back commits from another connection
  // (seen on CI with synchronous = FULL). Local writes are tiny, so a long wait is still short.
  db.execute('PRAGMA busy_timeout = 15000');
  db.execute('PRAGMA journal_mode = WAL');
  // FULL, not NORMAL: in WAL mode NORMAL can drop the latest commits on an OS crash or power
  // loss, which would break "saved on this device" (invariant 8). Write volume is tiny.
  db.execute('PRAGMA synchronous = FULL');
  db.execute('PRAGMA foreign_keys = ON');
}
