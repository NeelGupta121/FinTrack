import 'package:equatable/equatable.dart';

class RecurringBill extends Equatable {
  final String merchant;
  final double amount;
  final BillFrequency frequency;
  final DateTime nextDueDate;
  final double confidence;

  const RecurringBill({
    required this.merchant,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.confidence,
  });

  @override
  List<Object?> get props => [merchant, amount, frequency, nextDueDate];
}

enum BillFrequency { weekly, biweekly, monthly, quarterly, yearly }

class DetectRecurringBills {
  List<RecurringBill> call(List<Map<String, dynamic>> transactions) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in transactions) {
      final merchant = tx['merchant'] as String? ?? tx['description'] as String? ?? 'Unknown';
      grouped.putIfAbsent(merchant, () => []).add(tx);
    }

    final bills = <RecurringBill>[];
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;

      final amounts = entry.value.map((t) => (t['amount'] as num? ?? 0).toDouble()).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

      // Check amount consistency (±5%)
      final consistent = amounts.every((a) => (a - avgAmount).abs() / avgAmount <= 0.05);
      if (!consistent) continue;

      final dates = entry.value
          .map((t) => DateTime.tryParse(t['date'] as String? ?? ''))
          .whereType<DateTime>()
          .toList()
        ..sort();
      if (dates.length < 2) continue;

      final frequency = _detectFrequency(dates);
      if (frequency == null) continue;

      final nextDue = _nextDueDate(dates.last, frequency);
      final confidence = _calcConfidence(entry.value.length, amounts, avgAmount);

      bills.add(RecurringBill(
        merchant: entry.key,
        amount: avgAmount,
        frequency: frequency,
        nextDueDate: nextDue,
        confidence: confidence,
      ));
    }
    return bills..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  }

  BillFrequency? _detectFrequency(List<DateTime> dates) {
    if (dates.length < 2) return null;
    final gaps = <int>[];
    for (var i = 1; i < dates.length; i++) {
      gaps.add(dates[i].difference(dates[i - 1]).inDays);
    }
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;

    if (avgGap >= 5 && avgGap <= 9) return BillFrequency.weekly;
    if (avgGap >= 12 && avgGap <= 17) return BillFrequency.biweekly;
    if (avgGap >= 25 && avgGap <= 35) return BillFrequency.monthly;
    if (avgGap >= 80 && avgGap <= 100) return BillFrequency.quarterly;
    if (avgGap >= 350 && avgGap <= 380) return BillFrequency.yearly;
    return null;
  }

  DateTime _nextDueDate(DateTime lastDate, BillFrequency freq) {
    switch (freq) {
      case BillFrequency.weekly:
        return lastDate.add(const Duration(days: 7));
      case BillFrequency.biweekly:
        return lastDate.add(const Duration(days: 14));
      case BillFrequency.monthly:
        return DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      case BillFrequency.quarterly:
        return DateTime(lastDate.year, lastDate.month + 3, lastDate.day);
      case BillFrequency.yearly:
        return DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
    }
  }

  double _calcConfidence(int count, List<double> amounts, double avg) {
    final base = (count / 6).clamp(0.3, 0.8);
    final variance = amounts.map((a) => (a - avg).abs() / avg).reduce((a, b) => a + b) / amounts.length;
    return (base + (1 - variance) * 0.2).clamp(0.0, 1.0);
  }
}
