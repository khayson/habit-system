import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../data/account_calendar.dart';
import '../data/timezone_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';
import '../providers/stream_model.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';

/// Screen 04: the habit timezone. Edit writes profile.set_timezone through the writer (queued
/// offline, applied by the server from the start of the next day, A26); choosing the zone in
/// force cancels a pending change. "Follow device timezone" is a per-device setting
/// (ASSUMPTION(A3.2-follow-device)) that turns on the ask-on-change card on Today. The
/// reminder-permission block arrives with Phase 3.2b.
class TimezoneScreen extends StatelessWidget {
  final DateTime Function() clock;

  const TimezoneScreen({super.key, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return ChangeNotifierProvider(
      key: ValueKey(account.session.userId),
      create: (_) => StreamModel<TimezoneStatus?>(
        TimeZones.ready.then((_) => DeviceSettings(account.session.db).watch(clock)),
      ),
      child: const _Timezone(),
    );
  }

  /// "America/Los_Angeles" -> "Los Angeles".
  /// ASSUMPTION(A2b2-zone-name): the design's "Pacific Time" needs CLDR zone names the app does
  /// not ship; the city from the IANA id is shown instead, with the id beneath it.
  static String cityName(String zone) => zone.split('/').last.replaceAll('_', ' ');
}

class _Timezone extends StatelessWidget {
  const _Timezone();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final format = HabitFormat(context);
    final account = context.read<AccountContext?>()!;
    final status = context.watch<StreamModel<TimezoneStatus?>>().value;
    final zone = status?.inForce ?? '';

    String? line;
    if (status != null) {
      final pending = status.pending;
      if (status.queuedNeedsAttention) {
        line = l10n.setupQueuedProblem;
      } else if (status.queuedZone != null) {
        line = l10n.setupQueued(TimezoneScreen.cityName(status.queuedZone!));
      } else if (pending != null) {
        line = l10n.setupPending(
          TimezoneScreen.cityName(pending.timezone),
          format.time(AccountCalendar.wallClockIn(status.inForce, pending.effectiveAt)),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.setupTitle,
              subtitle: l10n.setupSubtitle,
              onBack: context.canPop() ? () => context.pop() : null,
            ),
            SurfaceCard(
              semanticsLabel: zone.isEmpty ? null : l10n.setupZoneLabel(zone),
              child: Row(
                children: [
                  const ExcludeSemantics(child: IconTile(icon: Icons.schedule)),
                  const SizedBox(width: HabitSpace.s16),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(TimezoneScreen.cityName(zone), style: text.titleLarge),
                          Text(zone, style: text.bodySmall?.copyWith(color: tokens.muted)),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: status == null ? null : () => _edit(context, account, status),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                    ),
                    child: Semantics(
                      label: l10n.setupEditZone,
                      excludeSemantics: true,
                      child: Text(l10n.setupEdit),
                    ),
                  ),
                ],
              ),
            ),
            if (line != null) ...[
              const SizedBox(height: HabitSpace.s12),
              Semantics(
                liveRegion: true,
                child: Text(line, style: text.bodyMedium?.copyWith(color: tokens.primary)),
              ),
            ],
            const SizedBox(height: HabitSpace.s16),
            Text(l10n.setupZoneNote, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            const SizedBox(height: HabitSpace.s32),
            Material(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(HabitRadius.r24),
              child: SwitchListTile(
                value: status?.followDevice ?? false,
                onChanged: status == null
                    ? null
                    : (on) => DeviceSettings(account.session.db).setFollowDevice(on),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HabitSpace.s24,
                  vertical: HabitSpace.s16,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HabitRadius.r24)),
                title: Text(l10n.setupFollow, style: text.titleMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: HabitSpace.s8),
                  child: Text(
                    l10n.setupFollowNote,
                    style: text.bodySmall?.copyWith(color: tokens.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: HabitSpace.s48),
            PrimaryButton(
              label: l10n.setupContinue,
              onPressed: () {
                final session = context.read<SessionProvider>();
                if (session.needsSetup) session.completeSetup();
                context.canPop() ? context.pop() : context.go(Routes.today);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, AccountContext account, TimezoneStatus status) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ZonePicker(current: status.target),
    );
    if (chosen == null || chosen == status.target) return;
    await account.actions.setTimezone(chosen);
  }
}

/// The searchable zone list: every canonical tz database zone, city name plus current offset.
class ZonePicker extends StatefulWidget {
  final String current;

  const ZonePicker({super.key, required this.current});

  /// Canonical "Area/City" zones (no Etc/, no legacy aliases such as US/Pacific).
  static List<String> zones() {
    const areas = {
      'Africa',
      'America',
      'Antarctica',
      'Asia',
      'Atlantic',
      'Australia',
      'Europe',
      'Indian',
      'Pacific',
    };
    return tz.timeZoneDatabase.locations.keys
        .where((z) => z.contains('/') && areas.contains(z.split('/').first))
        .toList()
      ..sort((a, b) => TimezoneScreen.cityName(a).compareTo(TimezoneScreen.cityName(b)));
  }

  /// "UTC+05:30" at this moment.
  static String offset(String zone, DateTime now) {
    final minutes = tz.TZDateTime.from(now, tz.getLocation(zone)).timeZoneOffset.inMinutes;
    final sign = minutes < 0 ? '−' : '+';
    final abs = minutes.abs();
    return 'UTC$sign${(abs ~/ 60).toString().padLeft(2, '0')}:${(abs % 60).toString().padLeft(2, '0')}';
  }

  @override
  State<ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<ZonePicker> {
  final _search = TextEditingController();
  late final List<String> _zones = ZonePicker.zones();
  final _now = DateTime.now().toUtc();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final query = _search.text.trim().toLowerCase().replaceAll(' ', '_');
    final shown = query.isEmpty
        ? _zones
        : _zones.where((z) => z.toLowerCase().contains(query)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HabitSpace.margin,
              HabitSpace.s24,
              HabitSpace.margin,
              HabitSpace.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(l10n.zonePickerTitle, style: text.titleLarge)),
                const SizedBox(height: HabitSpace.s8),
                Text(l10n.setupNextDay, style: text.bodyMedium?.copyWith(color: tokens.muted)),
                const SizedBox(height: HabitSpace.s16),
                TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: l10n.zoneSearch),
                ),
              ],
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(HabitSpace.margin),
              child: Text(l10n.zoneNoMatch, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final zone = shown[i];
                final selected = zone == widget.current;
                return ListTile(
                  minTileHeight: HabitSize.control,
                  contentPadding: const EdgeInsets.symmetric(horizontal: HabitSpace.margin),
                  selected: selected,
                  title: Text(
                    l10n.zoneRow(TimezoneScreen.cityName(zone), ZonePicker.offset(zone, _now)),
                  ),
                  subtitle: Text(zone),
                  trailing: selected ? Icon(Icons.check, color: tokens.primary) : null,
                  onTap: () => Navigator.of(context).pop(zone),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
