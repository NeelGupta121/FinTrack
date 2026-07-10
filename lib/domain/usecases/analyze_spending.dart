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

  double get percentAboveAverage => average == 0 ? 0 : ((amount - average) / average) * 100;
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

      // Reported (classic) mean — used for percentAboveAverage in the UI.
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;

      // Robust detection statistic: median + MAD (median absolute deviation).
      // Classic mean/std z-scores are corrupted by the very outlier they are
      // meant to flag — the outlier inflates std and deflates its own z-score,
      // so a genuine 5x spike can land just under a 2σ gate. Median/MAD is
      // resistant to that contamination.
      final median = _median(amounts);
      final absDeviations =
          amounts.map((a) => (a - median).abs()).toList();
      final mad = _median(absDeviations);

      // 1.4826 makes MAD a consistent estimator of std for normal data.
      var spread = 1.4826 * mad;
      var center = median;
      if (spread == 0) {
        // Degenerate MAD (>=half the values identical): fall back to std.
        final variance =
            amounts.map((a) => pow(a - mean, 2)).reduce((a, b) => a + b) /
                amounts.length;
        spread = sqrt(variance);
        center = mean;
      }
      if (spread == 0) continue; // all values identical — no anomalies

      for (final amount in amounts) {
        final z = (amount - center) / spread;
        if (z > 2.0) {
          anomalies.add(Anomaly(
            category: entry.key,
            amount: amount,
            average: mean,
            deviation: spread,
            zScore: z,
          ));
        }
      }
    }
    anomalies.sort((a, b) => b.zScore.compareTo(a.zScore));
    return anomalies;
  }

  /// Median of a list of doubles. Returns 0 for an empty list.
  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
