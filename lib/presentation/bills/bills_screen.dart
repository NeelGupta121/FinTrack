import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import '../../domain/usecases/detect_recurring_bills.dart';
import 'bills_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../common/widgets/category_catalog.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(recurringBillsProvider);
    ref.watch(billReminderProvider); // schedules reminders for upcoming bills (no-op on web)

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
    final t = context.tokens;
    final totalMonthly = bills
        .where((b) => b.frequency == BillFrequency.monthly)
        .fold<double>(0, (sum, b) => sum + b.amount);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.lg,
      ),
      children: [
        FadeSlideIn(index: 0, child: _TotalCard(total: totalMonthly)),
        const SizedBox(height: Space.section),
        if (bills.isNotEmpty)
          FadeSlideIn(
            index: 1,
            child: Container(
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: Radii.brMd,
                border: Border.all(color: t.borderStandard),
                boxShadow: t.cardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < bills.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 60),
                        child: Divider(height: 1, color: t.borderSubtle),
                      ),
                    _BillRow(bill: bills[i]),
                  ],
                ],
              ),
            ),
          ),
        if (bills.isEmpty)
          const FadeSlideIn(
            index: 1,
            child: EmptyState(
              icon: Icons.receipt_long,
              message: 'No recurring bills detected yet.\nAdd more transactions for auto-detection.',
            ),
          ),
        const SizedBox(height: Space.xxl),
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
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        children: [
          Text('MONTHLY RECURRING', style: AppText.micro(t.textTertiary)),
          const SizedBox(height: Space.md),
          Text(
            '₹${CurrencyFormatter.digits.format(total)}',
            style: AppText.money(t.textPrimary, size: 26),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final RecurringBill bill;
  const _BillRow({required this.bill});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final daysUntil = bill.nextDueDate.difference(now).inDays;
    // NOT a payment status: `nextDueDate` is a PREDICTION from observed
    // recurrence, and RecurringBill carries no paid/unpaid record at all. The
    // previous code labelled anything more than 3 days out as 'Paid' in green,
    // which asserted a financial fact the app cannot know — and a bill wrongly
    // shown as settled is exactly the error that causes a missed payment.
    final (statusColor, label) = daysUntil < 0
        ? (t.error, 'Overdue')
        : daysUntil <= 3
            ? (t.warning, 'Due soon')
            : (t.textSecondary, 'Scheduled');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md + 2,
      ),
      child: Row(
        children: [
          // Squircle icon plate
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: Radii.brSm,
            ),
            child: Icon(
              bill.categoryId == null
                  ? Icons.receipt_long
                  : CategoryCatalog.iconFor(bill.categoryId),
              size: 17,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(width: Space.md),
          // Name + amount subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.merchant,
                  style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${CurrencyFormatter.digits.format(bill.amount)} • ${bill.frequency.name}',
                  style: AppText.caption(t.textTertiary),
                ),
              ],
            ),
          ),
          // Status badge + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Status badge per spec
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(t.isDark ? 0.14 : 0.10),
                  borderRadius: Radii.brPill,
                ),
                child: Text(
                  label,
                  style: AppText.caption(statusColor, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                DateFormat('MMM d').format(bill.nextDueDate),
                style: AppText.caption(t.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
