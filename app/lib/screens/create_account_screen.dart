import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

/// Reads the device's IANA zone for registration. Replaceable in tests.
typedef DeviceTimezone = Future<String> Function();

Future<String> deviceTimezone() async => (await FlutterTimezone.getLocalTimezone()).identifier;

/// Screen 03. A valid form registers (201) and goes to 04; an invalid one stays here with field
/// errors and every entered value kept (design flow 01).
class CreateAccountScreen extends StatefulWidget {
  final DeviceTimezone timezone;

  const CreateAccountScreen({super.key, this.timezone = deviceTimezone});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _showTermsError = false;
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
      _showTermsError = !_agreed;
    });
    final valid = _form.currentState!.validate();
    if (!valid || !_agreed) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionProvider>().register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        timezone: await widget.timezone(),
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
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(HabitSpace.margin),
              children: [
                ScreenHeader(
                  title: l10n.createAccountTitle,
                  subtitle: l10n.createAccountSubtitle,
                  onBack: () => context.go(Routes.signIn),
                ),
                FieldLabel(l10n.fieldName),
                TextFormField(
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.fieldName,
                    errorText: _fieldErrors['name']?.first,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return l10n.errorNameRequired;
                    if (value.length > Validation.nameMaxLength) return l10n.errorNameTooLong;
                    return null;
                  },
                ),
                const SizedBox(height: HabitSpace.s24),
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
                  autofillHints: const [AutofillHints.newPassword],
                  helperText: l10n.createAccountPasswordHelper,
                  errorText: _fieldErrors['password']?.first,
                  validator: (v) => Validation.isPassword(v ?? '') ? null : l10n.errorPasswordShort,
                ),
                const SizedBox(height: HabitSpace.s16),
                // ASSUMPTION(A2b2-terms): the Terms and Privacy Policy are hosted in Phase 7; until
                // their URLs are configured the line is plain text, never a fabricated link.
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (v) => setState(() {
                    _agreed = v ?? false;
                    if (_agreed) _showTermsError = false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.createAccountTerms, style: text.bodyMedium),
                  subtitle: _showTermsError
                      ? Text(
                          l10n.createAccountTermsNeeded,
                          style: text.bodySmall?.copyWith(color: tokens.errorInk),
                        )
                      : null,
                ),
                const SizedBox(height: HabitSpace.s16),
                InfoCard(
                  title: l10n.createAccountNoPressureTitle,
                  body: l10n.createAccountNoPressureBody,
                ),
                const SizedBox(height: HabitSpace.s32),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: HabitSpace.s16),
                ],
                PrimaryButton(label: l10n.createAccountButton, loading: _busy, onPressed: _submit),
                const SizedBox(height: HabitSpace.s16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(Routes.signIn),
                    child: Text(l10n.createAccountSignIn, textAlign: TextAlign.center),
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
