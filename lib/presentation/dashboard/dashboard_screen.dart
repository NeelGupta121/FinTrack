import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../expenses/expense_providers.dart';
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
                  Text('Net Worth', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  expenses.when(
                    data: (list) {
                      final total = list.fold<double>(0, (sum, t) => sum + t.amount);
                      return Text('₹${NumberFormat('#,##0').format(total)}',
                          style: AppTheme.amountStyle(context));
                    },
                    loading: () => Text('₹0', style: AppTheme.amountStyle(context)),
                    error: (_, __) => Text('₹0', style: AppTheme.amountStyle(context)),
                  ),
                  const SizedBox(height: 4),
                  Text('Total expenses tracked',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PortfolioStat(label: 'Invested', value: '₹0'),
                      _PortfolioStat(label: 'Current', value: '₹0'),
                      _PortfolioStat(label: 'Returns', value: '0%'),
                    ],
                  ),
                ],
              ),
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
            error: (e, _) => Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load: $e'),
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
