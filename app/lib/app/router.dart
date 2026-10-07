import 'package:go_router/go_router.dart';

import '../providers/session_provider.dart';
import '../screens/protected_placeholder_screen.dart';
import '../screens/server_status_screen.dart';

abstract final class Routes {
  static const status = '/';
  static const today = '/today';

  /// Reachable without a session.
  static const public = {status};
}

/// Pure redirect rule, unit-tested on its own.
String? authRedirect({required bool isAuthenticated, required String location}) {
  if (!isAuthenticated && !Routes.public.contains(location)) return Routes.status;
  return null;
}

GoRouter buildRouter(SessionProvider session) => GoRouter(
  initialLocation: session.isAuthenticated ? Routes.today : Routes.status,
  refreshListenable: session,
  redirect: (context, state) =>
      authRedirect(isAuthenticated: session.isAuthenticated, location: state.matchedLocation),
  routes: [
    GoRoute(path: Routes.status, builder: (context, state) => const ServerStatusScreen()),
    GoRoute(path: Routes.today, builder: (context, state) => const ProtectedPlaceholderScreen()),
  ],
);
