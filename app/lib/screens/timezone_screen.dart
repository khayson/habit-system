import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';
import '../widgets/habit_ui.dart';

/// Screen 04, minimal (Phase 2b.1 review §6): confirm the habit timezone the server holds. Editing
/// it (profile.set_timezone), "Follow device timezone" and the reminder-permission block arrive
/// with Phase 3 and screen 11. Continue goes to Today (05, or 23 when there are no habits yet).
class TimezoneScreen extends StatelessWidget {
  const TimezoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(title: l10n.setupTitle),
            FutureBuilder(
              future: account.session.db.select(account.session.db.syncState).getSingleOrNull(),
              builder: (context, snapshot) {
                final zone = snapshot.data?.calendarTimezone;
                return SurfaceCard(
                  semanticsLabel: zone == null ? null : l10n.setupZoneLabel(zone),
                  child: Row(
                    children: [
                      const IconTile(icon: Icons.schedule),
                      const SizedBox(width: HabitSpace.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cityName(zone ?? ''), style: text.titleLarge),
                            Text(zone ?? '', style: text.bodySmall?.copyWith(color: tokens.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: HabitSpace.s16),
            Text(l10n.setupZoneNote, style: text.bodyMedium?.copyWith(color: tokens.muted)),
            const SizedBox(height: HabitSpace.s48),
            PrimaryButton(
              label: l10n.setupContinue,
              onPressed: () {
                context.read<SessionProvider>().completeSetup();
                context.go(Routes.today);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// "America/Los_Angeles" -> "Los Angeles".
  /// ASSUMPTION(A2b2-zone-name): the design's "Pacific Time" needs CLDR zone names the app does
  /// not ship; the city from the IANA id is shown instead, with the id beneath it.
  static String cityName(String zone) => zone.split('/').last.replaceAll('_', ' ');
}
