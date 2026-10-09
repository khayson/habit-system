import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_provider.dart';
import '../screens/app_shell.dart';
import '../screens/create_account_screen.dart';
import '../screens/create_habit_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/habit_library_screen.dart';
import '../screens/history_screen.dart';
import '../screens/reminder_editor_screen.dart';
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
  static const habits = '/habits';
  static const newHabit = '/habits/new';
  static String habit(String id) => '/habits/$id';

  /// Screen 13 for one habit, optionally with a chosen local date (from 12's calendar).
  static String history(String id, {String? date}) => Uri(
    path: '/habits/$id/history',
    queryParameters: date == null ? null : {'date': date},
  ).toString();
  static const queue = '/sync';

  /// Screen 11 for 08's reminder draft (extra: (ReminderDraft?, habit name)).
  static const reminderEditor = '/reminders/edit';

  /// Screen 11 in live mode for a habit that exists (12's Reminder row, 3.2c).
  static String habitReminder(String habitId, {String? reminderId}) => Uri(
    path: '/habits/$habitId/reminder',
    queryParameters: reminderId == null ? null : {'reminder': reminderId},
  ).toString();

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
  routes: appRoutes(),
);

/// Every screen's route. Today, Habits and habit detail share the bottom navigation (design
/// 05, 07, 12); history (13) and the editor (08) are full screens without it, as in the design.
/// [clock] and [registrationZone] are seams for tests.
List<RouteBase> appRoutes({
  DateTime Function() clock = DateTime.now,
  DeviceTimezone? registrationZone,
}) => [
  GoRoute(path: Routes.signIn, builder: (context, state) => const SignInScreen()),
  GoRoute(
    path: Routes.createAccount,
    builder: (context, state) => registrationZone == null
        ? const CreateAccountScreen()
        : CreateAccountScreen(timezone: registrationZone),
  ),
  GoRoute(
    path: Routes.setup,
    builder: (context, state) => TimezoneScreen(clock: clock),
  ),
  GoRoute(path: Routes.newHabit, builder: (context, state) => const CreateHabitScreen()),
  GoRoute(
    path: '/habits/:id/reminder',
    builder: (context, state) => ReminderEditorScreen(
      // One screen per reminder: opening another from "Other reminders" loads it afresh.
      key: ValueKey(state.uri.toString()),
      habitId: state.pathParameters['id'],
      reminderId: state.uri.queryParameters['reminder'],
      clock: clock,
    ),
  ),
  GoRoute(
    path: '/habits/:id/history',
    builder: (context, state) => HistoryScreen(
      habitId: state.pathParameters['id']!,
      initialDate: state.uri.queryParameters['date'],
      clock: clock,
    ),
  ),
  ShellRoute(
    builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
    routes: [
      GoRoute(
        path: Routes.today,
        builder: (context, state) => TodayScreen(clock: clock),
      ),
      GoRoute(path: Routes.habits, builder: (context, state) => const HabitLibraryScreen()),
      GoRoute(
        path: '/habits/:id',
        builder: (context, state) =>
            HabitDetailScreen(habitId: state.pathParameters['id']!, clock: clock),
      ),
    ],
  ),
  GoRoute(
    path: Routes.reminderEditor,
    builder: (context, state) {
      final (draft, name) = state.extra is (ReminderDraft?, String)
          ? state.extra! as (ReminderDraft?, String)
          : (null, '');
      return ReminderEditorScreen(draft: draft, habitName: name, clock: clock);
    },
  ),
  GoRoute(path: Routes.queue, builder: (context, state) => const SyncQueueScreen()),
  GoRoute(path: Routes.status, builder: (context, state) => const ServerStatusScreen()),
];
