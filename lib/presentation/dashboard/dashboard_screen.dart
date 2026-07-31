import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';
import 'wellness_providers.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import '../common/widgets/wellness_cards.dart';

const _heroAmount = TextStyle(
  fontFamily: 'SpaceGrotesk',
  color: Colors.white,
  fontSize: 34,
  fontWeight: FontWeight.w700,
  letterSpacing: -1,
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Net worth hero card
          FadeSlideIn(
            index: 0,
            child: ShimmerGradientContainer(
              colors: AppTheme.brandGradient.colors,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.seed.withOpacity(0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Total Spent',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  expenses.when(
                    data: (list) {
                      final total = list
                          .where((t) => t.type == 'expense')
                          .fold<double>(0, (sum, t) => sum + t.amount);
                      return AnimatedCount(
                        value: total,
                        formatter: (v) =>
                            '₹${NumberFormat('#,##0').format(v)}',
                        style: _heroAmount,
                      );
                    },
                    loading: () => const Text('₹0', style: _heroAmount),
                    error: (_, __) => const Text('₹0', style: _heroAmount),
                  ),
                  const SizedBox(height: 6),
                  Text('Across all tracked expenses',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // "In My Pocket" — what's actually free to spend for the rest of the month
          const FadeSlideIn(index: 1, child: _SafeToSpendCard()),
          const SizedBox(height: 16),

          // Financial health score (0-100) with factor breakdown
          const FadeSlideIn(index: 2, child: _HealthScoreCard()),
          const SizedBox(height: 16),

          // Quick actions
          FadeSlideIn(
            index: 3,
            child: Row(
              children: [
                _QuickAction(icon: Icons.add, label: 'Expense', onTap: () => context.push('/expenses/add')),
                const SizedBox(width: 12),
                _QuickAction(icon: Icons.camera_alt, label: 'Scan', onTap: () => context.push('/expenses/add?scan=1')),
                const SizedBox(width: 12),
                _QuickAction(icon: Icons.show_chart, label: 'Holding', onTap: () => context.push('/investments/add')),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Portfolio summary
          FadeSlideIn(
            index: 4,
            child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portfolio', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final pv = ref.watch(portfolioValueProvider);
                      return pv.when(
                        data: (p) {
                          final fmt = NumberFormat('#,##0');
                          final returns = p.totalInvested > 0
                              ? ((p.currentValue - p.totalInvested) / p.totalInvested * 100)
                              : 0.0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _PortfolioStat(label: 'Invested', value: '₹${fmt.format(p.totalInvested)}'),
                              _PortfolioStat(label: 'Current', value: '₹${fmt.format(p.currentValue)}'),
                              _PortfolioStat(
                                label: 'Returns',
                                value: '${returns >= 0 ? '+' : ''}${returns.toStringAsFixed(1)}%',
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        ),
                        error: (_, __) => const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PortfolioStat(label: 'Invested', value: '₹0'),
                            _PortfolioStat(label: 'Current', value: '₹0'),
                            _PortfolioStat(label: 'Returns', value: '0%'),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Month-over-month spending bars (hidden when nothing is logged)
          const FadeSlideIn(index: 5, child: SpendingTrendCard()),

          // Manage section — links to Bills, Goals, Reports
          Text('Manage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 5,
            child: Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Bills & Subscriptions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/bills'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Goals'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/goals'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/reports'),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Recent transactions
          Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 6,
            child: expenses.when(
            data: (list) {
              final recent = list.take(5).toList();
              if (recent.isEmpty) {
                return const Card(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No transactions yet')),
                ));
              }
              return Column(
                children: recent.map((t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Icon(Icons.receipt, color: cs.onSecondaryContainer),
                  ),
                  title: Text(t.description ?? t.merchant ?? 'Expense'),
                  subtitle: Text(DateFormat.MMMd().format(t.date)),
                  trailing: Text(
                    '₹${NumberFormat('#,##0').format(t.amount)}',
                    style: AppTheme.amountStyle(context, negative: true),
                  ),
                )).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Something went wrong.'),
            )),
          ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        child: FilledButton.tonal(
          onPressed: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioStat extends StatelessWidget {
  final String label;
  final String value;
  const _PortfolioStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// "In My Pocket": budget left for the rest of the month + a per-day allowance.
/// One number the user can act on at a glance.
class _SafeToSpendCard extends ConsumerWidget {
  const _SafeToSpendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(safeToSpendProvider);
    final fmt = NumberFormat('#,##0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox(
              height: 72, child: Center(child: Text('Safe-to-spend unavailable'))),
          data: (s) {
            final positive = !s.overBudget;
            final accent = positive ? cs.primary : cs.error;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.savings_outlined, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text('Safe to spend',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  positive ? '₹${fmt.format(s.remaining)}' : 'Over budget',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  positive
                      ? '≈ ₹${fmt.format(s.perDay)} per day for the rest of the month'
                      : 'You are ₹${fmt.format(s.overspentBy)} past this month\'s budget',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Financial health score (0-100) with its factor breakdown, so the number is
/// explainable rather than opaque.
class _HealthScoreCard extends ConsumerWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(healthScoreProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox(
              height: 72, child: Center(child: Text('Health score unavailable'))),
          data: (h) {
            // With fewer than two usable signals a number would mislead
            // (it would punish a new user for not having entered data yet).
            if (!h.hasEnoughData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_outline, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('Financial health',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Not enough data yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Your score appears once at least two of these are known:'
                    ' a monthly budget, logged income, and investments.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }
            final colour = h.score >= 65
                ? Colors.green
                : h.score >= 45
                    ? Colors.orange
                    : cs.error;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_outline, size: 18, color: colour),
                    const SizedBox(width: 8),
                    Text('Financial health',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(h.band,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colour, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${h.score}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colour,
                            )),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 2),
                      child: Text('/100', style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: h.score / 100,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colour),
                  ),
                ),
                const SizedBox(height: 12),
                for (final f in h.factors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${f.label} — ${f.detail}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const SizedBox(width: 8),
                        Text('${f.score}/${f.maxScore}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
