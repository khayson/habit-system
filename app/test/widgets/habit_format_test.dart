import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/widgets/habit_format.dart';

/// Phase 4.2b (L3): every category the server accepts reads as itself.
void main() {
  testWidgets('L3: a label for each of the five categories', (tester) async {
    late HabitFormat format;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            format = HabitFormat(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      [
        for (final c in ['health', 'mindfulness', 'learning', 'productivity', 'other'])
          format.category(c, long: true),
      ],
      ['Health', 'Mindfulness', 'Learning', 'Productivity', 'Other'],
    );
    expect(format.category('mindfulness'), 'Mindful', reason: "the design's short chip label");
  });
}
