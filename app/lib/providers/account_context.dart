import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_version.dart';
import '../core/network/api_client.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../data/timezone_view.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/reminder_permission.dart';
import '../notifications/reminder_scheduling.dart';
import '../services/auth_service.dart';
import '../services/habit_actions.dart';
import '../services/heatmap_service.dart';
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

  /// Older heatmap months (screen 12); null where there is no server (tests, offline-only).
  final RemoteHeatmap? heatmap;

  /// The device's notification scheduler (Phase 3.2b); one per device, shared by accounts.
  final NotificationScheduler notifications;

  AccountContext({
    required this.session,
    this.heatmap,
    NotificationScheduler? notifications,
    required SyncTransport transport,
    required Future<void> Function() refreshIfStale,
    Stream<bool>? connectivity,
    DateTime Function()? clock,
  }) : _clock = clock,
       notifications = notifications ?? LocalNotificationsScheduler(),
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

  late final ReminderPermission permission = ReminderPermission(
    DeviceSettings(session.db),
    notifications,
  );

  ReminderScheduling? _reminders;

  /// This account's reminders on the OS schedule: replanned on changes, start and resume.
  /// Created (and started) on first use.
  ReminderScheduling get reminders => _reminders ??= ReminderScheduling(
    db: session.db,
    view: view,
    scheduler: notifications,
    accountKey: session.userId,
    deviceZone: DeviceZone.read,
    title: (name) => name,
    body: lookupAppLocalizations(PlatformDispatcher.instance.locale).reminderBody,
    clock: _clock,
  )..start();

  /// Logout (not a token rejection): this account's notifications go; another account's stay.
  Future<void> endForLogout() => reminders.cancelAll();

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
        heatmap: HeatmapService(api),
        transport: HttpSyncTransport(api.dio, currentToken: api.currentToken),
        refreshIfStale: auth.refreshIfStale,
        connectivity: Connectivity().onConnectivityChanged.map(
          (results) => results.any((r) => r != ConnectivityResult.none),
        ),
      );

  void dispose() {
    _reminders?.dispose();
    sync.dispose();
    queue.dispose();
  }
}
