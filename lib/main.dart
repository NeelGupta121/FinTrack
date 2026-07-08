import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
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

  // Optional secure AI proxy: initialize Supabase + an anonymous session so AI
  // calls route through the server (Gemini key stays server-side). Fully
  // skipped — and never fatal — when SUPABASE_URL/anon key aren't provided.
  if (Env.useAiProxy) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
      if (Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }
    } catch (e, st) {
      AppLogger.error('Supabase init/anon-auth failed; using direct AI path',
          tag: 'App', error: e, stackTrace: st);
    }
  }

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
