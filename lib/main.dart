import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'data/datasources/local/local_database.dart';
import 'core/security/tamper_detection.dart';
import 'core/utils/logger.dart';
import 'services/insight_scheduler_service.dart';
import 'presentation/settings/settings_screen.dart' show savedThemeMode;
import 'app.dart';

Future<void> main() async {
  // Run the whole app inside a guarded zone so any async error that escapes a
  // widget is logged instead of silently killing the app.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Replace Flutter's default red/gray crash box with a friendly, recoverable
    // screen. A single screen throwing must never look like "the whole app is dead".
    ErrorWidget.builder = (FlutterErrorDetails details) => _FatalErrorScreen(details: details);

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

  // Register the daily background insights task (Android/iOS only; Workmanager
  // is unavailable on web). Non-fatal — a failure must never block startup.
  if (!kIsWeb) {
    try {
      await InsightSchedulerService.scheduleDaily();
    } catch (e, st) {
      AppLogger.error('Failed to schedule daily insights', tag: 'App', error: e, stackTrace: st);
    }
  }

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
  }, (error, stack) {
    AppLogger.error('Uncaught zone error', tag: 'Zone', error: error, stackTrace: stack);
  });
}

/// Full-screen fallback shown when a widget subtree throws — replaces the
/// default gray/red error box. Wraps itself in Directionality + Material so it
/// renders safely even outside a MaterialApp context.
class _FatalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _FatalErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF0E0F1A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 52),
                const SizedBox(height: 16),
                const Text('This screen hit a problem',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Your data is safe. Go back and try again, or restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Text(details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
