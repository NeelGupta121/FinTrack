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
      try {
        final json = jsonDecode(_extractJson(text)) as Map<String, dynamic>;
        return SentimentResult(
          sentiment: (json['sentiment'] as String?) ?? 'neutral',
          score: (json['score'] as num?)?.toDouble() ?? 0.0,
          reason: (json['reason'] as String?) ?? '',
        );
      } catch (_) {
        // Model returned prose / code-fenced / malformed JSON -> degrade gracefully.
        return const SentimentResult(sentiment: 'neutral', score: 0.0, reason: '');
      }
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
    // A safety-blocked candidate has no 'content'/'parts' -> navigate null-safely.
    final parts = (candidates[0] as Map?)?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    return (parts[0] as Map?)?['text'] as String? ?? '';
  }

  /// Extract a JSON object from a possibly code-fenced or prose-wrapped reply.
  String _extractJson(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    final m = fence.firstMatch(s);
    if (m != null) s = m.group(1)!.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) s = s.substring(start, end + 1);
    return s;
  }
}
