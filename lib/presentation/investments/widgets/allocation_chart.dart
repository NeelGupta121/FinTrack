import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../common/theme/app_theme.dart';
import '../investment_providers.dart';

class AllocationChart extends StatelessWidget {
  final List<AllocationEntry> entries;
  const AllocationChart({super.key, required this.entries});

  static const _typeLabels = {
    'stock': 'Stocks',
    'mutual_fund': 'MF',
    'etf': 'ETF',
    'bond': 'Bonds',
    'gold': 'Gold',
  };

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asset Allocation', style: tt.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 172,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 52,
                        startDegreeOffset: -90 * (1 - t),
                        sections: entries.asMap().entries.map((e) {
                          final color = AppTheme.chartPalette[e.key % AppTheme.chartPalette.length];
                          return PieChartSectionData(
                            value: e.value.value,
                            color: color,
                            radius: (30 * t).clamp(0.5, 30).toDouble(),
                            title: t > 0.6 ? '${e.value.percent.toStringAsFixed(0)}%' : '',
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                    Opacity(
                      opacity: t,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currFmt.format(total), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Total', style: tt.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: entries.asMap().entries.map((e) {
                final color = AppTheme.chartPalette[e.key % AppTheme.chartPalette.length];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_typeLabels[e.value.type] ?? e.value.type,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
