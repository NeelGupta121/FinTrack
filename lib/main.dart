import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/logger.dart';
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

  await SupabaseConfig.init();

  runApp(const ProviderScope(child: FinTrackApp()));
}
