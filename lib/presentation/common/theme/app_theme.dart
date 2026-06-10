import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF00897B); // Teal 600

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.light,
        textTheme: _textTheme,
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        textTheme: _textTheme,
      );

  static const _textTheme = TextTheme(
    headlineLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
    bodyLarge: TextStyle(fontSize: 16),
  );

  /// For displaying currency amounts prominently
  static TextStyle amountStyle(BuildContext context, {bool negative = false}) =>
      TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: negative
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      );
}
