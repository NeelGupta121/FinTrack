import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_animations.dart';
import '../../domain/usecases/detect_recurring_bills.dart';
import 'bills_providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(recurringBillsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bills & Subscriptions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBillDialog(context),
        child: const Icon(Icons.add),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Something went wrong. Pull down to retry.')),
        data: (bills) => _buildContent(context, bills),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<RecurringBill> bills) {
    final totalMonthly = bills
        .where((b) => b.frequency == BillFrequency.monthly)
        .fold<double>(0, (sum, b) => sum + b.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(index: 0, child: _TotalCard(total: totalMonthly)),
        const SizedBox(height: 16),
        ...bills.asMap().entries.map((e) => FadeSlideIn(
              index: (e.key + 1) < 6 ? e.key + 1 : 6,
              child: PressableScale(scale: 0.97, child: _BillTile(bill: e.value)),
            )),
        if (bills.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long,
            message: 'No recurring bills detected yet.\nAdd more transactions for auto-detection.',
          ),
      ],
    );
  }

  void _showAddBillDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Bill'),
        content: const Text('Manual bill entry coming soon.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Monthly Recurring', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('₹${total.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final RecurringBill bill;
  const _BillTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysUntil = bill.nextDueDate.difference(now).inDays;
    final (color, label) = daysUntil < 0
        ? (Colors.red, 'Overdue')
        : daysUntil <= 3
            ? (Colors.orange, 'Upcoming')
            : (Colors.green, 'Paid');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.receipt_long, color: color),
        ),
        title: Text(bill.merchant),
        subtitle: Text('₹${bill.amount.toStringAsFixed(0)} • ${bill.frequency.name}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Text(DateFormat('MMM d').format(bill.nextDueDate), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
