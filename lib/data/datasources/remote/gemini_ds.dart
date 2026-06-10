import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/network/rate_limiter.dart';

class SentimentResult {
  final String sentiment; // bullish, bearish, neutral
  final double score; // -1.0 to 1.0
  final String reason;

  const SentimentResult({required this.sentiment, required this.score, required this.reason});
}

class GeminiDatasource {
  final Dio _dio;
  final RateLimiter _limiter;
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';

  GeminiDatasource({Dio? dio, RateLimiter? limiter})
      : _dio = dio ?? Dio(),
        _limiter = limiter ?? RateLimiter();

  Future<SentimentResult> analyzeSentiment(String headline, String snippet) {
    return _limiter.execute('gemini', 1000, () async {
      final text = await _generate(
        'Analyze financial sentiment. Return JSON: {"sentiment":"bullish|bearish|neutral","score":<-1to1>,"reason":"<brief>"}\n\nHeadline: $headline\nSnippet: $snippet',
      );
      final json = jsonDecode(text);
      return SentimentResult(
        sentiment: json['sentiment'] ?? 'neutral',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        reason: json['reason'] ?? '',
      );
    });
  }

  Future<String> portfolioReview(Map<String, dynamic> holdings) {
    return _limiter.execute('gemini', 1000, () async {
      return _generate(
        'Review this Indian portfolio and give 3 actionable insights in 100 words:\n${jsonEncode(holdings)}',
      );
    });
  }

  Future<String> askQuestion(String question, Map<String, dynamic> context) {
    return _limiter.execute('gemini', 1000, () async {
      return _generate('Context: ${jsonEncode(context)}\n\nQuestion: $question');
    });
  }

  Future<String> _generate(String prompt) async {
    final res = await _dio.post(
      '$_base?key=${Env.geminiApiKey}',
      data: {
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 512},
      },
    );
    final candidates = res.data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    return candidates[0]['content']['parts'][0]['text'] ?? '';
  }
}
