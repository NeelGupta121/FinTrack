import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../investment_providers.dart';

class AllocationChart extends StatelessWidget {
  final List<AllocationEntry> entries;
  const AllocationChart({super.key, required this.entries});

  static const _colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];
  static const _typeLabels = {'stock': 'Stocks', 'mutual_fund': 'MF', 'etf': 'ETF', 'bond': 'Bonds', 'gold': 'Gold'};

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asset Allocation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: entries.asMap().entries.map((e) {
                        final color = _colors[e.key % _colors.length];
                        return PieChartSectionData(
                          value: e.value.value,
                          color: color,
                          radius: 35,
                          title: '${e.value.percent.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                  Text(currFmt.format(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: entries.asMap().entries.map((e) {
                final color = _colors[e.key % _colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(_typeLabels[e.value.type] ?? e.value.type, style: const TextStyle(fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
