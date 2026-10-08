import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:workmanager/workmanager.dart';

import '../config/api_config.dart';
import '../config/app_version.dart';
import '../core/storage/account_store.dart';
import '../core/storage/token_store.dart';
import '../data/app_database.dart';
import '../data/database_opener.dart';
import '../domain/calendar/timezone_timeline.dart';
import '../domain/provisional_type_rules.dart';
import 'http_sync_transport.dart';
import 'sync_engine.dart';
import 'sync_transport.dart';

/// Best-effort background sync (Phase 3.2b, Android first). The OS decides when it runs; the
/// foreground sync stays the repair path. It runs the same [SyncEngine] on the account's own
/// database and never touches the session: it never refreshes or clears a token, and on a 401
/// it records `reauth_needed` and stops (the foreground app owns the session, G1).
const backgroundSyncTask = 'habit.background_sync';

/// Registration with the OS, per account. A seam so tests and other platforms can fake it.
abstract interface class BackgroundSyncScheduler {
  Future<void> register(String accountKey);
  Future<void> cancel(String accountKey);
}

class WorkmanagerSyncScheduler implements BackgroundSyncScheduler {
  const WorkmanagerSyncScheduler();

  static String uniqueName(String accountKey) => 'sync-${accountKey.toLowerCase()}';

  static Future<void>? _ready;

  /// Once per process, before the first registration or cancellation.
  static Future<void> _initialized() =>
      _ready ??= Workmanager().initialize(backgroundSyncDispatcher);

  @override
  Future<void> register(String accountKey) async {
    await _initialized();
    await Workmanager().registerPeriodicTask(
      uniqueName(accountKey),
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {'account_key': accountKey},
    );
  }

  @override
  Future<void> cancel(String accountKey) async {
    await _initialized();
    await Workmanager().cancelByUniqueName(uniqueName(accountKey));
  }
}

/// The OS calls this in its own isolate (a background Flutter engine).
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final accountKey = input?['account_key'];
    if (task != backgroundSyncTask || accountKey is! String) return true;
    await runBackgroundSync(
      accountKey: accountKey,
      tokens: const SecureTokenStore(),
      accounts: const SecureAccountStore(),
      open: openAccountDatabase,
      transport: (token) => HttpSyncTransport(
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          ),
        ),
      ),
    );
    // Best effort: a failed run is not retried by the OS; the next period or the foreground
    // sync picks it up.
    return true;
  });
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
