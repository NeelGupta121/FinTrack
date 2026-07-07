import 'package:dio/dio.dart';

/// Client for the server-side AI proxy (Supabase Edge Function `ai-proxy`).
///
/// The Gemini key lives ONLY on the server. This client sends the user's
/// Supabase access token (from an authenticated or anonymous session) plus the
/// project anon key, and receives only the generated text/JSON back — never the
/// key. It is intentionally free of any Supabase SDK dependency: callers pass
/// the session `accessToken` in, so wiring this does not force a package add
/// beyond `supabase_flutter` for obtaining the session itself.
class AiProxyDatasource {
  final Dio _dio;

  /// e.g. https://<project-ref>.supabase.co/functions/v1/ai-proxy
  final String functionUrl;

  /// The project anon key (safe to ship; it is not the Gemini key).
  final String anonKey;

  AiProxyDatasource({
    required this.functionUrl,
    required this.anonKey,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  Future<dynamic> _call(String accessToken, Map<String, dynamic> body) async {
    final res = await _dio.post(
      functionUrl,
      data: body,
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
        'apikey': anonKey,
        'Content-Type': 'application/json',
      }),
    );
    return res.data;
  }

  /// Returns {sentiment, score, reason}.
  Future<Map<String, dynamic>> sentiment(
      String accessToken, String headline, String snippet) async {
    final data = await _call(accessToken, {
      'action': 'sentiment',
      'headline': headline,
      'snippet': snippet,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<String> portfolioReview(
      String accessToken, Map<String, dynamic> holdings) async {
    final data = await _call(accessToken, {
      'action': 'portfolioReview',
      'holdings': holdings,
    });
    return (data is Map ? data['text'] as String? : null) ?? '';
  }

  Future<String> askQuestion(
      String accessToken, String question, Map<String, dynamic> context) async {
    final data = await _call(accessToken, {
      'action': 'askQuestion',
      'question': question,
      'context': context,
    });
    return (data is Map ? data['text'] as String? : null) ?? '';
  }
}
