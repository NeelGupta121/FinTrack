import '../entities/insight.dart';

/// Contract for AI/ML operations.
abstract class AiRepository {
  Future<String> categorizeExpense(String description);
  Future<Insight> analyzeSentiment(String headline, String snippet, String symbol);
  Future<String> portfolioReview(Map<String, dynamic> portfolio);
  Future<String> askQuestion(String question, Map<String, dynamic> context);
  // TODO: detectAnomalies, generateWeeklyDigest
}
