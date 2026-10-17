import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/time_zones.dart';
import '../core/url_launcher_opener.dart';
import '../core/url_opener.dart';
import '../providers/session_provider.dart';
import '../services/photo_picker.dart';
import '../screens/amount_entry_screen.dart';
import '../screens/app_shell.dart';
import '../screens/archived_habits_screen.dart';
import '../screens/create_account_screen.dart';
import '../screens/conflict_review_screen.dart';
import '../screens/create_habit_screen.dart';
import '../screens/edit_habit_screen.dart';
import '../screens/frequency_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/habit_library_screen.dart';
import '../screens/freezes_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/history_screen.dart';
import '../screens/reminder_editor_screen.dart';
import '../screens/server_status_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/sync_queue_screen.dart';
import '../screens/timer_screen.dart';
import '../screens/timezone_screen.dart';
import '../screens/today_screen.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const createAccount = '/create-account';
  static const setup = '/setup';
  static const today = '/today';
  static const habits = '/habits';
  static const profile = '/profile';
  static const newHabit = '/habits/new';
  static String habit(String id) => '/habits/$id';

  /// Screen 09 for one habit.
  static String editHabit(String id) => '/habits/$id/edit';

  /// Screen 34 (4.3b): add an amount (extra: a prefilled amount in the type's units).
  static String amount(String id) => '/habits/$id/add';

  /// Screens 33 / 36 (4.3b): the habit's timer, running or paused.
  static String timer(String id) => '/habits/$id/timer';

  /// Screen 22. Matched before '/habits/:id' (router test).
  static const archivedHabits = '/habits/archived';

  /// Screen 13 for one habit, optionally with a chosen local date (from 12's calendar).
  static String history(String id, {String? date}) => Uri(
    path: '/habits/$id/history',
    queryParameters: date == null ? null : {'date': date},
  ).toString();
  static const queue = '/sync';

  /// Screens 16 and 17 (5.2b), inside the shell with Profile selected, as designed.
  static const rewards = '/rewards';
  static const freezes = '/freezes';

  /// Screen 19 (4.3c): review one change that needs a look.
  static String review(String mutationId) => '/sync/review/$mutationId';

  /// Screen 10 for 08 and 09 (extra: FrequencyRequest); pops a FrequencyChoice.
  static const frequency = '/frequency';

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
/// [clock], [registrationZone], [urlOpener] and [photoPicker] are seams for tests.
List<RouteBase> appRoutes({
  DateTime Function() clock = DateTime.now,
  DeviceTimezone? registrationZone,
  UrlOpener? urlOpener,
  PhotoPicker? photoPicker,
}) => [
  GoRoute(path: Routes.signIn, builder: (context, state) => const SignInScreen()),
  GoRoute(
    path: Routes.createAccount,
    builder: (context, state) => CreateAccountScreen(
      timezone: registrationZone ?? deviceTimezone,
      urlOpener: urlOpener ?? const UrlLauncherOpener(),
    ),
  ),
  GoRoute(
    path: Routes.setup,
    builder: (context, state) => TimezoneScreen(clock: clock),
  ),
  GoRoute(
    path: Routes.newHabit,
    builder: (context, state) => CreateHabitScreen(clock: clock),
  ),
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
    path: '/habits/:id/add',
    builder: (context, state) => AmountEntryScreen(
      habitId: state.pathParameters['id']!,
      prefill: state.extra is int ? state.extra! as int : null,
      clock: clock,
    ),
  ),
  GoRoute(
    path: '/habits/:id/timer',
    builder: (context, state) => TimerScreen(habitId: state.pathParameters['id']!, clock: clock),
  ),
  GoRoute(
    path: '/habits/:id/edit',
    builder: (context, state) =>
        EditHabitScreen(habitId: state.pathParameters['id']!, clock: clock),
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
      GoRoute(
        path: Routes.habits,
        builder: (context, state) => HabitLibraryScreen(clock: clock),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => ProfileScreen(
          picker: photoPicker ?? const DevicePhotoPicker(),
          urlOpener: urlOpener ?? const UrlLauncherOpener(),
          clock: clock,
        ),
      ),
      // Before '/habits/:id', so "archived" is never read as a habit id.
      GoRoute(
        path: Routes.archivedHabits,
        builder: (context, state) => ArchivedHabitsScreen(clock: clock),
      ),
      GoRoute(
        path: Routes.rewards,
        builder: (context, state) => ProgressScreen(clock: clock),
      ),
      GoRoute(
        path: Routes.freezes,
        builder: (context, state) => FreezesScreen(clock: clock),
      ),
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
  GoRoute(
    path: Routes.frequency,
    // 4.2b I1: opened without its request (restored or deep-linked): back to Today.
    redirect: (context, state) => state.extra is FrequencyRequest ? null : Routes.today,
    builder: (context, state) => FrequencyScreen(request: state.extra! as FrequencyRequest),
  ),
  GoRoute(path: Routes.queue, builder: (context, state) => const SyncQueueScreen()),
  GoRoute(
    path: '/sync/review/:mutationId',
    builder: (context, state) =>
        ConflictReviewScreen(mutationId: state.pathParameters['mutationId']!, clock: clock),
  ),
  GoRoute(path: Routes.status, builder: (context, state) => const ServerStatusScreen()),
];
