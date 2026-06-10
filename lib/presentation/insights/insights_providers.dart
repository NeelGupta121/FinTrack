import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/remote/news_api_ds.dart';
import '../../data/datasources/remote/gemini_ds.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/holding.dart';
import '../../domain/usecases/analyze_spending.dart';
import '../../domain/usecases/analyze_portfolio.dart';

final newsApiProvider = Provider((ref) => NewsApiDatasource());
final geminiProvider = Provider((ref) => GeminiDatasource());
final analyzeSpendingProvider = Provider((ref) => AnalyzeSpendingUseCase());
final analyzePortfolioProvider = Provider((ref) => AnalyzePortfolioUseCase());

// Input providers (set by parent screens)
final transactionsInputProvider = StateProvider<List<Transaction>>((ref) => []);
final holdingsInputProvider = StateProvider<List<Holding>>((ref) => []);

final spendingAnomaliesProvider = FutureProvider<List<Anomaly>>((ref) async {
  try {
    final txns = ref.watch(transactionsInputProvider);
    final useCase = ref.read(analyzeSpendingProvider);
    return useCase.detectAnomalies(txns);
  } catch (e, st) {
    AppLogger.error('Failed to detect spending anomalies', tag: 'Insights', error: e, stackTrace: st);
    return [];
  }
});

final portfolioInsightsProvider = FutureProvider<BenchmarkResult?>((ref) async {
  try {
    final useCase = ref.read(analyzePortfolioProvider);
    return useCase.compareVsBenchmark({}, {});
  } catch (e, st) {
    AppLogger.error('Failed to fetch portfolio insights', tag: 'Insights', error: e, stackTrace: st);
    return null;
  }
});

final driftAlertsProvider = FutureProvider<List<DriftAlert>>((ref) async {
  try {
    final holdings = ref.watch(holdingsInputProvider);
    final useCase = ref.read(analyzePortfolioProvider);
    return useCase.detectDrift(holdings);
  } catch (e, st) {
    AppLogger.error('Failed to detect portfolio drift', tag: 'Insights', error: e, stackTrace: st);
    return [];
  }
});

class NewsWithSentiment {
  final NewsArticle article;
  final SentimentResult sentiment;
  const NewsWithSentiment({required this.article, required this.sentiment});
}

final newsWithSentimentProvider = FutureProvider.family<List<NewsWithSentiment>, String>((ref, symbol) async {
  final newsApi = ref.read(newsApiProvider);
  final gemini = ref.read(geminiProvider);
  final articles = await newsApi.getHeadlines(symbol);
  final results = <NewsWithSentiment>[];
  for (final a in articles) {
    try {
      final sentiment = await gemini.analyzeSentiment(a.title, a.snippet);
      results.add(NewsWithSentiment(article: a, sentiment: sentiment));
    } catch (_) {
      results.add(NewsWithSentiment(
        article: a,
        sentiment: const SentimentResult(sentiment: 'neutral', score: 0, reason: 'Analysis unavailable'),
      ));
    }
  }
  return results;
});

final weeklyDigestProvider = FutureProvider<String>((ref) async {
  try {
    final gemini = ref.read(geminiProvider);
    final holdings = ref.watch(holdingsInputProvider);
    if (holdings.isEmpty) return 'Add investments to get a weekly digest.';
    final holdingsMap = {for (final h in holdings) h.symbol: {'qty': h.quantity, 'avg': h.avgPrice, 'type': h.type}};
    return gemini.portfolioReview(holdingsMap);
  } catch (e, st) {
    AppLogger.error('Failed to generate weekly digest', tag: 'Insights', error: e, stackTrace: st);
    return 'Unable to generate digest at this time. Please try again later.';
  }
});
