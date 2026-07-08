import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/env.dart';
import 'ai_proxy_ds.dart';
import 'gemini_ds.dart';

/// Routes AI calls through the secure server-side proxy when Supabase is
/// configured (`Env.useAiProxy`) AND an authenticated session exists; otherwise
/// falls back to the direct client ([GeminiDatasource]) path. Return types match
/// [GeminiDatasource] so existing callers need no changes. Any proxy failure
/// degrades gracefully to the direct path.
class AiFacade {
  final GeminiDatasource _gemini;
  final AiProxyDatasource? _proxy;

  AiFacade({GeminiDatasource? gemini, AiProxyDatasource? proxy})
      : _gemini = gemini ?? GeminiDatasource(),
        _proxy = proxy ??
            (Env.useAiProxy
                ? AiProxyDatasource(
                    functionUrl: '${Env.supabaseUrl}/functions/v1/ai-proxy',
                    anonKey: Env.supabaseAnonKey,
                  )
                : null);

  String? get _token {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null; // Supabase not initialized
    }
  }

  Future<SentimentResult> analyzeSentiment(String headline, String snippet) async {
    final proxy = _proxy;
    final token = _token;
    if (proxy != null && token != null) {
      try {
        final m = await proxy.sentiment(token, headline, snippet);
        return SentimentResult(
          sentiment: (m['sentiment'] as String?) ?? 'neutral',
          score: (m['score'] as num?)?.toDouble() ?? 0.0,
          reason: (m['reason'] as String?) ?? '',
        );
      } catch (_) {
        // fall through to the direct path on any proxy failure
      }
    }
    return _gemini.analyzeSentiment(headline, snippet);
  }

  Future<String> portfolioReview(Map<String, dynamic> holdings) async {
    final proxy = _proxy;
    final token = _token;
    if (proxy != null && token != null) {
      try {
        return await proxy.portfolioReview(token, holdings);
      } catch (_) {
        // fall through to the direct path
      }
    }
    return _gemini.portfolioReview(holdings);
  }
}
