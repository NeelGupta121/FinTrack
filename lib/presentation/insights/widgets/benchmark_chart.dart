import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../common/theme/app_theme.dart';

class BenchmarkChart extends StatelessWidget {
  const BenchmarkChart({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Placeholder data — in production, fed by portfolioInsightsProvider.
    final portfolioSpots = List.generate(
        12, (i) => FlSpot(i.toDouble(), 100 + i * 2.5 + (i % 3) * 1.5));
    final niftySpots = List.generate(
        12, (i) => FlSpot(i.toDouble(), 100 + i * 2.0 + (i % 4) * 0.8));

    final primaryColor = AppTokens.chartRamp[0]; // indigo
    final secondaryColor = AppTokens.chartRamp[1]; // emerald

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portfolio vs Nifty 50', style: AppText.cardTitle(t.textPrimary)),
          const SizedBox(height: Space.sm),
          Row(children: [
            _legend(primaryColor, 'Your Portfolio'),
            const SizedBox(width: Space.lg),
            _legend(secondaryColor, 'Nifty 50'),
          ]),
          const SizedBox(height: Space.lg),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      _monthLabel(v.toInt()),
                      style: AppText.micro(t.textTertiary),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: portfolioSpots,
                  color: primaryColor,
                  dotData: const FlDotData(show: false),
                  barWidth: 2,
                  isCurved: true,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor.withOpacity(0.26),
                        primaryColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: niftySpots,
                  color: secondaryColor,
                  dotData: const FlDotData(show: false),
                  barWidth: 2,
                  isCurved: true,
                  isStrokeCapRound: true,
                  dashArray: const [5, 3],
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: Radii.brXs,
            ),
          ),
          const SizedBox(width: Space.xs + 2),
          Text(label, style: AppText.caption(color, weight: FontWeight.w500)),
        ],
      );

  String _monthLabel(int i) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][i % 12];
}
