import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../investment_providers.dart';

class PortfolioValueCard extends StatelessWidget {
  final PortfolioValue portfolio;
  const PortfolioValueCard({super.key, required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isProfit = portfolio.totalPnL >= 0;
    final isDayUp = portfolio.dayChange >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio Value', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(currFmt.format(portfolio.currentValue), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _PnLChip(label: 'P&L', amount: portfolio.totalPnL, percent: portfolio.totalPnLPercent, isPositive: isProfit),
                const SizedBox(width: 12),
                _PnLChip(label: 'Day', amount: portfolio.dayChange, percent: portfolio.dayChangePercent, isPositive: isDayUp),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: portfolio.sparkline.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: isProfit ? Colors.green : Colors.red,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: (isProfit ? Colors.green : Colors.red).withOpacity(0.1)),
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
    final color = isPositive ? Colors.green : Colors.red;
    final sign = isPositive ? '+' : '';
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '$label: $sign${currFmt.format(amount)} (${percent.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
