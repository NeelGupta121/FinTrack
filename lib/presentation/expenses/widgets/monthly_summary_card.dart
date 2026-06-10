import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../expense_providers.dart';
import 'category_picker.dart';

class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummary summary;
  const MonthlySummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final remaining = summary.budget - summary.totalSpent;
    final progress = (summary.totalSpent / summary.budget).clamp(0.0, 1.0);

    // Top 3 categories by spend
    final sorted = summary.categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('This Month', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(fmt.format(summary.totalSpent), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(fmt.format(remaining), style: TextStyle(fontSize: 16, color: remaining < 0 ? Colors.red : Colors.green)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[200], color: progress > 0.9 ? Colors.red : Colors.blue),
            ),
            const SizedBox(height: 16),
            ...top3.map((entry) {
              final cat = categories.firstWhere((c) => c.id == entry.key, orElse: () => categories.last);
              final catProgress = entry.value / summary.totalSpent;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(cat.icon, size: 16, color: cat.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cat.label, style: const TextStyle(fontSize: 12))),
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: catProgress, minHeight: 4, backgroundColor: Colors.grey[200], color: cat.color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(fmt.format(entry.value), style: const TextStyle(fontSize: 11)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}
