/// Environment configuration loaded via --dart-define at build time.
class Env {
  static const alphaVantageKey = String.fromEnvironment('ALPHA_VANTAGE_KEY');
  static const twelveDataKey = String.fromEnvironment('TWELVE_DATA_KEY');
  static const newsApiKey = String.fromEnvironment('NEWS_API_KEY');
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const fredApiKey = String.fromEnvironment('FRED_API_KEY', defaultValue: 'DEMO_KEY');

  // Secure AI proxy (Supabase). When both are set, AI calls route through the
  // server-side Edge Function (Gemini key stays on the server); otherwise the
  // app uses the direct client AI path.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get useAiProxy => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
