import '../entities/insight.dart';
import '../repositories/ai_repository.dart';

/// Get an AI-generated insight via Gemini Flash-Lite.
class GetAiInsight {
  final AiRepository _repo;
  GetAiInsight(this._repo);

  Future<Insight> sentiment(String headline, String snippet, String symbol) {
    return _repo.analyzeSentiment(headline, snippet, symbol);
  }

  Future<String> portfolioReview(Map<String, dynamic> portfolio) {
    return _repo.portfolioReview(portfolio);
  }
}
