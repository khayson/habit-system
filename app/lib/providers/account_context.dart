import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_version.dart';
import '../core/network/api_client.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../domain/provisional_type_rules.dart';
import '../services/auth_service.dart';
import '../services/habit_actions.dart';
import '../sync/http_sync_transport.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_transport.dart';
import 'stream_model.dart';
import 'sync_provider.dart';

/// Everything that belongs to one signed-in account: its database, writer, view, one sync
/// engine and the queue stream. Built on sign-in, disposed on sign-out; another account never
/// shares any of it.
class AccountContext {
  final AccountSession session;
  final LocalMutationService writer;
  final LocalView view;
  final SyncProvider sync;
  final StreamModel<QueueView> queue;

  AccountContext({
    required this.session,
    required SyncTransport transport,
    required Future<void> Function() refreshIfStale,
    Stream<bool>? connectivity,
    DateTime Function()? clock,
  }) : _clock = clock,
       writer = LocalMutationService(session.db, clock: clock),
       view = LocalView(session.db),
       sync = SyncProvider(
         engine: SyncEngine(
           db: session.db,
           transport: transport,
           capabilities: ProvisionalTypeRegistry.builtins().keys.toList(),
           clock: clock,
           appVersion: AppVersion.current,
         ),
         refreshIfStale: refreshIfStale,
         connectivity: connectivity,
       ),
       queue = StreamModel(Future.value(LocalView(session.db).watchQueue()));

  final DateTime Function()? _clock;

  late final HabitActions actions = HabitActions(
    writer,
    onLocalWrite: sync.scheduleAfterWrite,
    clock: _clock,
  );

  /// The production wiring: HTTP transport over the shared ApiClient, connectivity_plus as a
  /// trigger only.
  factory AccountContext.live(AccountSession session, ApiClient api, AuthService auth) =>
      AccountContext(
        session: session,
        transport: HttpSyncTransport(api.dio, currentToken: api.currentToken),
        refreshIfStale: auth.refreshIfStale,
        connectivity: Connectivity().onConnectivityChanged.map(
          (results) => results.any((r) => r != ConnectivityResult.none),
        ),
      );

  void dispose() {
    sync.dispose();
    queue.dispose();
  }
}
