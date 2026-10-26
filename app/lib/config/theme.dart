import 'package:flutter/material.dart';

import 'habit_tokens.dart';

/// Material theme built from [HabitTokens]. No seed colours: every value comes from the
/// design tokens. Text sizes are logical and scale with the system text size.
abstract final class AppTheme {
  static ThemeData get light => _build(HabitTokens.light, Brightness.light);
  static ThemeData get dark => _build(HabitTokens.dark, Brightness.dark);

  /// Type ramp (size / line height) from HABIT DESIGN SYSTEM / 3.
  /// Bundled Urbanist (variable), the redesign's rounded geometric sans (A56). Glyphs it lacks
  /// fall back to the platform font.
  static const String fontFamily = 'Urbanist';

  static TextTheme textTheme(Color ink) {
    // A variable font needs the weight on its `wght` axis as well as in fontWeight.
    TextStyle s(double size, double lineHeight, FontWeight weight) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: ink,
    );
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
    // A56: pill buttons, and soft-cornered white fields and cards with no outline.
    const controlShape = StadiumBorder();
    final fieldRadius = BorderRadius.circular(HabitRadius.r16);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HabitRadius.r20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.control)),
          shape: const WidgetStatePropertyAll(controlShape),
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
          shape: const WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStatePropertyAll(t.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? t.disabledInk : t.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused) ? t.focus : t.border,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      // A56: text actions are the brown accent (the orange is never text, 2.7:1 on white).
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.minTarget)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? t.disabledInk : t.accent,
          ),
        ),
      ),
      // A56: the orange switch of the mockups ("Get reminders").
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.surface : t.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : t.border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : t.muted,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HabitRadius.r4)),
        side: BorderSide(color: t.muted, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.selected : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(t.onSelected),
      ),
      // A56: white options; the selected one is the dark "selected" pill, as the chosen day.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(HabitSize.minTarget, HabitSize.control)),
          textStyle: WidgetStatePropertyAll(text.titleSmall),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? t.selected : t.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? t.onSelected : t.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused) ? t.focus : t.border,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
          shape: const WidgetStatePropertyAll(controlShape),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        constraints: const BoxConstraints(minHeight: HabitSize.control),
        contentPadding: const EdgeInsets.symmetric(horizontal: HabitSpace.s16, vertical: 14),
        border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: t.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: t.errorInk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: t.errorInk, width: 2),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: t.muted),
        labelStyle: text.bodyMedium?.copyWith(color: t.muted),
        errorStyle: text.bodySmall?.copyWith(color: t.errorInk),
        errorMaxLines: 4,
      ),
    );
  }
}
