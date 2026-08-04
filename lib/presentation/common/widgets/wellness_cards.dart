import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/usecases/net_worth.dart';
import '../../../domain/usecases/spending_trend.dart';
import '../../../domain/usecases/tax_saving.dart';
import '../../accounts/accounts_providers.dart';
import '../../expenses/expense_providers.dart';
import '../../investments/investment_providers.dart';
import '../theme/app_animations.dart';
import '../theme/app_theme.dart';

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
    final colour = p.limitReached ? AppTokens.of(context).success : cs.primary;

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
                          color: mom > 0 ? cs.error : AppTokens.of(context).success,
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

/// Real net worth: cash accounts + investments − debts, with a trend line and
/// an explainable breakdown. Prompts the user to add accounts when empty rather
/// than showing a meaningless ₹0.
/// Net worth — the dashboard hero.
///
/// Presented as the single dominant figure rather than one card among four.
/// The numeral is large and LIGHT (w300) with tabular figures: oversized bold
/// type is the clearest "template dashboard" tell, whereas thin large type is
/// what reads as premium in Mercury / Linear / Copilot.
class NetWorthCard extends ConsumerWidget {
  final VoidCallback? onManageAccounts;
  const NetWorthCard({super.key, this.onManageAccounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final fmt = NumberFormat('#,##0');
    final async = ref.watch(netWorthProvider);

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brXl,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: async.when(
        loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => SizedBox(
            height: 96,
            child: Center(
                child: Text('Net worth unavailable',
                    style: AppText.caption(t.textTertiary)))),
        data: (nw) {
          // Record today's reading so the trend builds up over time.
          if (!nw.isEmpty) {
            final record = ref.read(netWorthRecorderProvider);
            WidgetsBinding.instance.addPostFrameCallback((_) => record(nw));
          }

          if (nw.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NET WORTH', style: AppText.micro(t.textTertiary)),
                const SizedBox(height: Space.md),
                Text('Add your accounts to see this',
                    style: AppText.cardTitle(t.textPrimary)),
                const SizedBox(height: Space.xs),
                Text(
                  'Enter bank/cash balances and any money owed. Combined with '
                  'your investments, that gives a real net worth.',
                  style: AppText.caption(t.textTertiary),
                ),
                if (onManageAccounts != null) ...[
                  const SizedBox(height: Space.lg),
                  FilledButton.icon(
                    onPressed: onManageAccounts,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add accounts'),
                  ),
                ],
              ],
            );
          }

          final history = ref.watch(netWorthHistoryProvider);
          final change = NetWorthCalculator.changeSinceStart(history);
          final positive = nw.netWorth >= 0;
          final line = positive ? t.accent : t.error;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('NET WORTH', style: AppText.micro(t.textTertiary)),
                  const Spacer(),
                  if (onManageAccounts != null)
                    TextButton(
                      onPressed: onManageAccounts,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Manage'),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              AnimatedCount(
                value: nw.netWorth.abs(),
                formatter: (v) =>
                    '${positive ? '' : '−'}₹${fmt.format(v)}',
                style: AppText.hero(
                  positive ? t.textPrimary : t.error,
                  size: 42,
                ),
              ),
              if (change != null && change != 0) ...[
                const SizedBox(height: Space.md),
                _ChangePill(change: change, fmt: fmt),
              ],
              if (history.length >= 2) ...[
                const SizedBox(height: Space.lg),
                SizedBox(
                  height: 56,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < history.length; i++)
                              FlSpot(i.toDouble(), history[i].value),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.28,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          color: line,
                          // Gradient fade to transparent rather than a flat
                          // translucent slab — the modern chart idiom.
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                line.withOpacity(0.26),
                                line.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: Motion.chart,
                    curve: Motion.smooth,
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              Divider(color: t.borderSubtle, height: 1),
              const SizedBox(height: Space.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NwRow(label: 'Cash & bank', value: nw.cashAssets, fmt: fmt),
                  _NwRow(label: 'Investments', value: nw.investments, fmt: fmt),
                  _NwRow(
                      label: 'Owed',
                      value: -nw.liabilities,
                      fmt: fmt,
                      negative: true),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small pill showing movement since tracking began.
class _ChangePill extends StatelessWidget {
  final double change;
  final NumberFormat fmt;
  const _ChangePill({required this.change, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final up = change > 0;
    final c = up ? t.success : t.error;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.md, vertical: Space.xs + 2),
      decoration: BoxDecoration(
        color: c.withOpacity(t.isDark ? 0.14 : 0.10),
        borderRadius: Radii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 13, color: c),
          const SizedBox(width: Space.xs + 2),
          Text(
            '₹${fmt.format(change.abs())} since tracking started',
            style: AppText.caption(c, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// One column of the net-worth breakdown. Laid out three-up so the composition
/// reads at a glance instead of as three stacked label/value rows.
class _NwRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat fmt;
  final bool negative;
  const _NwRow(
      {required this.label,
      required this.value,
      required this.fmt,
      this.negative = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.micro(t.textTertiary)),
          const SizedBox(height: Space.xs + 2),
          Text(
            '${value < 0 ? '−' : ''}₹${fmt.format(value.abs())}',
            style: AppText.money(
              negative && value != 0 ? t.error : t.textPrimary,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}
