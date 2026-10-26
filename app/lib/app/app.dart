import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_version.dart';
import '../config/theme.dart';
import '../core/url_launcher_opener.dart';
import '../core/version_gate.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/version_gated.dart';

class HabitApp extends StatelessWidget {
  final GoRouter router;

  /// A54: the server's minimum build against this one.
  final VersionGate versionGate;

  const HabitApp({super.key, required this.router, required this.versionGate});

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
          child: AppToastScope(
            owner: session.account,
            child: VersionGated(
              gate: versionGate,
              opener: const UrlLauncherOpener(),
              downloadUrl: AppVersion.downloadPageUrl,
              child: _Foreground(account: session.account, child: child ?? const SizedBox()),
            ),
          ),
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
    onResume: () {
      widget.account?.sync.onForeground();
      widget.account?.reminders.replanInBackground();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    widget.account?.reminders.replanInBackground(); // app start
    widget.account?.registerBackground();
  }

  @override
  void didUpdateWidget(_Foreground old) {
    super.didUpdateWidget(old);
    // Sign-in or account switch: this account's reminders are planned again.
    if (old.account != widget.account) {
      widget.account?.reminders.replanInBackground();
      widget.account?.registerBackground();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
