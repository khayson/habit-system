import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../config/habit_tokens.dart';
import '../../core/validation.dart';
import '../../data/profile_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../notifications/notification_scheduler.dart';
import '../../providers/account_context.dart';
import '../../services/countries.dart';
import '../../services/photo_picker.dart';
import '../../widgets/habit_ui.dart';
import 'notice_banner.dart';

/// Screen 20's sheets. None of them has a design of its own (design gaps, listed in the 3b.2
/// packet); they use the app's existing sheet, field and button styles.

Widget _sheet(BuildContext context, String title, List<Widget> children) {
  final text = Theme.of(context).textTheme;
  return SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        HabitSpace.margin,
        0,
        HabitSpace.margin,
        HabitSpace.margin + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: HabitSpace.s16),
          ...children,
        ],
      ),
    ),
  );
}

/// Choose photo / Take photo / Remove photo (only when there is one).
Future<void> showPhotoSheet(
  BuildContext context,
  AccountContext account,
  ProfileState profile,
  PhotoPicker picker,
) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => _sheet(sheet, l10n.photoSheetTitle, [
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(sheet, 'gallery'),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(l10n.photoChoose),
      ),
      const SizedBox(height: HabitSpace.s12),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(sheet, 'camera'),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(l10n.photoTake),
      ),
      if (profile.photoPath != null || profile.hasAvatar) ...[
        const SizedBox(height: HabitSpace.s12),
        TextButton.icon(
          onPressed: () => Navigator.pop(sheet, 'remove'),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.photoRemove),
        ),
      ],
    ]),
  );
  if (choice == null) return;
  if (choice == 'remove') {
    await account.photos.remove();
  } else {
    final path = await picker.pick(
      choice == 'camera' ? PhotoSource.camera : PhotoSource.gallery,
      cropTitle: l10n.photoCropTitle,
    );
    if (path == null) return;
    await account.photos.choose(path);
  }
  account.sync.scheduleAfterWrite();
}

/// Edit name, city and country. ASSUMPTION(A3b-profile-edit): no design exists for it.
Future<void> showEditProfileSheet(
  BuildContext context,
  AccountContext account,
  ProfileState profile,
  Countries countries,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _EditProfile(account: account, profile: profile, countries: countries),
);

class _EditProfile extends StatefulWidget {
  final AccountContext account;
  final ProfileState profile;
  final Countries countries;

  const _EditProfile({required this.account, required this.profile, required this.countries});

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _city = TextEditingController(text: widget.profile.city ?? '');
  late String? _country = widget.profile.countryCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _city.addListener(_changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  String? get _nameError {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) return l10n.errorNameRequired;
    if (name.length > Validation.nameMaxLength) return l10n.errorNameTooLong;
    return null;
  }

  String? get _cityError =>
      _city.text.trim().length > 60 ? AppLocalizations.of(context).errorCityTooLong : null;

  bool get _unchanged =>
      _name.text.trim() == widget.profile.name &&
      (_city.text.trim().isEmpty ? null : _city.text.trim()) == widget.profile.city &&
      _country == widget.profile.countryCode;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.account.actions.updateProfile(
        name: _name.text,
        city: _city.text,
        countryCode: _country,
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<_CountryChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CountryPicker(countries: widget.countries, current: _country),
    );
    if (picked != null) setState(() => _country = picked.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    final canSave = !_saving && !_unchanged && _nameError == null && _cityError == null;
    return _sheet(context, l10n.profileEditTitle, [
      FieldLabel(l10n.fieldName),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(hintText: l10n.fieldName, errorText: _nameError),
      ),
      const SizedBox(height: HabitSpace.s16),
      FieldLabel(l10n.fieldCity),
      TextField(
        controller: _city,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: l10n.fieldCity, errorText: _cityError),
      ),
      const SizedBox(height: HabitSpace.s16),
      FieldLabel(l10n.fieldCountry),
      Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r14),
        child: InkWell(
          onTap: _pickCountry,
          borderRadius: BorderRadius.circular(HabitRadius.r14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HabitSize.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.countries.nameOf(_country) ?? l10n.countryNone,
                      style: text.bodyLarge,
                    ),
                  ),
                  Icon(Icons.expand_more, color: tokens.muted),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: HabitSpace.s32),
      PrimaryButton(label: l10n.profileSave, loading: _saving, onPressed: canSave ? _save : null),
    ]);
  }
}

class _CountryChoice {
  final String? code;

  const _CountryChoice(this.code);
}

/// The shared country list, searched by typing; "No country" clears it.
class _CountryPicker extends StatefulWidget {
  final Countries countries;
  final String? current;

  const _CountryPicker({required this.countries, required this.current});

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final matches = widget.countries.search(_query.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HabitSpace.margin),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.countrySearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: HabitSpace.s8),
          Expanded(
            child: ListView(
              children: [
                if (_query.text.trim().isEmpty)
                  ListTile(
                    title: Text(l10n.countryNone, style: text.bodyLarge),
                    selected: widget.current == null,
                    onTap: () => Navigator.pop(context, const _CountryChoice(null)),
                  ),
                for (final c in matches)
                  ListTile(
                    title: Text(c.name, style: text.bodyLarge),
                    trailing: c.code == widget.current ? const Icon(Icons.check) : null,
                    selected: c.code == widget.current,
                    onTap: () => Navigator.pop(context, _CountryChoice(c.code)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The habits that have reminders (each opens live screen 11), the permission state as 11
/// shows it, and "Hide habit names in notifications".
Future<void> showRemindersSheet(
  BuildContext context,
  AccountContext account,
  List<HabitReminders> reminders,
  NotificationPermission? permission,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => _Reminders(
    account: account,
    reminders: reminders,
    permission: permission,
    onOpen: (habitId) {
      Navigator.pop(sheet);
      context.push(Routes.habitReminder(habitId));
    },
  ),
);

class _Reminders extends StatefulWidget {
  final AccountContext account;
  final List<HabitReminders> reminders;
  final NotificationPermission? permission;
  final void Function(String habitId) onOpen;

  const _Reminders({
    required this.account,
    required this.reminders,
    required this.permission,
    required this.onOpen,
  });

  @override
  State<_Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<_Reminders> {
  bool? _hide;
  late NotificationPermission? _permission = widget.permission;

  @override
  void initState() {
    super.initState();
    widget.account.reminders.hideHabitNames().then((on) {
      if (mounted) setState(() => _hide = on);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return _sheet(context, l10n.remindersSheetTitle, [
      if (_permission == NotificationPermission.denied) ...[
        NoticeBanner(
          tone: Tone.warning,
          title: l10n.reminderDeniedTitle,
          body: l10n.reminderDeniedBody,
          action: l10n.reminderOpenDeviceSettings,
          onAction: () => widget.account.permission.openSettings(),
        ),
        const SizedBox(height: HabitSpace.s16),
      ] else if (_permission == NotificationPermission.unknown) ...[
        NoticeBanner(
          tone: Tone.info,
          title: l10n.reminderAskTitle,
          body: l10n.reminderAskBody,
          action: l10n.remindersAllow,
          onAction: () async {
            final state = await widget.account.permission.allow();
            if (mounted) setState(() => _permission = state);
          },
        ),
        const SizedBox(height: HabitSpace.s16),
      ],
      if (widget.reminders.isEmpty)
        Text(l10n.remindersSheetEmpty, style: text.bodyMedium?.copyWith(color: tokens.muted))
      else
        for (final r in widget.reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: HabitSpace.s8),
            child: SurfaceCard(
              onTap: () => widget.onOpen(r.habitId),
              semanticsLabel: l10n.remindersSheetHabitLabel(r.habitName),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.habitName, style: text.titleMedium),
                          const SizedBox(height: HabitSpace.s4),
                          Text(
                            l10n.profileRemindersCount(r.enabled),
                            style: text.bodySmall?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: tokens.primary),
                  ],
                ),
              ),
            ),
          ),
      const SizedBox(height: HabitSpace.s16),
      Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(HabitRadius.r16),
        child: SwitchListTile(
          value: _hide ?? false,
          onChanged: _hide == null
              ? null
              : (on) async {
                  setState(() => _hide = on);
                  await widget.account.reminders.setHideHabitNames(on);
                },
          title: Text(l10n.hideNamesTitle, style: text.titleMedium),
          subtitle: Text(l10n.hideNamesBody, style: text.bodySmall?.copyWith(color: tokens.muted)),
        ),
      ),
    ]);
  }
}

/// ASSUMPTION(A3b-signout): neutral wording, no guilt; only shown when something is unsynced.
Future<bool> confirmSignOut(BuildContext context, int unsynced) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.signOutTitle),
      content: Text(l10n.signOutUnsynced(unsynced)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.signOut)),
      ],
    ),
  );
  return confirmed == true;
}
