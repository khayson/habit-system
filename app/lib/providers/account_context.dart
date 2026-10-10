import 'dart:io' show Directory;
import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_version.dart';
import '../core/network/api_client.dart';
import '../core/time_zones.dart';
import '../data/habit_detail_view.dart';
import '../data/local_mutation_service.dart';
import '../data/local_view.dart';
import '../data/photo_service.dart';
import '../data/profile_view.dart';
import '../data/timezone_view.dart';
import '../domain/provisional_type_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/reminder_permission.dart';
import '../notifications/reminder_scheduling.dart';
import '../services/auth_service.dart';
import '../services/habit_actions.dart';
import '../services/heatmap_service.dart';
import '../background/workmanager_sync.dart';
import '../sync/avatar_sync.dart';
import '../sync/avatar_transport.dart';
import '../sync/background_sync.dart';
import '../sync/http_avatar_transport.dart';
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

  /// Best-effort background sync registration (Phase 3.2b); null where there is none (tests).
  final BackgroundSyncScheduler? background;

  /// Phase 3b: the account's own folder for files (the profile photo).
  final String filesRoot;

  AccountContext({
    required this.session,
    this.heatmap,
    NotificationScheduler? notifications,
    this.background,
    required SyncTransport transport,
    AvatarTransport? avatarTransport,
    String? filesRoot,
    required Future<void> Function() refreshIfStale,
    Stream<bool>? connectivity,
    DateTime Function()? clock,
  }) : _clock = clock,
       filesRoot = filesRoot ?? '${Directory.systemTemp.path}/habit_${session.userId}_files',
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
           avatars: avatarTransport == null
               ? null
               : AvatarSync(
                   db: session.db,
                   transport: avatarTransport,
                   filesRoot:
                       filesRoot ?? '${Directory.systemTemp.path}/habit_${session.userId}_files',
                   clock: clock,
                 ),
         ),
         refreshIfStale: refreshIfStale,
         connectivity: connectivity,
       ),
       queue = StreamModel(Future.value(LocalView(session.db).watchQueue()));

  final DateTime Function()? _clock;

  /// Phase 3b: screen 20's data and the photo on this device.
  late final ProfileView profile = ProfileView(session.db, filesRoot: filesRoot);
  late final PhotoService photos = PhotoService(session.db, filesRoot: filesRoot, clock: _clock);

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

  /// App start and sign-in: this account's background sync is registered (idempotent).
  Future<void> registerBackground() async => background?.register(session.userId);

  /// Logout (not a token rejection): this account's notifications and background task go;
  /// another account's stay.
  Future<void> endForLogout() async {
    await reminders.cancelAll();
    await background?.cancel(session.userId);
  }

  late final HabitActions actions = HabitActions(
    writer,
    onLocalWrite: sync.scheduleAfterWrite,
    clock: _clock,
  );

  /// The production wiring: HTTP transport over the shared ApiClient, connectivity_plus as a
  /// trigger only.
  factory AccountContext.live(
    AccountSession session,
    ApiClient api,
    AuthService auth, {
    required String filesRoot,
  }) => AccountContext(
    session: session,
    heatmap: HeatmapService(api),
    background: const WorkmanagerSyncScheduler(),
    transport: HttpSyncTransport(api.dio, currentToken: api.currentToken),
    avatarTransport: HttpAvatarTransport(api.dio),
    filesRoot: filesRoot,
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
