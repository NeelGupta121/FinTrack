import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/local/local_database.dart';
import 'core/security/tamper_detection.dart';
import 'core/utils/logger.dart';
import 'presentation/settings/settings_screen.dart' show savedThemeMode;
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error('Flutter error: ${details.exceptionAsString()}',
        tag: 'Flutter', error: details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Uncaught error', tag: 'Platform', error: error, stackTrace: stack);
    return true;
  };

  AppLogger.info('FinTrack starting', tag: 'App');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await LocalDatabase.init();
  await TamperDetection.init();

  // Cache onboarding status synchronously for GoRouter redirect
  final prefs = await SharedPreferences.getInstance();
  onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  // Load persisted theme mode
  final tm = prefs.getString('theme_mode');
  if (tm == 'dark') {
    savedThemeMode = ThemeMode.dark;
  } else if (tm == 'light') {
    savedThemeMode = ThemeMode.light;
  }

  runApp(const ProviderScope(child: FinTrackApp()));
}
