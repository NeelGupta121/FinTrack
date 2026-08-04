import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

/// ---------------------------------------------------------------------------
/// Type scale.
///
/// The important decision here is that large type gets LIGHTER, not heavier.
/// Space Grotesk's weight axis runs 300-700 and its default instance is
/// Light 300, so a 44px hero numeral at w300 costs nothing and is the single
/// change that most separates this from a stock Material screen.
///
/// Every monetary figure uses `FontFeature.tabularFigures()` so digits occupy
/// equal advance widths and columns of amounts align. This is free (an
/// OpenType feature, no GPU cost) and both bundled fonts support `tnum`.
///
/// Note: do NOT ask Space Grotesk for w800 — the axis caps at 700 and Flutter
/// silently clamps, so the intended extra step just doesn't render.
/// ---------------------------------------------------------------------------
abstract final class AppText {
  static const String display = 'SpaceGrotesk';
  static const String body = 'Inter';

  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  /// Hero balance. Large, light, tabular.
  static TextStyle hero(Color color, {double size = 44}) => TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.0,
        height: 1.05,
        color: color,
        fontFeatures: _tnum,
      );

  /// Any currency amount in a row, card or table.
  static TextStyle money(
    Color color, {
    double size = 16,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.3,
        color: color,
        fontFeatures: _tnum,
      );

  /// Screen / major section heading.
  static TextStyle section(Color color, {double size = 24}) => TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      );

  /// Card heading.
  static TextStyle cardTitle(Color color) => TextStyle(
        fontFamily: display,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle bodyText(Color color, {FontWeight? weight}) => TextStyle(
        fontFamily: body,
        fontSize: 15,
        fontWeight: weight ?? FontWeight.w400,
        height: 1.45,
        color: color,
      );

  static TextStyle caption(Color color, {FontWeight? weight}) => TextStyle(
        fontFamily: body,
        fontSize: 13,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: -0.1,
        color: color,
      );

  /// Uppercase eyebrow label sitting above a value ("TOTAL BALANCE").
  static TextStyle micro(Color color) => TextStyle(
        fontFamily: body,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: color,
      );
}

class AppTheme {
  // ---- Backwards-compatible surface -------------------------------------
  // Existing screens and tests reference these names directly. They now
  // resolve to the new token values so old call sites pick up the refresh
  // instead of fighting it.

  static const Color seed = Color(0xFF6366F1);
  static const Color positive = Color(0xFF22C55E);
  static const Color negative = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const String displayFont = AppText.display;
  static const String bodyFont = AppText.body;

  /// Two-hue stepped ramp. Replaces the previous 8-hue rainbow.
  static const List<Color> chartPalette = AppTokens.chartRamp;

  /// Restrained brand gradient for the one hero surface per screen.
  /// The previous version added a 30px 45%-opacity purple glow, which is the
  /// clearest "2021 dashboard" tell; this stays inside the indigo family.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF7C7FF5)],
  );

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final t = AppTokens.forBrightness(brightness);
    final isDark = t.isDark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: Colors.white,
      primaryContainer: t.accentSubtle,
      onPrimaryContainer: t.accent,
      secondary: t.success,
      onSecondary: Colors.white,
      surface: t.card,
      onSurface: t.textPrimary,
      surfaceContainerLowest: t.canvas,
      surfaceContainerLow: t.panel,
      surfaceContainer: t.card,
      surfaceContainerHigh: t.hover,
      surfaceContainerHighest: t.hover,
      onSurfaceVariant: t.textSecondary,
      outline: t.borderStrong,
      outlineVariant: t.borderStandard,
      error: t.error,
      onError: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: t.textPrimary,
      onInverseSurface: t.canvas,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(t),

      appBarTheme: AppBarTheme(
        backgroundColor: t.canvas,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.section(t.textPrimary, size: 20),
        iconTheme: IconThemeData(color: t.textSecondary, size: 22),
      ),

      // Hairline border, no shadow on dark. Radius drops 20 -> 12; oversized
      // radii on every card is part of what dates the current look.
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: t.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.transparent : const Color(0x0D000000),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brMd,
          side: BorderSide(color: t.borderStandard),
        ),
      ),

      // 8px on actions, not pill. Pill primaries now read as 2022.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: Space.lg, vertical: Space.md + 2),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
          textStyle: const TextStyle(
            fontFamily: AppText.body,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: Space.lg, vertical: Space.md + 2),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.borderStrong),
          padding: const EdgeInsets.symmetric(
              horizontal: Space.lg, vertical: Space.md + 2),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          padding: const EdgeInsets.symmetric(
              horizontal: Space.md, vertical: Space.sm),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
          textStyle: const TextStyle(
            fontFamily: AppText.body,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? t.panel : t.panel,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.lg, vertical: Space.md + 2),
        hintStyle: AppText.bodyText(t.textTertiary),
        labelStyle: AppText.caption(t.textSecondary),
        border: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: t.borderStandard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: t.borderStandard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: t.error),
        ),
      ),

      // Pill is correct here — chips are exactly what it's reserved for.
      chipTheme: ChipThemeData(
        backgroundColor: t.panel,
        selectedColor: t.accentSubtle,
        checkmarkColor: t.accent,
        side: BorderSide(color: t.borderStandard),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brPill),
        labelStyle: AppText.caption(t.textSecondary, weight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.md, vertical: Space.sm),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: t.borderStandard)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brSm),
          ),
          textStyle: WidgetStatePropertyAll(
            AppText.caption(t.textPrimary, weight: FontWeight.w600),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: t.panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accentSubtle,
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: Radii.brPill),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppText.body,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? t.accent : t.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? t.accent : t.textTertiary,
          );
        }),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.lg, vertical: Space.xs),
        iconColor: t.textSecondary,
        titleTextStyle: AppText.bodyText(t.textPrimary, weight: FontWeight.w500),
        subtitleTextStyle: AppText.caption(t.textTertiary),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
      ),

      dividerTheme: DividerThemeData(
        color: t.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brXl,
          side: BorderSide(color: t.borderStandard),
        ),
        titleTextStyle: AppText.cardTitle(t.textPrimary),
        contentTextStyle: AppText.bodyText(t.textSecondary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? t.hover : const Color(0xFF1F2937),
        contentTextStyle: AppText.caption(Colors.white, weight: FontWeight.w500),
        actionTextColor: t.accentHover,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : t.textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accent : t.panel),
        trackOutlineColor:
            WidgetStateProperty.resolveWith((s) => t.borderStandard),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accent : Colors.transparent),
        side: BorderSide(color: t.borderStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brXs),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.panel,
        circularTrackColor: t.panel,
        linearMinHeight: 6,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? t.hover : const Color(0xFF1F2937),
          borderRadius: Radii.brSm,
        ),
        textStyle: AppText.caption(Colors.white),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static TextTheme _textTheme(AppTokens t) => TextTheme(
        displayLarge: AppText.hero(t.textPrimary, size: 52),
        displayMedium: AppText.hero(t.textPrimary, size: 44),
        displaySmall: AppText.hero(t.textPrimary, size: 36),
        headlineLarge: AppText.section(t.textPrimary, size: 28),
        headlineMedium: AppText.section(t.textPrimary, size: 24),
        headlineSmall: AppText.section(t.textPrimary, size: 20),
        titleLarge: AppText.cardTitle(t.textPrimary),
        titleMedium:
            AppText.bodyText(t.textPrimary, weight: FontWeight.w600),
        titleSmall: AppText.caption(t.textPrimary, weight: FontWeight.w600),
        bodyLarge: AppText.bodyText(t.textPrimary),
        bodyMedium: AppText.bodyText(t.textSecondary),
        bodySmall: AppText.caption(t.textTertiary),
        labelLarge:
            AppText.bodyText(t.textPrimary, weight: FontWeight.w600),
        labelMedium: AppText.caption(t.textSecondary, weight: FontWeight.w500),
        labelSmall: AppText.micro(t.textTertiary),
      );

  /// Prominent currency amount. Kept for existing call sites; now tabular and
  /// medium-weight rather than bold.
  static TextStyle amountStyle(BuildContext context, {bool negative = false}) {
    final t = AppTokens.of(context);
    return AppText.money(
      negative ? t.error : t.textPrimary,
      size: 20,
    );
  }
}
