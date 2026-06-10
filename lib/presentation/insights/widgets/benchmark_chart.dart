import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BenchmarkChart extends StatelessWidget {
  const BenchmarkChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data - in production, fed by portfolioInsightsProvider
    final portfolioSpots = List.generate(12, (i) => FlSpot(i.toDouble(), 100 + i * 2.5 + (i % 3) * 1.5));
    final niftySpots = List.generate(12, (i) => FlSpot(i.toDouble(), 100 + i * 2.0 + (i % 4) * 0.8));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portfolio vs Nifty 50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(children: [
              _legend(Colors.blue, 'Your Portfolio'),
              const SizedBox(width: 16),
              _legend(Colors.grey, 'Nifty 50'),
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
                    getTitlesWidget: (v, _) => Text(_monthLabel(v.toInt()), style: const TextStyle(fontSize: 10)),
                  )),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(spots: portfolioSpots, color: Colors.blue, dotData: const FlDotData(show: false), barWidth: 2.5),
                  LineChartBarData(spots: niftySpots, color: Colors.grey, dotData: const FlDotData(show: false), barWidth: 2, dashArray: [5, 3]),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  String _monthLabel(int i) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i % 12];
}
