import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../config/app_version.dart';
import '../core/storage/account_store.dart';
import '../core/storage/token_store.dart';
import '../data/app_database.dart';
import '../domain/calendar/timezone_timeline.dart';
import '../domain/provisional_type_rules.dart';
import 'sync_engine.dart';
import 'sync_transport.dart';

/// Best-effort background sync (Phase 3.2b, Android first). Pure Dart; the OS glue is
/// lib/background/workmanager_sync.dart. The OS decides when it runs; the
/// foreground sync stays the repair path. It runs the same [SyncEngine] on the account's own
/// database and never touches the session: it never refreshes or clears a token, and on a 401
/// it records `reauth_needed` and stops (the foreground app owns the session, G1).
const backgroundSyncTask = 'habit.background_sync';

/// Registration with the OS, per account. A seam so tests and other platforms can fake it.
abstract interface class BackgroundSyncScheduler {
  Future<void> register(String accountKey);
  Future<void> cancel(String accountKey);
}

/// One background run for one account. Returns the outcome, or null when it did not run (the
/// account is no longer the signed-in one, or there is no token).
Future<SyncOutcome?> runBackgroundSync({
  required String accountKey,
  required TokenStore tokens,
  required AccountStore accounts,
  required AppDatabase Function(String accountKey) open,
  required SyncTransport Function(String token) transport,
}) async {
  // A logged-out or switched account never syncs from the background.
  if ((await accounts.readUserId())?.toLowerCase() != accountKey.toLowerCase()) return null;
  final token = await tokens.read();
  if (token == null) return null;
  ensureTimeZonesLoaded(tzdata.initializeTimeZones);
  final db = open(accountKey);
  try {
    final outcome = await SyncEngine(
      db: db,
      transport: transport(token),
      capabilities: ProvisionalTypeRegistry.builtins().keys.toList(),
      appVersion: AppVersion.current,
    ).run();
    if (outcome == SyncOutcome.loggedOut) {
      await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(
          lastError: Value(
            jsonEncode({
              'code': 'reauth_needed',
              'message': 'Sign in again on this device to keep syncing.',
            }),
          ),
        ),
      );
    }
    return outcome;
  } finally {
    await db.close();
  }
}
