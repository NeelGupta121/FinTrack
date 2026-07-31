import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/usecases/spending_trend.dart';
import '../../../domain/usecases/tax_saving.dart';
import '../../expenses/expense_providers.dart';
import '../../investments/investment_providers.dart';

/// Section 80C progress toward the ₹1.5L annual deduction ceiling.
/// Hidden entirely when the user has flagged nothing as tax-saving, so it never
/// shows an empty ₹0 widget to someone not using the feature.
class Section80CCard extends ConsumerWidget {
  const Section80CCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(section80cProvider);
    if (p.count == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');
    final colour = p.limitReached ? Colors.green : cs.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: colour),
                const SizedBox(width: 8),
                Text('Tax saving (80C)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(p.fyLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${fmt.format(p.invested)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colour,
                        )),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 3),
                  child: Text('of ₹${fmt.format(Section80C.limit)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: p.fraction),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colour),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.limitReached
                  ? 'Ceiling reached — further 80C investment earns no extra deduction this year.'
                  : '₹${fmt.format(p.remaining)} of headroom left across ${p.count} '
                      '${p.count == 1 ? 'holding' : 'holdings'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Month-over-month spending bars for the last 6 months, with a grow-in
/// animation and a change-vs-last-month readout.
class SpendingTrendCard extends ConsumerWidget {
  const SpendingTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(spendingTrendProvider);
    final cs = Theme.of(context).colorScheme;
    final compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Nothing logged in any of the 6 months -> don't render an empty chart.
    final maxVal = series.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    if (maxVal <= 0) return const SizedBox.shrink();

    final mom = SpendingTrend.momChangePercent(series);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Spending trend',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (mom != null)
                  Text(
                    '${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(0)}% vs last month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mom > 0 ? cs.error : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        '${series[group.x].label}\n${compact.format(rod.toY)}',
                        TextStyle(color: cs.onInverseSurface, fontSize: 11),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= series.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(series[i].label,
                                style: Theme.of(context).textTheme.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < series.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: series[i].total,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            // Highlight the current month.
                            color: i == series.length - 1
                                ? cs.primary
                                : cs.primary.withOpacity(0.35),
                          ),
                        ],
                      ),
                  ],
                ),
                // fl_chart animates bar height changes on rebuild.
                swapAnimationDuration: const Duration(milliseconds: 650),
                swapAnimationCurve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
