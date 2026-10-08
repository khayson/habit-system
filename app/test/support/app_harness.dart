import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit/app/router.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/core/time_zones.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/providers/session_provider.dart';
import 'package:habit/screens/create_account_screen.dart';
import 'package:habit/screens/create_habit_screen.dart';
import 'package:habit/screens/sign_in_screen.dart';
import 'package:habit/screens/sync_queue_screen.dart';
import 'package:habit/screens/timezone_screen.dart';
import 'package:habit/screens/today_screen.dart';
import 'package:habit/services/auth_service.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:provider/provider.dart';

import 'fake_sync_server.dart';

/// 17:22 UTC on 28 May 2026 is 10:22 in Los Angeles (the design file's clock).
final testNow = DateTime.utc(2026, 5, 28, 17, 22);

void loadTestZones() {
  TimeZones.load();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}

/// One signed-in account on an in-memory database, talking to [server].
Future<AccountContext> testAccount(
  FakeSyncServer server, {
  Stream<bool>? connectivity,
  DateTime Function()? clock,
}) async {
  // Widget tests: streams must close synchronously or closing the database waits forever on a
  // query parked in fake async (drift docs, "Testing").
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  await initAccountState(
    db,
    userId: 'user-1',
    deviceId: '01970000-0000-7000-8000-00000000d001',
    user: server.user,
  );
  return AccountContext(
    session: AccountSession(userId: 'user-1', deviceId: 'd', db: db),
    transport: server,
    refreshIfStale: () async {},
    connectivity: connectivity,
    clock: clock ?? () => testNow,
  );
}

/// The real screens behind a router, themed and localised like the app. With [session], the
/// app's redirect rule runs and the account comes from the session, as in production.
Widget testApp({
  required String initial,
  AccountContext? account,
  SessionProvider? session,
  DateTime Function()? clock,
}) {
  final router = GoRouter(
    initialLocation: initial,
    refreshListenable: session,
    redirect: session == null
        ? null
        : (context, state) => authRedirect(
            isAuthenticated: session.isAuthenticated,
            needsSetup: session.needsSetup,
            location: state.matchedLocation,
          ),
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.createAccount,
        builder: (_, _) => CreateAccountScreen(timezone: () async => 'America/Los_Angeles'),
      ),
      GoRoute(path: Routes.setup, builder: (_, _) => const TimezoneScreen()),
      GoRoute(
        path: Routes.today,
        builder: (_, _) => TodayScreen(clock: clock ?? () => testNow),
      ),
      GoRoute(path: Routes.newHabit, builder: (_, _) => const CreateHabitScreen()),
      GoRoute(path: Routes.queue, builder: (_, _) => const SyncQueueScreen()),
    ],
  );
  final materialApp = MaterialApp.router(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
  if (session == null) return Provider<AccountContext?>.value(value: account, child: materialApp);
  return ChangeNotifierProvider.value(
    value: session,
    child: Consumer<SessionProvider>(
      builder: (context, s, child) =>
          Provider<AccountContext?>.value(value: s.account, child: child),
      child: materialApp,
    ),
  );
}

/// A phone-width (411 dp) viewport, tall enough that a whole form is built without scrolling.
void useTallPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(1080, 4200);
  addTearDown(tester.view.reset);
}

/// Lets real async work (drift, futures) run, then pumps frames. Drift runs on real I/O, so
/// plain fake-async pumping never lets its queries finish.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts the app (cancelling its watch-queries and timers) and closes the database.
Future<void> tearDownApp(WidgetTester tester, AccountContext account) async {
  await tester.pumpWidget(const SizedBox());
  account.dispose();
  await tester.runAsync(() => account.session.db.close());
}

/// Runs a sync with the engine outside fake async.
Future<SyncOutcome> syncNow(WidgetTester tester, AccountContext account) async =>
    (await tester.runAsync(() => account.sync.sync(force: true)))!;

/// A transport whose every call fails as offline.
class OfflineTransport implements SyncTransport {
  @override
  Future<SyncPage> sync({
    required String deviceId,
    required String? cursor,
    required int pullLimit,
    required List<Map<String, Object?>> mutations,
    required List<String> capabilities,
  }) => Future.error(const SyncTransportException(SyncFailure.network));

  @override
  Future<BootstrapPage> bootstrap({required String? cursor, required int limit}) =>
      Future.error(const SyncTransportException(SyncFailure.network));
}

/// Keeps a connectivity stream open for a test.
StreamController<bool> connectivityController() => StreamController<bool>.broadcast();
