import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/habit_tokens.dart';
import '../config/legal_config.dart';
import '../core/url_opener.dart';
import '../l10n/generated/app_localizations.dart';

/// A33: the Terms and Privacy Policy links under screen 03's consent line. Each opens the hosted
/// page in the browser; if nothing can open it, a sheet shows the link to copy.
// ASSUMPTION(A33-links): the design file draws the consent line without links or a failure
// state; the links and the copy-link sheet use the app's existing text button and sheet styles.
class LegalLinks extends StatelessWidget {
  final UrlOpener opener;

  const LegalLinks({super.key, required this.opener});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await opener.open(Uri.parse(url));
    if (!opened && context.mounted) await showLinkFallback(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: HabitSpace.s8,
      children: [
        _link(
          l10n.legalTerms,
          l10n.legalOpensInBrowser,
          () => _open(context, LegalConfig.termsUrl),
        ),
        _link(
          l10n.legalPrivacy,
          l10n.legalOpensInBrowser,
          () => _open(context, LegalConfig.privacyUrl),
        ),
      ],
    );
  }

  // The hint sits inside the button so it merges into the button's own semantics node.
  Widget _link(String label, String hint, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    child: Semantics(hint: hint, child: Text(label)),
  );
}

/// The page did not open: the link as selectable text, and a button that copies it.
Future<void> showLinkFallback(BuildContext context, String url) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      final tokens = HabitTokens.of(sheet);
      var copied = false;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HabitSpace.margin,
            0,
            HabitSpace.margin,
            HabitSpace.margin,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.legalOpenFailedTitle, style: text.titleLarge),
                const SizedBox(height: HabitSpace.s8),
                Text(
                  l10n.legalOpenFailedBody,
                  style: text.bodyLarge?.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: HabitSpace.s16),
                SelectableText(url, style: text.bodyLarge),
                const SizedBox(height: HabitSpace.s24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    setState(() => copied = true);
                  },
                  icon: Icon(copied ? Icons.check : Icons.copy),
                  label: Text(copied ? l10n.legalLinkCopied : l10n.legalCopyLink),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
