import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../core/url_opener.dart';
import '../core/version_gate.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_icons.dart';
import 'habit_ui.dart';

/// A54: shows [child] while the server accepts this build; otherwise a calm full-screen
/// "Please update" whose only way forward is the download page. No design exists for it; it is
/// built from the app's own parts.
class VersionGated extends StatelessWidget {
  final VersionGate gate;
  final UrlOpener opener;
  final String downloadUrl;
  final Widget child;

  const VersionGated({
    super.key,
    required this.gate,
    required this.opener,
    required this.downloadUrl,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: gate,
    builder: (context, _) =>
        gate.updateRequired ? _UpdateRequired(opener: opener, downloadUrl: downloadUrl) : child,
  );
}

class _UpdateRequired extends StatelessWidget {
  final UrlOpener opener;
  final String downloadUrl;

  const _UpdateRequired({required this.opener, required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final uri = Uri.parse(downloadUrl);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            const SizedBox(height: HabitSpace.s32),
            const Align(
              alignment: Alignment.centerLeft,
              child: IconTile(icon: AppIcons.update),
            ),
            const SizedBox(height: HabitSpace.s24),
            Semantics(header: true, child: Text(l10n.updateTitle, style: text.headlineMedium)),
            const SizedBox(height: HabitSpace.s12),
            Text(l10n.updateBody, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            const SizedBox(height: HabitSpace.s32),
            PrimaryButton(label: l10n.updateButton, onPressed: () => opener.open(uri)),
            const SizedBox(height: HabitSpace.s16),
            SelectableText(
              '${uri.host}${uri.path}',
              style: text.bodySmall?.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}
