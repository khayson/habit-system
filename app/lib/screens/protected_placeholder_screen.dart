import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';

/// Stand-in for Today (05), which Phase 2 builds. Exists only so the auth redirect has a
/// protected destination.
class ProtectedPlaceholderScreen extends StatelessWidget {
  const ProtectedPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HabitSpace.margin),
          child: Text(
            AppLocalizations.of(context).protectedPlaceholder,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
