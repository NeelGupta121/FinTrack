import 'dart:math';
import '../../domain/entities/transaction.dart';

class Anomaly {
  final String category;
  final double amount;
  final double average;
  final double deviation;
  final double zScore;

  const Anomaly({
    required this.category,
    required this.amount,
    required this.average,
    required this.deviation,
    required this.zScore,
  });

  double get percentAboveAverage => ((amount - average) / average) * 100;
}

class AnalyzeSpendingUseCase {
  /// Detect anomalies using z-score > 2σ from 30-day category average.
  List<Anomaly> detectAnomalies(List<Transaction> transactions) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = transactions.where((t) => t.date.isAfter(cutoff) && t.type == 'expense').toList();

    // Group by category
    final Map<String, List<double>> categoryAmounts = {};
    for (final t in recent) {
      final cat = t.categoryId ?? 'uncategorized';
      categoryAmounts.putIfAbsent(cat, () => []).add(t.amount);
    }

    final anomalies = <Anomaly>[];
    for (final entry in categoryAmounts.entries) {
      final amounts = entry.value;
      if (amounts.length < 3) continue; // need enough data

      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance = amounts.map((a) => pow(a - mean, 2)).reduce((a, b) => a + b) / amounts.length;
      final stdDev = sqrt(variance);
      if (stdDev == 0) continue;

      for (final amount in amounts) {
        final z = (amount - mean) / stdDev;
        if (z > 2.0) {
          anomalies.add(Anomaly(
            category: entry.key,
            amount: amount,
            average: mean,
            deviation: stdDev,
            zScore: z,
          ));
        }
      }
    }
    anomalies.sort((a, b) => b.zScore.compareTo(a.zScore));
    return anomalies;
  }
}
