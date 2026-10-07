import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/habit_tokens.dart';
import 'package:habit/config/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const roleOrder = [
    'canvas', 'background', 'surface', 'ink', 'muted', 'border', 'primary', 'pressed', //
    'onPrimary', 'positiveBg', 'positiveInk', 'infoBg', 'infoInk', 'warningBg', 'warningInk',
    'errorBg', 'errorInk', 'disabledBg', 'disabledInk', 'progress', 'focus',
  ];

  test('both themes define the 21 design roles in design-file order (A13e)', () {
    expect(HabitTokens.light.roles.keys.toList(), roleOrder);
    expect(HabitTokens.dark.roles.keys.toList(), roleOrder);
  });

  test('spot-checks design values', () {
    expect(HabitTokens.light.primary, const Color(0xFF2F7B45));
    expect(HabitTokens.light.canvas, const Color(0xFFF0F4EF));
    expect(HabitTokens.dark.canvas, const Color(0xFF101A14));
    expect(HabitTokens.dark.focus, const Color(0xFFA1D7F3));
  });

  test('applies the A13d infoInk correction', () {
    expect(HabitTokens.light.infoInk, const Color(0xFF256E82));
  });

  // Body text 4.5:1 (design file, page 8). Disabled and progress are exempt: disabled is
  // unavailable by definition, progress is never the only indicator (A13d).
  const textPairs = [
    ('ink', 'background'),
    ('ink', 'surface'),
    ('ink', 'canvas'),
    ('muted', 'background'),
    ('muted', 'surface'),
    ('muted', 'canvas'),
    ('onPrimary', 'primary'),
    ('onPrimary', 'pressed'),
    ('primary', 'surface'),
    ('positiveInk', 'positiveBg'),
    ('infoInk', 'infoBg'),
    ('infoInk', 'surface'),
    ('warningInk', 'warningBg'),
    ('errorInk', 'errorBg'),
    ('errorInk', 'surface'),
  ];

  for (final (name, tokens) in [('light', HabitTokens.light), ('dark', HabitTokens.dark)]) {
    for (final (fg, bg) in textPairs) {
      test('$name: $fg on $bg meets 4.5:1', () {
        final ratio = contrast(tokens.roles[fg]!, tokens.roles[bg]!);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '${ratio.toStringAsFixed(2)}:1');
      });
    }
    test('$name: focus ring meets 3:1 non-text contrast on surface', () {
      expect(contrast(tokens.focus, tokens.surface), greaterThanOrEqualTo(3));
    });
  }

  test('themes carry HabitTokens and map the ColorScheme from them', () {
    for (final (theme, tokens) in [
      (AppTheme.light, HabitTokens.light),
      (AppTheme.dark, HabitTokens.dark),
    ]) {
      expect(theme.extension<HabitTokens>(), tokens);
      expect(theme.colorScheme.primary, tokens.primary);
      expect(theme.colorScheme.onSurface, tokens.ink);
      expect(theme.colorScheme.error, tokens.errorInk);
      expect(theme.scaffoldBackgroundColor, tokens.background);
    }
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('type ramp matches the design file (size / line height)', () {
    final t = AppTheme.textTheme(Colors.black);
    void check(TextStyle? s, double size, double line) {
      expect(s!.fontSize, size);
      expect(s.fontSize! * s.height!, closeTo(line, 0.001));
    }

    check(t.displayLarge, 36, 50);
    check(t.headlineMedium, 28, 40);
    check(t.titleLarge, 20, 28);
    check(t.bodyLarge, 16, 24);
    check(t.bodySmall, 13, 19);
    check(t.titleSmall, 14, 20);
    check(t.labelSmall, 11, 16);
  });

  test('scales: space, radius, control heights', () {
    expect(
      [
        HabitSpace.s4,
        HabitSpace.s8,
        HabitSpace.s12,
        HabitSpace.s16,
        HabitSpace.s24,
        HabitSpace.s32,
        HabitSpace.s48,
        HabitSpace.s64,
      ],
      [4, 8, 12, 16, 24, 32, 48, 64],
    );
    expect(
      [
        HabitRadius.r4,
        HabitRadius.r8,
        HabitRadius.r12,
        HabitRadius.r14,
        HabitRadius.r16,
        HabitRadius.r24,
      ],
      [4, 8, 12, 14, 16, 24],
    );
    expect([HabitSize.minTarget, HabitSize.control, HabitSize.controlLarge], [44, 52, 64]);
  });

  test('lerp interpolates between themes', () {
    final mid = HabitTokens.light.lerp(HabitTokens.dark, 0.5);
    expect(mid.ink, Color.lerp(HabitTokens.light.ink, HabitTokens.dark.ink, 0.5));
    expect(HabitTokens.light.lerp(null, 0.5), HabitTokens.light);
  });
}
