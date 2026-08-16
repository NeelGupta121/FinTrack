import 'dart:math';
import 'package:equatable/equatable.dart';

class RecurringBill extends Equatable {
  final String merchant;
  final double amount;
  final BillFrequency frequency;
  final DateTime nextDueDate;
  final double confidence;

  /// Dominant category id across the group, when the source rows carry one.
  /// Optional: the UI falls back to a generic icon when it is null.
  final String? categoryId;

  const RecurringBill({
    required this.merchant,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.confidence,
    this.categoryId,
  });

  @override
  List<Object?> get props => [merchant, amount, frequency, nextDueDate];
}

enum BillFrequency { weekly, biweekly, monthly, quarterly, yearly }

class DetectRecurringBills {
  List<RecurringBill> call(List<Map<String, dynamic>> transactions) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in transactions) {
      // A recurring bill is by definition money going OUT. Recurring income
      // (a monthly salary, a fixed freelance retainer) satisfies every
      // recurrence test — stable amount, stable ~30-day gap — so without this
      // filter it was emitted as a subscription and added to the "monthly
      // recurring" total, overstating committed spend by the income amount.
      //
      // Excluded by explicit 'income' rather than requiring 'expense', so rows
      // with a missing or unrecognised type keep their previous behaviour.
      if ((tx['type'] as String?) == 'income') continue;

      final merchant = tx['merchant'] as String? ?? tx['description'] as String? ?? 'Unknown';
      grouped.putIfAbsent(merchant, () => []).add(tx);
    }

    final bills = <RecurringBill>[];
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;

      final amounts = entry.value.map((t) => (t['amount'] as num? ?? 0).toDouble()).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      if (avgAmount <= 0) continue; // no meaningful recurring bill for ₹0/negative groups

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
        categoryId: _dominantCategory(entry.value),
      ));
    }
    return bills..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  }

  /// Most frequent non-empty `category_id` in the group, or null when the rows
  /// carry none. Ties resolve to whichever was counted first, which is stable
  /// for a given input ordering.
  String? _dominantCategory(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final r in rows) {
      final id = (r['category_id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    var best = counts.keys.first;
    for (final e in counts.entries) {
      if (e.value > counts[best]!) best = e.key;
    }
    return best;
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
        return _addMonths(lastDate, 1);
      case BillFrequency.quarterly:
        return _addMonths(lastDate, 3);
      case BillFrequency.yearly:
        return _addMonths(lastDate, 12);
    }
  }

  /// Adds [months] to [date], clamping the day to the last valid day of the
  /// target month so e.g. Jan 31 + 1 month = Feb 28 (not Mar 3 via overflow).
  DateTime _addMonths(DateTime date, int months) {
    final total = (date.month - 1) + months;
    final year = date.year + (total ~/ 12);
    final month = (total % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day; // day 0 of next month = last day
    return DateTime(year, month, min(date.day, lastDay));
  }

  double _calcConfidence(int count, List<double> amounts, double avg) {
    final base = (count / 6).clamp(0.3, 0.8);
    final variance = amounts.map((a) => (a - avg).abs() / avg).reduce((a, b) => a + b) / amounts.length;
    return (base + (1 - variance) * 0.2).clamp(0.0, 1.0);
  }
}
