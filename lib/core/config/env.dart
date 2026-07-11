/// Environment configuration loaded via --dart-define at build time.
class Env {
  static const alphaVantageKey = String.fromEnvironment('ALPHA_VANTAGE_KEY');
  static const twelveDataKey = String.fromEnvironment('TWELVE_DATA_KEY');
  static const newsApiKey = String.fromEnvironment('NEWS_API_KEY');
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const fredApiKey = String.fromEnvironment('FRED_API_KEY', defaultValue: 'DEMO_KEY');

  /// Build-time DEFAULT Gemini model. A runtime override persisted in settings
  /// (see GeminiModelConfig) takes precedence when set. Overridable at build
  /// time too via --dart-define=GEMINI_MODEL=... The old gemini-1.5-flash was
  /// retired from the public API.
  static const geminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');

  // Secure AI proxy (Supabase). When both are set, AI calls route through the
  // server-side Edge Function (Gemini key stays on the server); otherwise the
  // app uses the direct client AI path.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get useAiProxy => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
