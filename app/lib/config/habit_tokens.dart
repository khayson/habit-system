import 'package:flutter/material.dart';

/// The colour roles of the 2026-10-26 redesign (A56): the mockups' palette in light, a warm
/// derivation in dark (the mockups have none). Text pairs meet 4.5:1 (theme_test).
@immutable
class HabitTokens extends ThemeExtension<HabitTokens> {
  final Color canvas;

  /// The warm cream every screen sits on.
  final Color background;

  /// Cards, fields and the round chips.
  final Color surface;
  final Color ink;

  /// The mockups' captions are lighter (#A5A5A5, 2.5:1); darkened to 4.5:1 or more on every light surface (A56).
  final Color muted;
  final Color border;

  /// The orange of buttons, switches and done checks.
  final Color primary;
  final Color pressed;

  /// Near-black, not white: white on the orange is 2.7:1 (A56, Khay Studios).
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

  /// Never the only indicator: a number or text always accompanies it (A13d).
  final Color progress;
  final Color focus;

  /// The chosen day or option: a dark circle (A56).
  final Color selected;
  final Color onSelected;

  /// Dark brown: small buttons, the + button and text actions (A56); light brown in dark.
  final Color accent;
  final Color onAccent;

  /// Pastel tiles behind habit icons; each with its icon colour.
  final Color tilePeach;
  final Color tilePeachInk;
  final Color tileLime;
  final Color tileLimeInk;
  final Color tilePink;
  final Color tilePinkInk;

  /// Insights bars (A56), on a hatched [chartTrack].
  final Color chartBrown;
  final Color chartRust;
  final Color chartLime;
  final Color chartPink;
  final Color chartTrack;

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
    required this.selected,
    required this.onSelected,
    required this.accent,
    required this.onAccent,
    required this.tilePeach,
    required this.tilePeachInk,
    required this.tileLime,
    required this.tileLimeInk,
    required this.tilePink,
    required this.tilePinkInk,
    required this.chartBrown,
    required this.chartRust,
    required this.chartLime,
    required this.chartPink,
    required this.chartTrack,
  });

  static const light = HabitTokens(
    canvas: Color(0xFFEFE8E3),
    background: Color(0xFFF7F2EF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1E1F22),
    muted: Color(0xFF646464),
    border: Color(0xFFECE4DE),
    primary: Color(0xFFFF7616),
    pressed: Color(0xFFE8650F),
    onPrimary: Color(0xFF1E1F22),
    positiveBg: Color(0xFFFFD5BC),
    positiveInk: Color(0xFF682E08),
    infoBg: Color(0xFFE5EFBA),
    infoInk: Color(0xFF475610),
    warningBg: Color(0xFFFFE8C2),
    warningInk: Color(0xFF87470A),
    errorBg: Color(0xFFFCE1DE),
    errorInk: Color(0xFFA3271B),
    disabledBg: Color(0xFFECE6E1),
    disabledInk: Color(0xFF6F6862),
    progress: Color(0xFFFF7616),
    focus: Color(0xFF292C31),
    selected: Color(0xFF292C31),
    onSelected: Color(0xFFFFFFFF),
    accent: Color(0xFF682E08),
    onAccent: Color(0xFFFFFFFF),
    tilePeach: Color(0xFFFFD5BC),
    tilePeachInk: Color(0xFFB14E0C),
    tileLime: Color(0xFFE5EFBA),
    tileLimeInk: Color(0xFF5A7016),
    tilePink: Color(0xFFFFDEF8),
    tilePinkInk: Color(0xFFA33A8B),
    chartBrown: Color(0xFF523632),
    chartRust: Color(0xFF99470F),
    chartLime: Color(0xFF8AA232),
    chartPink: Color(0xFFE586CA),
    chartTrack: Color(0xFFE4DDD5),
  );

  static const dark = HabitTokens(
    canvas: Color(0xFF120D0A),
    background: Color(0xFF1A1411),
    surface: Color(0xFF262019),
    ink: Color(0xFFF7F2EF),
    muted: Color(0xFFC2B8B0),
    border: Color(0xFF3E342D),
    primary: Color(0xFFFF8A3D),
    pressed: Color(0xFFFFA366),
    onPrimary: Color(0xFF1E1F22),
    positiveBg: Color(0xFF4A2A16),
    positiveInk: Color(0xFFFFD5BC),
    infoBg: Color(0xFF34401A),
    infoInk: Color(0xFFE5EFBA),
    warningBg: Color(0xFF4A3416),
    warningInk: Color(0xFFFFD9A0),
    errorBg: Color(0xFF4D2320),
    errorInk: Color(0xFFFFB4AA),
    disabledBg: Color(0xFF332B25),
    disabledInk: Color(0xFF9A9088),
    progress: Color(0xFFFF8A3D),
    focus: Color(0xFFF7F2EF),
    selected: Color(0xFFF7F2EF),
    onSelected: Color(0xFF1E1F22),
    accent: Color(0xFFE8A070),
    onAccent: Color(0xFF1E1F22),
    tilePeach: Color(0xFF4A2E1E),
    tilePeachInk: Color(0xFFFFB98A),
    tileLime: Color(0xFF343F1C),
    tileLimeInk: Color(0xFFC9DB7E),
    tilePink: Color(0xFF47253F),
    tilePinkInk: Color(0xFFF2A8DD),
    chartBrown: Color(0xFFA88780),
    chartRust: Color(0xFFD27A3A),
    chartLime: Color(0xFFA8C24A),
    chartPink: Color(0xFFE586CA),
    chartTrack: Color(0xFF3A302A),
  );

  /// All roles by name, in this order.
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
    'selected': selected,
    'onSelected': onSelected,
    'accent': accent,
    'onAccent': onAccent,
    'tilePeach': tilePeach,
    'tilePeachInk': tilePeachInk,
    'tileLime': tileLime,
    'tileLimeInk': tileLimeInk,
    'tilePink': tilePink,
    'tilePinkInk': tilePinkInk,
    'chartBrown': chartBrown,
    'chartRust': chartRust,
    'chartLime': chartLime,
    'chartPink': chartPink,
    'chartTrack': chartTrack,
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
    Color? selected,
    Color? onSelected,
    Color? accent,
    Color? onAccent,
    Color? tilePeach,
    Color? tilePeachInk,
    Color? tileLime,
    Color? tileLimeInk,
    Color? tilePink,
    Color? tilePinkInk,
    Color? chartBrown,
    Color? chartRust,
    Color? chartLime,
    Color? chartPink,
    Color? chartTrack,
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
      selected: selected ?? this.selected,
      onSelected: onSelected ?? this.onSelected,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      tilePeach: tilePeach ?? this.tilePeach,
      tilePeachInk: tilePeachInk ?? this.tilePeachInk,
      tileLime: tileLime ?? this.tileLime,
      tileLimeInk: tileLimeInk ?? this.tileLimeInk,
      tilePink: tilePink ?? this.tilePink,
      tilePinkInk: tilePinkInk ?? this.tilePinkInk,
      chartBrown: chartBrown ?? this.chartBrown,
      chartRust: chartRust ?? this.chartRust,
      chartLime: chartLime ?? this.chartLime,
      chartPink: chartPink ?? this.chartPink,
      chartTrack: chartTrack ?? this.chartTrack,
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
      selected: l(selected, other.selected),
      onSelected: l(onSelected, other.onSelected),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      tilePeach: l(tilePeach, other.tilePeach),
      tilePeachInk: l(tilePeachInk, other.tilePeachInk),
      tileLime: l(tileLime, other.tileLime),
      tileLimeInk: l(tileLimeInk, other.tileLimeInk),
      tilePink: l(tilePink, other.tilePink),
      tilePinkInk: l(tilePinkInk, other.tilePinkInk),
      chartBrown: l(chartBrown, other.chartBrown),
      chartRust: l(chartRust, other.chartRust),
      chartLime: l(chartLime, other.chartLime),
      chartPink: l(chartPink, other.chartPink),
      chartTrack: l(chartTrack, other.chartTrack),
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

  /// A56: cards and the round-cornered tiles of the redesign.
  static const double r20 = 20;
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
