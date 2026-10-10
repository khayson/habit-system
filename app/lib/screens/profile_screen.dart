import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/time_zones.dart';
import '../core/url_launcher_opener.dart';
import '../core/url_opener.dart';
import '../data/profile_view.dart';
import '../data/timezone_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/notification_scheduler.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';
import '../providers/stream_model.dart';
import '../services/countries.dart';
import '../services/photo_picker.dart';
import '../widgets/avatar_view.dart';
import '../widgets/habit_ui.dart';
import '../widgets/legal_links.dart';
import 'widgets/profile_sheets.dart';

/// Screen 20 (A20): the avatar card, Timezone and Reminders rows and "Signed in as", as
/// designed. Privacy and export (21, Phase 6) and Archived habits (22, Phase 4) arrive with
/// their screens. Sign out and the Terms and Privacy links are design gaps, below the design's
/// content (ASSUMPTION(A3b-signout); 21 carries the links as designed in Phase 6).
class ProfileScreen extends StatelessWidget {
  final PhotoPicker picker;
  final UrlOpener urlOpener;
  final DateTime Function() clock;

  const ProfileScreen({
    super.key,
    this.picker = const DevicePhotoPicker(),
    this.urlOpener = const UrlLauncherOpener(),
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    return MultiProvider(
      key: ValueKey(account.session.userId),
      providers: [
        ChangeNotifierProvider(
          create: (_) => StreamModel<ProfileState?>(Future.value(account.profile.watch())),
        ),
        ChangeNotifierProvider(
          create: (_) => StreamModel<TimezoneStatus?>(
            TimeZones.ready.then((_) => DeviceSettings(account.session.db).watch(clock)),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StreamModel<List<HabitReminders>>(
            Future.value(account.profile.watchReminders(account.view)),
          ),
        ),
      ],
      child: _Profile(picker: picker, urlOpener: urlOpener),
    );
  }
}

class _Profile extends StatefulWidget {
  final PhotoPicker picker;
  final UrlOpener urlOpener;

  const _Profile({required this.picker, required this.urlOpener});

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> with WidgetsBindingObserver {
  NotificationPermission? _permission;
  Countries? _countries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPermission());
    Countries.load().then((c) {
      if (mounted) setState(() => _countries = c);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the device settings: show what the OS says now.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    final state = await account.permission.state();
    if (mounted) setState(() => _permission = state);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final account = context.read<AccountContext?>()!;
    final profile = context.watch<StreamModel<ProfileState?>>().value;
    final zone = context.watch<StreamModel<TimezoneStatus?>>().value;
    final reminders = context.watch<StreamModel<List<HabitReminders>>>().value ?? const [];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HabitSpace.margin),
        children: [
          ScreenHeader(
            title: l10n.profileTitle,
            subtitle: l10n.profileSubtitle,
            onBack: () => context.canPop() ? context.pop() : context.go(Routes.today),
          ),
          if (profile != null)
            _AvatarCard(
              profile: profile,
              countries: _countries,
              onPhoto: () => showPhotoSheet(context, account, profile, widget.picker),
              onEdit: _countries == null
                  ? null
                  : () => showEditProfileSheet(context, account, profile, _countries!),
            ),
          const SizedBox(height: HabitSpace.s24),
          _Row(
            icon: Icons.schedule,
            title: l10n.profileTimezone,
            subtitle: _zoneLine(l10n, zone),
            trailing: TextButton(
              onPressed: () => context.push(Routes.setup),
              child: Semantics(label: l10n.profileTimezoneEditLabel, child: Text(l10n.setupEdit)),
            ),
          ),
          const SizedBox(height: HabitSpace.s16),
          _Row(
            icon: Icons.notifications_none,
            title: l10n.profileReminders,
            subtitle: l10n.profileRemindersLine(
              l10n.profileRemindersCount(reminders.fold(0, (n, r) => n + r.enabled)),
              switch (_permission) {
                NotificationPermission.authorized ||
                NotificationPermission.provisional => l10n.profileNotificationsOn,
                NotificationPermission.denied => l10n.profileNotificationsOff,
                _ => l10n.profileNotificationsUnknown,
              },
            ),
            onTap: () async {
              await showRemindersSheet(context, account, reminders, _permission);
              await _refreshPermission();
            },
          ),
          const SizedBox(height: HabitSpace.s48),
          if (profile?.email != null)
            Text(
              l10n.signedInAs(profile!.email!),
              style: text.bodyMedium?.copyWith(color: tokens.muted),
            ),
          const SizedBox(height: HabitSpace.s16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: profile == null ? null : () => _signOut(context, profile),
              style: TextButton.styleFrom(
                minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
              ),
              child: Text(l10n.signOut),
            ),
          ),
          LegalLinks(opener: widget.urlOpener),
        ],
      ),
    );
  }

  String _zoneLine(AppLocalizations l10n, TimezoneStatus? status) {
    if (status == null) return '';
    if (status.queuedZone != null) return l10n.setupQueued(status.queuedZone!);
    return status.inForce;
  }

  Future<void> _signOut(BuildContext context, ProfileState profile) async {
    final session = context.read<SessionProvider>();
    if (profile.unsynced > 0 && !await confirmSignOut(context, profile.unsynced)) return;
    await session.signOut();
  }
}

class _AvatarCard extends StatelessWidget {
  final ProfileState profile;
  final Countries? countries;
  final VoidCallback onPhoto;
  final VoidCallback? onEdit;

  const _AvatarCard({
    required this.profile,
    required this.countries,
    required this.onPhoto,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final place = [
      ?profile.city,
      ?(countries?.nameOf(profile.countryCode) ?? profile.countryCode),
    ].join(', ');
    // ASSUMPTION(A3b-level-line): the design's "· Level 13 · 1,250 XP" waits for the A13c
    // rewards flag (Phase 5); until then the line shows the place only.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: HabitSpace.s32, horizontal: HabitSpace.s16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Column(
        children: [
          AvatarView(
            photoPath: profile.photoPath,
            initials: profile.initials,
            name: profile.name,
            size: AvatarSize.large,
            onTap: onPhoto,
            tapHint: l10n.avatarChangeHint,
          ),
          const SizedBox(height: HabitSpace.s24),
          Text(profile.name, style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: HabitSpace.s8),
          Text(
            place.isEmpty ? l10n.profileLocationEmpty : place,
            style: text.bodyMedium?.copyWith(color: tokens.muted),
            textAlign: TextAlign.center,
          ),
          if (profile.editQueued) ...[
            const SizedBox(height: HabitSpace.s8),
            _Note(icon: Icons.schedule, text: l10n.profileEditQueued),
          ],
          if (profile.uploadRejected) ...[
            const SizedBox(height: HabitSpace.s12),
            Text(
              l10n.photoRejected,
              style: text.bodyMedium?.copyWith(color: tokens.ink),
              textAlign: TextAlign.center,
            ),
          ] else if (profile.uploadPending) ...[
            const SizedBox(height: HabitSpace.s8),
            _Note(icon: Icons.cloud_upload_outlined, text: l10n.photoWaiting),
          ],
          const SizedBox(height: HabitSpace.s8),
          TextButton(onPressed: onEdit, child: Text(l10n.profileEdit)),
        ],
      ),
    );
  }
}

/// A waiting state on the card: a symbol and words (never colour alone), wrapping at any text
/// size.
class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.infoInk);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: HabitSize.icon, color: tokens.infoInk),
        const SizedBox(width: HabitSpace.s8),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

/// One of the design's rows: an icon tile, a title and a muted line, then an action or a
/// chevron.
class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final content = Row(
      children: [
        IconTile(icon: icon),
        const SizedBox(width: HabitSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium ?? text.bodyLarge),
              const SizedBox(height: HabitSpace.s4),
              Text(subtitle, style: text.bodySmall?.copyWith(color: tokens.muted)),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (onTap != null)
          Icon(Icons.chevron_right, color: tokens.primary),
      ],
    );
    return SurfaceCard(
      onTap: onTap,
      semanticsLabel: onTap == null ? null : '$title, $subtitle',
      child: onTap == null ? content : ExcludeSemantics(child: content),
    );
  }
}
