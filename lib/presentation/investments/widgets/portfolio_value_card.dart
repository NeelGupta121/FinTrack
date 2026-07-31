import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../common/theme/app_theme.dart';
import '../investment_providers.dart';

class PortfolioValueCard extends StatelessWidget {
  final PortfolioValue portfolio;

  /// Annualised money-weighted return (%). Null when it can't be computed
  /// (no dated holdings, or the solver didn't converge).
  final double? xirr;

  const PortfolioValueCard({super.key, required this.portfolio, this.xirr});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isProfit = portfolio.totalPnL >= 0;
    final isDayUp = portfolio.dayChange >= 0;
    final lineColor = isProfit ? AppTheme.positive : AppTheme.negative;

    final raw = portfolio.sparkline;
    final spots = raw.isEmpty
        ? const [FlSpot(0, 0), FlSpot(1, 0)] // fl_chart needs >=2 points
        : <FlSpot>[
            for (var i = 0; i < raw.length; i++) FlSpot(i.toDouble(), raw[i]),
            if (raw.length == 1) FlSpot(1, raw.first),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio Value',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(currFmt.format(portfolio.currentValue),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                _PnLChip(label: 'P&L', amount: portfolio.totalPnL, percent: portfolio.totalPnLPercent, isPositive: isProfit),
                const SizedBox(width: 12),
                _PnLChip(label: 'Day', amount: portfolio.dayChange, percent: portfolio.dayChangePercent, isPositive: isDayUp),
              ],
            ),
            if (xirr != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timeline,
                      size: 14,
                      color: xirr! >= 0 ? AppTheme.positive : AppTheme.negative),
                  const SizedBox(width: 6),
                  Text('XIRR ${xirr! >= 0 ? '+' : ''}${xirr!.toStringAsFixed(1)}% p.a.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: xirr! >= 0 ? AppTheme.positive : AppTheme.negative,
                          )),
                  const SizedBox(width: 6),
                  Text('annualised',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [lineColor.withOpacity(0.28), lineColor.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PnLChip extends StatelessWidget {
  final String label;
  final double amount;
  final double percent;
  final bool isPositive;
  const _PnLChip({required this.label, required this.amount, required this.percent, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppTheme.positive : AppTheme.negative;
    final sign = isPositive ? '+' : '';
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(30)),
      child: Text(
        '$label: $sign${currFmt.format(amount)} (${percent.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
