import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// A50: password reset by a 6-digit code (screens 25, 26 and 27). The design was drawn for an
// email link; wherever it says "link" the app says "code" (each place is marked
// ASSUMPTION(A50-code)). The server answers every email the same way, so nothing here tells
// whether an account exists.

/// Screen 25, "A fresh start": asks for a code.
class ForgotPasswordScreen extends StatefulWidget {
  final String email;

  const ForgotPasswordScreen({super.key, this.email = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final email = _email.text.trim();
    try {
      await context.read<SessionProvider>().requestPasswordReset(email);
      if (mounted) context.push(Routes.resetSent, extra: email);
    } on Object catch (e) {
      if (mounted) setState(() => _error = formErrorText(AppLocalizations.of(context), e));
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
          child: ListView(
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              // ASSUMPTION(A50-code): the design's subtitle asks for a reset link.
              ScreenHeader(
                title: l10n.forgotTitle,
                subtitle: l10n.forgotSubtitle,
                onBack: () => context.go(Routes.signIn),
              ),
              FieldLabel(l10n.fieldEmail),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(hintText: l10n.fieldEmail),
                validator: (v) =>
                    Validation.isEmail((v ?? '').trim()) ? null : l10n.errorEmailInvalid,
              ),
              const SizedBox(height: HabitSpace.s32),
              InfoCard(
                title: l10n.forgotPrivateTitle,
                body: l10n.forgotPrivateBody,
                tone: Tone.info,
                icon: Icons.schedule,
                tintTitle: true,
              ),
              const SizedBox(height: HabitSpace.s48),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: HabitSpace.s16)],
              // ASSUMPTION(A50-code): the design's button sends a reset link.
              PrimaryButton(label: l10n.forgotSend, loading: _busy, onPressed: _send),
              const SizedBox(height: HabitSpace.s16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.go(Routes.signIn),
                  child: Text(l10n.forgotBackToSignIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 26, "Check your inbox": on to 27, or another code once the 60-second cooldown ends.
class ResetSentScreen extends StatefulWidget {
  final String email;

  /// A50: the server issues no new code within 60 seconds of the last.
  static const cooldown = Duration(seconds: 60);

  const ResetSentScreen({super.key, required this.email});

  @override
  State<ResetSentScreen> createState() => _ResetSentScreenState();
}

class _ResetSentScreenState extends State<ResetSentScreen> {
  Timer? _timer;
  int _left = ResetSentScreen.cooldown.inSeconds;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _left = ResetSentScreen.cooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await context.read<SessionProvider>().requestPasswordReset(widget.email);
      if (!mounted) return;
      setState(() => _note = l10n.resetSentResent);
      _start();
    } on Object catch (e) {
      if (mounted) setState(() => _note = formErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final waiting = _left > 0;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ScreenHeader(
              title: l10n.resetSentTitle,
              subtitle: l10n.resetSentSubtitle,
              onBack: () => context.canPop() ? context.pop() : context.go(Routes.signIn),
            ),
            const SizedBox(height: HabitSpace.s32),
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(color: tokens.positiveBg, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 56, color: tokens.primary),
                ),
              ),
            ),
            const SizedBox(height: HabitSpace.s32),
            // ASSUMPTION(A50-code): the design says to follow the link in the email.
            Text(l10n.resetSentBody, style: text.titleMedium),
            const SizedBox(height: HabitSpace.s24),
            // ASSUMPTION(A50-code): the design's card says "another link".
            InfoCard(
              title: l10n.resetSentNothingTitle,
              body: l10n.resetSentNothingBody,
              tone: Tone.info,
              icon: Icons.schedule,
              tintTitle: true,
            ),
            const SizedBox(height: HabitSpace.s48),
            if (_note != null) ...[
              Semantics(liveRegion: true, child: Text(_note!, style: text.bodyMedium)),
              const SizedBox(height: HabitSpace.s16),
            ],
            // ASSUMPTION(A50-code): the design's primary action is "Back to sign in"; with a code
            // the next step is entering it. The back arrow still returns.
            PrimaryButton(
              label: l10n.resetSentEnterCode,
              onPressed: () => context.push(Routes.resetPassword, extra: widget.email),
            ),
            const SizedBox(height: HabitSpace.s16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                label: waiting ? l10n.resetSentResendInLabel(_left) : null,
                excludeSemantics: waiting,
                child: TextButton(
                  onPressed: waiting || _busy ? null : _resend,
                  child: Text(waiting ? l10n.resetSentResendIn(_left) : l10n.resetSentResend),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 27, "Choose a new password": the code first, then the new password twice.
class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fields = const {};

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _codeRefused => _fields.containsKey('reset_token');

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fields = const {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionProvider>().resetPassword(
        email: widget.email,
        code: _code.text,
        password: _password.text,
        confirmation: _confirm.text,
      );
      if (mounted) context.go(Routes.signIn);
    } on Object catch (e) {
      if (!mounted) return;
      final fields = e is AppException ? e.fields : const <String, List<String>>{};
      setState(() {
        _fields = fields;
        _error = fields.isEmpty ? formErrorText(AppLocalizations.of(context), e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(HabitSpace.margin),
              children: [
                // ASSUMPTION(A50-code): the design's subtitle is about a reset link.
                ScreenHeader(
                  title: l10n.resetTitle,
                  subtitle: l10n.resetSubtitle,
                  onBack: () => context.canPop() ? context.pop() : context.go(Routes.signIn),
                ),
                // A50: the code field comes first; the design has no code (it was a link).
                FieldLabel(l10n.resetCodeLabel),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.resetCodeHint,
                    errorText: _fields['reset_token']?.first,
                  ),
                  validator: (v) =>
                      RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : l10n.resetCodeInvalid,
                ),
                if (_codeRefused)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => context.go(Routes.forgotPassword, extra: widget.email),
                      child: Text(l10n.resetRequestNewCode),
                    ),
                  ),
                const SizedBox(height: HabitSpace.s24),
                FieldLabel(l10n.resetNewPassword),
                PasswordField(
                  controller: _password,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _fields['password']?.first,
                  validator: (v) => Validation.isPassword(v ?? '') ? null : l10n.errorPasswordShort,
                ),
                const SizedBox(height: HabitSpace.s24),
                FieldLabel(l10n.resetConfirmPassword),
                PasswordField(
                  controller: _confirm,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v == _password.text ? null : l10n.resetMismatch,
                ),
                const SizedBox(height: HabitSpace.s32),
                // ASSUMPTION(A50-code): the design's card says "Expired links".
                InfoCard(
                  title: l10n.resetRulesTitle,
                  body: l10n.resetRulesBody,
                  tone: Tone.info,
                  icon: Icons.schedule,
                  tintTitle: true,
                ),
                const SizedBox(height: HabitSpace.s48),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: HabitSpace.s16),
                ],
                PrimaryButton(label: l10n.resetSave, loading: _busy, onPressed: _save),
                const SizedBox(height: HabitSpace.s16),
                Text(l10n.resetFooter, style: text.bodySmall?.copyWith(color: tokens.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
