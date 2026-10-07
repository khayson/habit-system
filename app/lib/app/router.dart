import 'package:go_router/go_router.dart';

import '../providers/session_provider.dart';
import '../screens/create_account_screen.dart';
import '../screens/create_habit_screen.dart';
import '../screens/server_status_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/sync_queue_screen.dart';
import '../screens/timezone_screen.dart';
import '../screens/today_screen.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const createAccount = '/create-account';
  static const setup = '/setup';
  static const today = '/today';
  static const newHabit = '/habits/new';
  static const queue = '/sync';

  /// The Phase 0 connection check, kept for diagnostics.
  static const status = '/status';

  /// Reachable without a session.
  static const public = {signIn, createAccount, status};
  static const authOnly = {signIn, createAccount};
}

/// Pure redirect rule, unit-tested on its own.
String? authRedirect({
  required bool isAuthenticated,
  required bool needsSetup,
  required String location,
}) {
  if (!isAuthenticated) return Routes.public.contains(location) ? null : Routes.signIn;
  if (needsSetup && location != Routes.setup) return Routes.setup;
  if (Routes.authOnly.contains(location)) return Routes.today;
  return null;
}

GoRouter buildRouter(SessionProvider session) => GoRouter(
  initialLocation: session.isAuthenticated ? Routes.today : Routes.signIn,
  refreshListenable: session,
  redirect: (context, state) => authRedirect(
    isAuthenticated: session.isAuthenticated,
    needsSetup: session.needsSetup,
    location: state.matchedLocation,
  ),
  routes: [
    GoRoute(path: Routes.signIn, builder: (context, state) => const SignInScreen()),
    GoRoute(path: Routes.createAccount, builder: (context, state) => const CreateAccountScreen()),
    GoRoute(path: Routes.setup, builder: (context, state) => const TimezoneScreen()),
    GoRoute(path: Routes.today, builder: (context, state) => const TodayScreen()),
    GoRoute(path: Routes.newHabit, builder: (context, state) => const CreateHabitScreen()),
    GoRoute(path: Routes.queue, builder: (context, state) => const SyncQueueScreen()),
    GoRoute(path: Routes.status, builder: (context, state) => const ServerStatusScreen()),
  ],
);
