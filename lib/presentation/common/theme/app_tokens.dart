import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// FinTrack design tokens (2026 refresh).
///
/// Derived from a study of Linear, Mercury, Stripe, Copilot Money, Monzo and
/// Ramp. Three rules drive every value here:
///
///  1. ONE accent. The indigo is reserved for primary actions and interactive
///     state. Everything else is a neutral step. Two saturated accents is the
///     single clearest "dashboard template" tell.
///  2. Depth by luminance on dark, by hairline + one soft shadow on light.
///     Drop shadows on a dark canvas are a light-mode design wearing a costume.
///  3. Weight down, not up. Hero numerals are w300. Bold display type is the
///     2022 look; thin large type is what reads as premium now.
///
/// Colours are explicit rather than seed-derived: `ColorScheme.fromSeed`
/// harmonises everything toward the seed hue, which is exactly what makes
/// generated Material themes look muddy and generic.
/// ---------------------------------------------------------------------------

/// Spacing scale. Synthesised from Stripe (2/4/8/12/16/24/32/64) and
/// Linear (4/8/12/16/20/24/32).
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  /// Standard screen gutter.
  static const double gutter = 20;

  /// Gap between cells of a bento grid.
  static const double bento = 10;

  /// Vertical gap between major sections.
  static const double section = 28;
}

/// Corner radius scale.
///
/// Note the deliberate move away from full-pill primary buttons: the 2026
/// convention is a restrained 8px on actions, with pill reserved for chips,
/// tags and status badges.
abstract final class Radii {
  static const double xs = 4; // badges, micro tags
  static const double sm = 8; // buttons, inputs
  static const double md = 12; // standard cards
  static const double lg = 16; // panels
  static const double xl = 24; // sheets, modals, hero surfaces
  static const double pill = 999; // chips ONLY

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens.
///
/// `entrance` is Linear's signature easing — cubic-bezier(0.16, 1, 0.3, 1),
/// a hard decelerate that settles without overshoot. Elastic/bounce curves are
/// deliberately absent: overshoot on a money figure reads as toy-like.
abstract final class Motion {
  static const Duration tap = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration entrance = Duration(milliseconds: 260);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration route = Duration(milliseconds: 340);
  static const Duration count = Duration(milliseconds: 620);
  static const Duration chart = Duration(milliseconds: 700);

  /// cubic-bezier(0.16, 1, 0.3, 1) — Linear's decelerate.
  static const Curve decelerate = Cubic(0.16, 1, 0.3, 1);

  /// cubic-bezier(0.32, 0.72, 0, 1) — Linear's modal/sheet curve.
  static const Curve emphasized = Cubic(0.32, 0.72, 0, 1);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve smooth = Curves.easeInOut;

  /// 40ms per item, capped so a long list never feels sluggish at the tail.
  static Duration stagger(int index) =>
      Duration(milliseconds: (index.clamp(0, 12)) * 40);
}

/// A fully resolved token set for one brightness.
@immutable
class AppTokens {
  // Surfaces, darkest to lightest (Linear's 4-level elevation model).
  final Color canvas;
  final Color panel;
  final Color card;
  final Color hover;

  // Text ramp. Never pure white on dark, never pure black on light.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Hairline borders carry the depth on dark.
  final Color borderSubtle;
  final Color borderStandard;
  final Color borderStrong;

  // The single accent.
  final Color accent;
  final Color accentHover;
  final Color accentSubtle;

  // Money + status semantics.
  final Color success;
  final Color warning;
  final Color error;

  /// Empty on dark (luminance carries depth); one soft layer on light.
  final List<BoxShadow> cardShadow;

  /// Heavier stack for modals/sheets/floating nav, both modes.
  final List<BoxShadow> floatShadow;

  final Brightness brightness;

  const AppTokens({
    required this.canvas,
    required this.panel,
    required this.card,
    required this.hover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.borderSubtle,
    required this.borderStandard,
    required this.borderStrong,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.success,
    required this.warning,
    required this.error,
    required this.cardShadow,
    required this.floatShadow,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Near-black with a cool undertone, following Linear (#08090a) and
  /// Mercury (#171721). Pure #000 is avoided — it kills all elevation cues.
  static const AppTokens dark = AppTokens(
    canvas: Color(0xFF0A0A0C),
    panel: Color(0xFF121316),
    card: Color(0xFF1A1B1F),
    hover: Color(0xFF252630),
    textPrimary: Color(0xFFF5F6F7),
    textSecondary: Color(0xFFB0B4BC),
    textTertiary: Color(0xFF6B7080),
    textDisabled: Color(0xFF454850),
    borderSubtle: Color(0x0FFFFFFF), // white @ 6%
    borderStandard: Color(0x1AFFFFFF), // white @ 10%
    borderStrong: Color(0x26FFFFFF), // white @ 15%
    accent: Color(0xFF6366F1),
    accentHover: Color(0xFF818CF8),
    accentSubtle: Color(0x1F6366F1),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    cardShadow: <BoxShadow>[], // depth via luminance stepping, not shadow
    floatShadow: <BoxShadow>[
      BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
    brightness: Brightness.dark,
  );

  /// Cool near-white canvas with true-white cards, so cards read as lifted
  /// without needing a heavy shadow.
  static const AppTokens light = AppTokens(
    canvas: Color(0xFFFAFAFA),
    panel: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    hover: Color(0xFFF3F4F6),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF9CA3AF),
    textDisabled: Color(0xFFD1D5DB),
    borderSubtle: Color(0xFFF0F0F0),
    borderStandard: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    accent: Color(0xFF4F46E5), // deeper indigo for contrast on white
    accentHover: Color(0xFF4338CA),
    accentSubtle: Color(0x144F46E5),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    cardShadow: <BoxShadow>[
      BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    floatShadow: <BoxShadow>[
      BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
    brightness: Brightness.light,
  );

  static AppTokens forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;

  static AppTokens of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);

  /// Chart ramp: two hues (indigo + emerald) stepped through tints, rather
  /// than a rainbow. A multi-hue categorical palette is the clearest signal
  /// that a default charting library was dropped in unstyled.
  static const List<Color> chartRamp = <Color>[
    Color(0xFF6366F1), // indigo 500
    Color(0xFF34D399), // emerald 400
    Color(0xFF818CF8), // indigo 400
    Color(0xFF6EE7B7), // emerald 300
    Color(0xFFA5B4FC), // indigo 300
    Color(0xFFA7F3D0), // emerald 200
    Color(0xFFC7D2FE), // indigo 200
    Color(0xFFD1FAE5), // emerald 100
  ];
}

/// Ergonomic access: `context.tokens.accent`.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
}
