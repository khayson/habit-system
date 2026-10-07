import 'package:flutter/material.dart';

import '../../config/habit_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

/// Password input with a 44 px show/hide toggle. The value is never logged.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final Iterable<String> autofillHints;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.autofillHints,
    this.helperText,
    this.errorText,
    this.validator,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: l10n.fieldPassword,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _visible ? l10n.hidePassword : l10n.showPassword,
          constraints: const BoxConstraints(
            minWidth: HabitSize.minTarget,
            minHeight: HabitSize.minTarget,
          ),
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
