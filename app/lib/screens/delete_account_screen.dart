import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/account_context.dart';
import '../providers/session_provider.dart';
import '../sync/outbox_states.dart';
import '../widgets/habit_ui.dart';
import 'privacy_screen.dart';
import 'widgets/password_field.dart';

/// Screen 28, "Delete your account?" (A49). The password is the recent reauthentication; the
/// server decides. Nothing on the device changes until it answers 202, then the session ends and
/// the router opens sign in.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.privacy);

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _fieldError = null;
      _error = null;
    });
    try {
      await context.read<SessionProvider>().deleteAccount(_password.text);
    } on Object catch (e) {
      if (!mounted) return;
      final password = e is AppException ? e.fields['password']?.first : null;
      final offline =
          e is AppException && (e.kind == AppErrorKind.network || e.kind == AppErrorKind.timeout);
      setState(() {
        _fieldError = password;
        _error = password != null
            ? null
            : offline
            ? l10n.deleteAccountOffline
            : l10n.deleteAccountError;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final canDelete = _password.text.isNotEmpty && !_busy;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.deleteAccountTitle,
              subtitle: l10n.deleteAccountSubtitle,
              onBack: _back,
            ),
            const SizedBox(height: HabitSpace.s16),
            ListenableBuilder(
              listenable: account.queue,
              builder: (context, _) {
                final waiting = (account.queue.value?.items ?? const <QueueItem>[])
                    .where((i) => OutboxState.unacked.contains(i.row.state))
                    .length;
                return _ExportCard(
                  title: l10n.deleteAccountExportTitle,
                  body: waiting > 0
                      ? '${l10n.deleteAccountExportBody} ${l10n.deleteAccountPending(waiting)}'
                      : l10n.deleteAccountExportBody,
                );
              },
            ),
            const SizedBox(height: HabitSpace.s32),
            FieldLabel(l10n.deleteAccountPasswordLabel),
            // Only the destructive button deletes: no submit from the keyboard.
            PasswordField(controller: _password, autofillHints: const [], errorText: _fieldError),
            const SizedBox(height: HabitSpace.s32),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deleteAccountNextTitle, style: text.titleMedium),
                  const SizedBox(height: HabitSpace.s12),
                  Text(
                    l10n.deleteAccountNextBody,
                    style: text.bodyMedium?.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s48),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: HabitSpace.s12),
              Center(
                child: TextButton(
                  onPressed: canDelete ? _delete : null,
                  child: Text(l10n.deleteAccountTryAgain),
                ),
              ),
              const SizedBox(height: HabitSpace.s12),
            ],
            tonalButton(label: l10n.deleteAccountKeep, onPressed: _busy ? null : _back),
            const SizedBox(height: HabitSpace.s12),
            DestructiveButton(
              label: l10n.deleteAccountConfirm,
              loading: _busy,
              onPressed: canDelete ? _delete : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 28's amber card: the icon and title in the warning ink, the body muted.
class _ExportCard extends StatelessWidget {
  final String title;
  final String body;

  const _ExportCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HabitSpace.s16),
      decoration: BoxDecoration(
        color: tokens.warningBg,
        borderRadius: BorderRadius.circular(HabitRadius.r16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, color: tokens.warningInk),
          const SizedBox(width: HabitSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    color: tokens.warningInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: HabitSpace.s4),
                Text(body, style: text.bodySmall?.copyWith(color: tokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
