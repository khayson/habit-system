import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../config/api_config.dart';
import '../core/storage/account_store.dart';
import '../core/storage/token_store.dart';
import '../data/database_opener.dart';
import '../sync/background_sync.dart';
import '../sync/http_sync_transport.dart';

/// The OS side of background sync (Phase 3.2b): WorkManager registration per account and the
/// entry point the OS calls. The run itself is [runBackgroundSync] (pure Dart).
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
