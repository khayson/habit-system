import 'package:flutter/material.dart';

import 'habit_tokens.dart';

/// Material theme built from [HabitTokens]. No seed colours: every value comes from the
/// design tokens. Text sizes are logical and scale with the system text size.
abstract final class AppTheme {
  static ThemeData get light => _build(HabitTokens.light, Brightness.light);
  static ThemeData get dark => _build(HabitTokens.dark, Brightness.dark);

  /// Type ramp (size / line height) from HABIT DESIGN SYSTEM / 3.
  static TextTheme textTheme(Color ink) {
    TextStyle s(double size, double lineHeight, FontWeight weight) =>
        TextStyle(fontSize: size, height: lineHeight / size, fontWeight: weight, color: ink);
    return TextTheme(
      displayLarge: s(36, 50, FontWeight.w600), // Display
      headlineMedium: s(28, 40, FontWeight.w600), // Title
      titleLarge: s(20, 28, FontWeight.w600), // Section
      bodyLarge: s(16, 24, FontWeight.w400), // Body
      bodyMedium: s(16, 24, FontWeight.w400),
      bodySmall: s(13, 19, FontWeight.w400), // BodySmall
      titleSmall: s(14, 20, FontWeight.w500), // CardTitle
      labelLarge: s(16, 24, FontWeight.w600), // Button label
      labelSmall: s(11, 16, FontWeight.w400), // Caption / NavLabel
    );
  }

  static ThemeData _build(HabitTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.positiveBg,
      onPrimaryContainer: t.positiveInk,
      secondary: t.infoInk,
      onSecondary: t.surface,
      secondaryContainer: t.infoBg,
      onSecondaryContainer: t.infoInk,
      tertiary: t.warningInk,
      onTertiary: t.surface,
      tertiaryContainer: t.warningBg,
      onTertiaryContainer: t.warningInk,
      error: t.errorInk,
      onError: t.surface,
      errorContainer: t.errorBg,
      onErrorContainer: t.errorInk,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.muted,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.background,
      surfaceContainer: t.background,
      surfaceContainerHigh: t.canvas,
      surfaceContainerHighest: t.canvas,
      outline: t.border,
      outlineVariant: t.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      inversePrimary: t.pressed,
    );
    final text = textTheme(t.ink);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HabitRadius.r12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.canvas,
      dividerColor: t.border,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [t],
      focusColor: t.focus.withValues(alpha: 0.24),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.ink,
        elevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r16),
          side: BorderSide(color: t.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.control)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.disabledBg;
            if (states.contains(WidgetState.pressed)) return t.pressed;
            return t.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? t.disabledInk : t.onPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.focused) ? BorderSide(color: t.focus, width: 2) : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.control)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? t.disabledInk : t.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused) ? t.focus : t.border,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.minTarget)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? t.disabledInk : t.primary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        constraints: const BoxConstraints(minHeight: HabitSize.control),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          borderSide: BorderSide(color: t.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r12),
          borderSide: BorderSide(color: t.errorInk),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: t.muted),
        errorStyle: text.bodySmall?.copyWith(color: t.errorInk),
        errorMaxLines: 4,
      ),
    );
  }
}
