import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../common/theme/app_theme.dart';

class BenchmarkChart extends StatelessWidget {
  const BenchmarkChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data — in production, fed by portfolioInsightsProvider.
    final portfolioSpots = List.generate(12, (i) => FlSpot(i.toDouble(), 100 + i * 2.5 + (i % 3) * 1.5));
    final niftySpots = List.generate(12, (i) => FlSpot(i.toDouble(), 100 + i * 2.0 + (i % 4) * 0.8));
    final tt = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio vs Nifty 50', style: tt.titleMedium),
            const SizedBox(height: 10),
            Row(children: [
              _legend(AppTheme.seed, 'Your Portfolio'),
              const SizedBox(width: 16),
              _legend(muted, 'Nifty 50'),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(_monthLabel(v.toInt()), style: TextStyle(fontSize: 10, color: muted)),
                  )),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: portfolioSpots,
                    color: AppTheme.seed,
                    dotData: const FlDotData(show: false),
                    barWidth: 3,
                    isCurved: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.seed.withOpacity(0.25), AppTheme.seed.withOpacity(0.0)],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: niftySpots,
                    color: muted,
                    dotData: const FlDotData(show: false),
                    barWidth: 2,
                    isCurved: true,
                    dashArray: const [5, 3],
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  String _monthLabel(int i) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i % 12];
}
