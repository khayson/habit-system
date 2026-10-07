import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../core/validation.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/session_provider.dart';
import '../widgets/error_text.dart';
import '../widgets/habit_ui.dart';
import 'widgets/password_field.dart';

/// Screen 02. Valid credentials go to 04 on a first setup on this device, otherwise to Today
/// (05 or its empty state 23). Errors stay here and keep the email (design flow 01).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionProvider>().signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on Object catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _fieldErrors = e is AppException ? e.fields : const {};
        _error = _fieldErrors.isEmpty ? formErrorText(l10n, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(HabitSpace.margin),
              children: [
                ScreenHeader(title: l10n.signInTitle, subtitle: l10n.signInSubtitle),
                FieldLabel(l10n.fieldEmail),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l10n.fieldEmail,
                    errorText: _fieldErrors['email']?.first,
                  ),
                  validator: (v) => Validation.isEmail(v ?? '') ? null : l10n.errorEmailInvalid,
                ),
                const SizedBox(height: HabitSpace.s24),
                FieldLabel(l10n.fieldPassword),
                PasswordField(
                  controller: _password,
                  autofillHints: const [AutofillHints.password],
                  errorText: _fieldErrors['password']?.first,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v ?? '').isEmpty ? l10n.errorRequired : null,
                ),
                const SizedBox(height: HabitSpace.s32),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: HabitSpace.s16),
                ],
                PrimaryButton(label: l10n.signInButton, loading: _busy, onPressed: _submit),
                const SizedBox(height: HabitSpace.s32),
                InfoCard(title: l10n.signInPrivateTitle, body: l10n.signInPrivateBody),
                const SizedBox(height: HabitSpace.s32),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(Routes.createAccount),
                    child: Text(l10n.signInCreateAccount, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
