import 'package:flutter/material.dart';
import '../../../domain/usecases/analyze_spending.dart';

class AnomalyCard extends StatelessWidget {
  final Anomaly anomaly;
  const AnomalyCard({super.key, required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final pct = anomaly.percentAboveAverage;
    final color = pct > 100 ? Colors.red : pct > 50 ? Colors.orange : Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(_categoryIcon(anomaly.category), color: color),
        ),
        title: Text('₹${anomaly.amount.toStringAsFixed(0)} in ${anomaly.category}'),
        subtitle: Text('${pct.toStringAsFixed(0)}% above average (₹${anomaly.average.toStringAsFixed(0)})'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text('${anomaly.zScore.toStringAsFixed(1)}σ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    const map = {
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'shopping': Icons.shopping_bag,
      'bills': Icons.receipt_long,
      'entertainment': Icons.movie,
      'health': Icons.local_hospital,
    };
    return map[category.toLowerCase()] ?? Icons.category;
  }
}
