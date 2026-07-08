import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/remote/news_api_ds.dart';
import '../../data/datasources/remote/gemini_ds.dart';
import '../../data/datasources/remote/ai_facade.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/holding.dart';
import '../../domain/usecases/analyze_spending.dart';
import '../../domain/usecases/analyze_portfolio.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';

final newsApiProvider = Provider((ref) => NewsApiDatasource());
// Routes through the secure proxy when configured, else direct Gemini.
final geminiProvider = Provider((ref) => AiFacade());
final analyzeSpendingProvider = Provider((ref) => AnalyzeSpendingUseCase());
final analyzePortfolioProvider = Provider((ref) => AnalyzePortfolioUseCase());

// Read from real data providers
final transactionsInputProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.watch(expenseListProvider.future);
});
final holdingsInputProvider = FutureProvider<List<Holding>>((ref) async {
  return ref.watch(holdingsListProvider.future);
});

final spendingAnomaliesProvider = FutureProvider<List<Anomaly>>((ref) async {
  try {
    final txns = await ref.watch(transactionsInputProvider.future);
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
    final holdings = await ref.watch(holdingsInputProvider.future);
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

final newsWithSentimentProvider = FutureProvider.autoDispose.family<List<NewsWithSentiment>, String>((ref, symbol) async {
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
    final holdings = await ref.watch(holdingsInputProvider.future);
    if (holdings.isEmpty) return 'Add investments to get a weekly digest.';
    final holdingsMap = {for (final h in holdings) h.symbol: {'qty': h.quantity, 'avg': h.avgPrice, 'type': h.type}};
    return gemini.portfolioReview(holdingsMap);
  } catch (e, st) {
    AppLogger.error('Failed to generate weekly digest', tag: 'Insights', error: e, stackTrace: st);
    return 'Unable to generate digest at this time. Please try again later.';
  }
});
