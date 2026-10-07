import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';

class HabitApp extends StatelessWidget {
  final GoRouter router;

  const HabitApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // The signed-in account (or null) for every screen, and the foreground sync triggers.
      builder: (context, child) => Consumer<SessionProvider>(
        builder: (context, session, _) => Provider<AccountContext?>.value(
          value: session.account,
          child: _Foreground(account: session.account, child: child ?? const SizedBox()),
        ),
      ),
    );
  }
}

/// Syncs when the app comes back to the foreground (and refreshes an old token first).
class _Foreground extends StatefulWidget {
  final AccountContext? account;
  final Widget child;

  const _Foreground({required this.account, required this.child});

  @override
  State<_Foreground> createState() => _ForegroundState();
}

class _ForegroundState extends State<_Foreground> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => widget.account?.sync.onForeground(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
