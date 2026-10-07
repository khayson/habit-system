import 'package:flutter/material.dart';

/// The 21 semantic colour roles from the design file (HABIT DESIGN SYSTEM / 2).
/// Dark values are mapped to the light roles by order (A13e).
@immutable
class HabitTokens extends ThemeExtension<HabitTokens> {
  final Color canvas;
  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color primary;
  final Color pressed;
  final Color onPrimary;
  final Color positiveBg;
  final Color positiveInk;
  final Color infoBg;
  final Color infoInk;
  final Color warningBg;
  final Color warningInk;
  final Color errorBg;
  final Color errorInk;
  final Color disabledBg;
  final Color disabledInk;

  /// Never the only indicator: values are always also printed as text (A13d).
  final Color progress;
  final Color focus;

  const HabitTokens({
    required this.canvas,
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.pressed,
    required this.onPrimary,
    required this.positiveBg,
    required this.positiveInk,
    required this.infoBg,
    required this.infoInk,
    required this.warningBg,
    required this.warningInk,
    required this.errorBg,
    required this.errorInk,
    required this.disabledBg,
    required this.disabledInk,
    required this.progress,
    required this.focus,
  });

  static const light = HabitTokens(
    canvas: Color(0xFFF0F4EF),
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF323B35),
    muted: Color(0xFF647269),
    border: Color(0xFFE6EBE7),
    primary: Color(0xFF2F7B45),
    pressed: Color(0xFF246538),
    onPrimary: Color(0xFFFFFFFF),
    positiveBg: Color(0xFFE7F4E7),
    positiveInk: Color(0xFF2F7B45),
    infoBg: Color(0xFFE1F2F6),
    // A13d: design value #318297 is 3.8:1 on infoBg, below the file's 4.5:1 body-text rule.
    infoInk: Color(0xFF256E82),
    warningBg: Color(0xFFFFF3D8),
    warningInk: Color(0xFFA85816),
    errorBg: Color(0xFFFFF0EC),
    errorInk: Color(0xFFA44234),
    disabledBg: Color(0xFFE6EBE7),
    disabledInk: Color(0xFF7C8980),
    progress: Color(0xFF5CAC60),
    focus: Color(0xFF236899),
  );

  static const dark = HabitTokens(
    canvas: Color(0xFF101A14),
    background: Color(0xFF142018),
    surface: Color(0xFF1D2D22),
    ink: Color(0xFFEEF6EE),
    muted: Color(0xFFB8C8BC),
    border: Color(0xFF53685A),
    primary: Color(0xFF8BD799),
    pressed: Color(0xFFADE7B6),
    onPrimary: Color(0xFF13251A),
    positiveBg: Color(0xFF25472F),
    positiveInk: Color(0xFF9FE0AE),
    infoBg: Color(0xFF203F48),
    infoInk: Color(0xFF99D9E8),
    warningBg: Color(0xFF493C22),
    warningInk: Color(0xFFECCC93),
    errorBg: Color(0xFF492F2B),
    errorInk: Color(0xFFF2B9AB),
    disabledBg: Color(0xFF34463A),
    disabledInk: Color(0xFF8B9D91),
    progress: Color(0xFF8BD799),
    focus: Color(0xFFA1D7F3),
  );

  /// All roles by design-file name, in design-file order.
  Map<String, Color> get roles => {
    'canvas': canvas,
    'background': background,
    'surface': surface,
    'ink': ink,
    'muted': muted,
    'border': border,
    'primary': primary,
    'pressed': pressed,
    'onPrimary': onPrimary,
    'positiveBg': positiveBg,
    'positiveInk': positiveInk,
    'infoBg': infoBg,
    'infoInk': infoInk,
    'warningBg': warningBg,
    'warningInk': warningInk,
    'errorBg': errorBg,
    'errorInk': errorInk,
    'disabledBg': disabledBg,
    'disabledInk': disabledInk,
    'progress': progress,
    'focus': focus,
  };

  static HabitTokens of(BuildContext context) => Theme.of(context).extension<HabitTokens>()!;

  @override
  HabitTokens copyWith({
    Color? canvas,
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? border,
    Color? primary,
    Color? pressed,
    Color? onPrimary,
    Color? positiveBg,
    Color? positiveInk,
    Color? infoBg,
    Color? infoInk,
    Color? warningBg,
    Color? warningInk,
    Color? errorBg,
    Color? errorInk,
    Color? disabledBg,
    Color? disabledInk,
    Color? progress,
    Color? focus,
  }) {
    return HabitTokens(
      canvas: canvas ?? this.canvas,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      pressed: pressed ?? this.pressed,
      onPrimary: onPrimary ?? this.onPrimary,
      positiveBg: positiveBg ?? this.positiveBg,
      positiveInk: positiveInk ?? this.positiveInk,
      infoBg: infoBg ?? this.infoBg,
      infoInk: infoInk ?? this.infoInk,
      warningBg: warningBg ?? this.warningBg,
      warningInk: warningInk ?? this.warningInk,
      errorBg: errorBg ?? this.errorBg,
      errorInk: errorInk ?? this.errorInk,
      disabledBg: disabledBg ?? this.disabledBg,
      disabledInk: disabledInk ?? this.disabledInk,
      progress: progress ?? this.progress,
      focus: focus ?? this.focus,
    );
  }

  @override
  HabitTokens lerp(HabitTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HabitTokens(
      canvas: l(canvas, other.canvas),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      pressed: l(pressed, other.pressed),
      onPrimary: l(onPrimary, other.onPrimary),
      positiveBg: l(positiveBg, other.positiveBg),
      positiveInk: l(positiveInk, other.positiveInk),
      infoBg: l(infoBg, other.infoBg),
      infoInk: l(infoInk, other.infoInk),
      warningBg: l(warningBg, other.warningBg),
      warningInk: l(warningInk, other.warningInk),
      errorBg: l(errorBg, other.errorBg),
      errorInk: l(errorInk, other.errorInk),
      disabledBg: l(disabledBg, other.disabledBg),
      disabledInk: l(disabledInk, other.disabledInk),
      progress: l(progress, other.progress),
      focus: l(focus, other.focus),
    );
  }
}

/// Space scale (space/4 … space/64) and layout grid: 24 margin, 16 gutter, 4 columns.
abstract final class HabitSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;

  static const double margin = 24;
  static const double gutter = 16;
  static const int columns = 4;
}

/// Radius scale (radius/4 … radius/24).
abstract final class HabitRadius {
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r24 = 24;
}

/// Control heights: 44 minimum hit area, 52 default control, 64 large control.
abstract final class HabitSize {
  static const double minTarget = 44;
  static const double control = 52;
  static const double controlLarge = 64;
  static const double icon = 24;
}

/// Elevation styles: Raised 2/8, Overlay 8/24 (y-offset / blur).
abstract final class HabitElevation {
  static List<BoxShadow> raised(Color shadow) => [
    BoxShadow(color: shadow, offset: const Offset(0, 2), blurRadius: 8),
  ];
  static List<BoxShadow> overlay(Color shadow) => [
    BoxShadow(color: shadow, offset: const Offset(0, 8), blurRadius: 24),
  ];
}
