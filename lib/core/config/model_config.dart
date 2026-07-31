import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import 'env.dart';

/// Runtime-switchable Gemini model.
///
/// Resolution order for the model used by every generateContent call:
///   1. Persisted user choice in settings ('gemini_model'), if set.
///   2. Build-time default [Env.geminiModel] (--dart-define override / code default).
///
/// This lets the app switch models on the fly (e.g. from Settings) without a
/// rebuild — useful when a model is retired, rate-limited, or you want a
/// cheaper/faster tier.
class GeminiModelConfig {
  static const _settingsKey = 'gemini_model';

  /// Curated list offered in the in-app model picker.
  static const available = <String>[
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  /// The effective model right now (persisted override, else build default).
  /// Never throws — falls back to the default if the settings box isn't open.
  static String get current {
    try {
      final v = LocalDatabase.settings.get(_settingsKey) as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {
      // settings box not initialised (e.g. very early startup) -> use default.
    }
    return Env.geminiModel;
  }

  /// Persist a runtime model override. Pass null/empty to clear (revert to default).
  static Future<void> set(String? model) async {
    if (model == null || model.trim().isEmpty) {
      await LocalDatabase.settings.delete(_settingsKey);
    } else {
      await LocalDatabase.settings.put(_settingsKey, model.trim());
    }
  }

  /// Full generateContent endpoint for the current model, built at call time so
  /// a mid-session switch takes effect on the next request.
  static String get generateContentUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$current:generateContent';
}

/// UI reactivity for the current model (Settings picker watches this). The AI
/// datasources read [GeminiModelConfig.current] directly, so this provider only
/// needs to mirror the persisted value for widget rebuilds.
final geminiModelProvider = StateProvider<String>((_) => GeminiModelConfig.current);
