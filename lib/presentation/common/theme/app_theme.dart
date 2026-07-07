import 'package:flutter/material.dart';

/// FinTrack modern design system.
///
/// Indigo-violet brand + emerald/coral money semantics, soft canvas, rounded
/// outlined cards, pill inputs/buttons, a curated chart palette, and a distinct
/// type identity from BUNDLED fonts (offline-safe): Space Grotesk for
/// headings/amounts, Inter for body/labels. See pubspec `fonts:` + assets/fonts.
class AppTheme {
  static const seed = Color(0xFF6C5CE7); // indigo-violet brand
  static const positive = Color(0xFF12B886); // emerald — gains / income
  static const negative = Color(0xFFFF5A5F); // coral — losses / expense
  static const warning = Color(0xFFF59F00);

  static const displayFont = 'SpaceGrotesk';
  static const bodyFont = 'Inter';

  /// Modern categorical palette for charts (donuts, lines, legends).
  static const chartPalette = <Color>[
    Color(0xFF6C5CE7), // indigo-violet
    Color(0xFF12B886), // emerald
    Color(0xFFFF922B), // amber-orange
    Color(0xFF4DABF7), // sky
    Color(0xFFB06AB3), // mauve
    Color(0xFFFF6B6B), // coral
    Color(0xFF20C997), // teal
    Color(0xFFFAB005), // gold
  ];

  /// Brand gradient for hero surfaces (balance card, headers).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF8E7BFF), Color(0xFFB06AB3)],
  );

  // Premium dark palette: deep near-black canvas, elevated bordered surfaces.
  static const _darkCanvas = Color(0xFF0B0E14);
  static const _darkSurface = Color(0xFF161A23);
  static const _darkElevated = Color(0xFF1E2432);
  static const _darkBorder = Color(0xFF2A3040);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (isDark) {
      // Brighter violet reads better on dark; hand-tuned surfaces for depth.
      scheme = scheme.copyWith(
        primary: const Color(0xFF8E7BFF),
        onPrimary: Colors.white,
        secondary: const Color(0xFF12B886),
        surface: _darkSurface,
        onSurface: const Color(0xFFE7E9F0),
        onSurfaceVariant: const Color(0xFF9AA3B5),
        surfaceContainerHighest: _darkElevated,
        outlineVariant: _darkBorder,
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _darkCanvas : const Color(0xFFF6F7FB),
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isDark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withOpacity(isDark ? 0.4 : 0.7),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            scheme.surfaceContainerHighest.withOpacity(isDark ? 0.4 : 0.6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark ? _darkSurface : Colors.white,
        indicatorColor: scheme.primary.withOpacity(0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
              fontFamily: bodyFont, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    // Inter on every style, then Space Grotesk on the display/heading styles.
    final base = (scheme.brightness == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(fontFamily: bodyFont);
    return base.copyWith(
      displaySmall: base.displaySmall
          ?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w700, letterSpacing: -1),
      headlineMedium: base.headlineMedium
          ?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: base.headlineSmall
          ?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: base.titleLarge?.copyWith(
          fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );
  }

  /// Prominent currency amounts (Space Grotesk). Negatives use the coral
  /// semantic; positives stay neutral (green is reserved for explicit gains).
  static TextStyle amountStyle(BuildContext context, {bool negative = false}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: negative
            ? AppTheme.negative
            : Theme.of(context).colorScheme.onSurface,
      );
}
