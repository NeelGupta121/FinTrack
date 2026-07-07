import 'package:dio/dio.dart';
import 'package:fintrack/core/config/env.dart';
import 'package:fintrack/core/network/rate_limiter.dart';
import 'package:fintrack/data/datasources/local/local_database.dart';

class AiChatService {
  static final _dio = Dio();
  static final _rateLimiter = RateLimiter();
  static const _model = 'gemini-1.5-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _systemPrompt =
      'You are a personal finance assistant for an Indian user. '
      'Answer based on their financial data provided as context. '
      'Use ₹ for amounts. Be concise and helpful.';

  static String buildContext() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final buf = StringBuffer('## Financial Summary (last 30 days)\n');

    // Transactions
    final txns = LocalDatabase.transactions.values.where((t) {
      final d = DateTime.tryParse(t['date'] ?? '');
      return d != null && d.isAfter(thirtyDaysAgo);
    }).toList();

    double totalExpense = 0, totalIncome = 0;
    final catSpend = <String, double>{};
    for (final t in txns) {
      final amt = (t['amount'] as num?)?.toDouble() ?? 0;
      if (t['type'] == 'income') {
        totalIncome += amt;
      } else {
        totalExpense += amt;
        final cat = t['category_id'] ?? 'Uncategorized';
        catSpend[cat] = (catSpend[cat] ?? 0) + amt;
      }
    }
    buf.writeln('Total income: ₹${totalIncome.toStringAsFixed(0)}');
    buf.writeln('Total expenses: ₹${totalExpense.toStringAsFixed(0)}');
    buf.writeln('Transaction count: ${txns.length}');
    if (catSpend.isNotEmpty) {
      final sorted = catSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('Top categories:');
      for (final e in sorted.take(5)) {
        buf.writeln('  - ${e.key}: ₹${e.value.toStringAsFixed(0)}');
      }
    }

    // Holdings
    final holdings = LocalDatabase.holdings.values.toList();
    if (holdings.isNotEmpty) {
      double portfolioValue = 0;
      buf.writeln('\n## Holdings (${holdings.length})');
      for (final h in holdings) {
        final val = ((h['quantity'] as num?)?.toDouble() ?? 0) *
            ((h['avg_price'] as num?)?.toDouble() ?? 0);
        portfolioValue += val;
        buf.writeln('  - ${h['name'] ?? h['symbol']}: ₹${val.toStringAsFixed(0)}');
      }
      buf.writeln('Portfolio value: ₹${portfolioValue.toStringAsFixed(0)}');
    }

    // Goals
    final goals = LocalDatabase.goals.values.toList();
    if (goals.isNotEmpty) {
      buf.writeln('\n## Goals');
      for (final g in goals) {
        buf.writeln('  - ${g['name']}: ₹${g['current_amount'] ?? 0} / ₹${g['target_amount'] ?? 0}');
      }
    }
    return buf.toString();
  }

  static bool _needsWebSearch(String question) {
    final q = question.toLowerCase();
    return q.contains('market') || q.contains('nifty') || q.contains('sensex') ||
        q.contains('stock price') || q.contains('news') || q.contains('gold') ||
        q.contains('crypto') || q.contains('bitcoin');
  }

  static Future<String> askQuestion(String question) async {
    const key = Env.geminiApiKey;
    if (key.isEmpty) {
      return 'AI chat is not configured. Please try again later.';
    }
    return _rateLimiter.execute('gemini_chat', 1000, () async {
      final context = buildContext();
      final parts = <Map<String, String>>[];

      if (_needsWebSearch(question)) {
        parts.add({'text': '$_systemPrompt\n\n$context\n\nThe user is asking about live market info. Provide your best knowledge about current Indian market conditions along with answering from their data.\n\nUser question: $question'});
      } else {
        parts.add({'text': '$_systemPrompt\n\n$context\n\nUser question: $question'});
      }

      try {
        final response = await _dio.post(
          '$_baseUrl?key=$key',
          data: {
            'contents': [{'parts': parts}],
            'generationConfig': {'maxOutputTokens': 512, 'temperature': 0.7},
          },
        );

        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final resParts = content['parts'] as List?;
          if (resParts != null && resParts.isNotEmpty) {
            return resParts[0]['text'] as String;
          }
        }
        // Check for safety blocks / empty response
        final blockReason = response.data['promptFeedback']?['blockReason'];
        if (blockReason != null) return 'Response blocked: $blockReason. Try rephrasing.';
        return 'Sorry, I could not generate a response. Please try again.';
      } on DioException catch (e) {
        // Surface the actual Gemini API error so it's diagnosable
        final status = e.response?.statusCode;
        final apiMsg = e.response?.data is Map
            ? (e.response?.data['error']?['message'] ?? '').toString()
            : '';
        if (status == 400 && apiMsg.contains('API key not valid')) {
          return 'Your Gemini API key is invalid. Re-check it in Settings → AI.';
        }
        if (status == 429) {
          return 'Gemini rate limit reached (free tier: 1500/day). Try again later.';
        }
        if (status == 404) {
          return 'Model unavailable for this key. Error: $apiMsg';
        }
        return 'AI error${status != null ? ' ($status)' : ''}: ${apiMsg.isNotEmpty ? apiMsg : e.message}';
      }
    });
  }
}
