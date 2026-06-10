import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';
import '../common/theme/app_theme.dart';

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
          // Net worth card
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Spent', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  expenses.when(
                    data: (list) {
                      final total = list.where((t) => t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
                      return Text('₹${NumberFormat('#,##0').format(total)}',
                          style: AppTheme.amountStyle(context));
                    },
                    loading: () => Text('₹0', style: AppTheme.amountStyle(context)),
                    error: (_, __) => Text('₹0', style: AppTheme.amountStyle(context)),
                  ),
                  const SizedBox(height: 4),
                  Text('Across all tracked expenses',
                      style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.7))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              _QuickAction(icon: Icons.add, label: 'Expense', onTap: () => context.push('/expenses/add')),
              const SizedBox(width: 12),
              _QuickAction(icon: Icons.camera_alt, label: 'Scan', onTap: () => context.push('/expenses/add')),
              const SizedBox(width: 12),
              _QuickAction(icon: Icons.show_chart, label: 'Holding', onTap: () => context.push('/investments/add')),
            ],
          ),
          const SizedBox(height: 24),

          // Portfolio summary
          Card(
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
          const SizedBox(height: 24),

          // Manage section — links to Bills, Goals, Reports
          Text('Manage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
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
          const SizedBox(height: 24),

          // Recent transactions
          Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          expenses.when(
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
