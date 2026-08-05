import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import '../common/widgets/empty_state.dart';
import 'expense_providers.dart';
import 'add_expense_screen.dart';
import 'import_statement_screen.dart';
import 'widgets/expense_card.dart';
import 'widgets/monthly_summary_card.dart';
import 'widgets/category_picker.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final expenses = ref.watch(expenseListProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final filter = ref.watch(expenseFilterProvider);
    ref.watch(budgetAlertProvider); // fires >=80% budget alert (no-op on web)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Import statement (PDF)',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportStatementScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expenseListProvider);
          ref.invalidate(monthlySummaryProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Monthly summary
            SliverToBoxAdapter(
              child: summary.when(
                data: (s) => MonthlySummaryCard(summary: s),
                loading: () => const Padding(
                  padding: EdgeInsets.all(Space.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Filter chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Wrap(spacing: Space.sm, children: [
                  FilterChip(
                    label: Text(switch (filter.type) {
                      'income' => 'Income',
                      'all' => 'All types',
                      _ => 'Expenses',
                    }),
                    selected: filter.type != 'expense',
                    onSelected: (_) => _showTypeFilter(context, ref),
                  ),
                  FilterChip(
                    label: Text(filter.categoryId != null
                        ? categories
                            .firstWhere(
                              (c) => c.id == filter.categoryId,
                              orElse: () => categories.last,
                            )
                            .label
                        : 'Category'),
                    selected: filter.categoryId != null,
                    onSelected: (_) => _showCategoryFilter(context, ref),
                  ),
                  FilterChip(
                    label: Text(filter.startDate != null
                        ? DateFormat('d MMM').format(filter.startDate!)
                        : 'Date'),
                    selected: filter.startDate != null,
                    onSelected: (_) => _showDateFilter(context, ref),
                  ),
                  if (filter.categoryId != null ||
                      filter.startDate != null ||
                      filter.type != 'expense')
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () => ref
                          .read(expenseFilterProvider.notifier)
                          .state = const ExpenseFilter(),
                    ),
                ]),
              ),
            ),
            // Expense list grouped by date
            expenses.when(
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.receipt_long,
                      message: 'Add your first expense',
                      actionLabel: 'Add Expense',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddExpenseScreen(),
                        ),
                      ),
                    ),
                  );
                }
                final grouped = <String, List<dynamic>>{};
                for (final txn in items) {
                  final key = DateFormat('d MMMM yyyy').format(txn.date);
                  grouped.putIfAbsent(key, () => []).add(txn);
                }
                final sections = grouped.entries.toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final section = sections[i];
                      return FadeSlideIn(
                        index: i,
                        child: Padding(
                          // Nav shell bottom clearance — floating pill + FAB.
                          padding: EdgeInsets.only(
                            bottom: i == sections.length - 1 ? 136 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.gutter,
                                  Space.lg,
                                  Space.gutter,
                                  Space.xs,
                                ),
                                child: Text(
                                  section.key.toUpperCase(),
                                  style: AppText.micro(t.textTertiary),
                                ),
                              ),
                              ...section.value.map(
                                (txn) => _DismissibleRow(
                                  transaction: txn,
                                  ref: ref,
                                  context: context,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: sections.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SliverFillRemaining(
                child: Center(
                  child: Text('Something went wrong. Pull down to retry.'),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTypeFilter(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in const [
              ['expense', 'Expenses'],
              ['income', 'Income'],
              ['all', 'All types'],
            ])
              ListTile(
                title: Text(opt[1]),
                trailing: ref.read(expenseFilterProvider).type == opt[0]
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref.read(expenseFilterProvider.notifier).state =
                      ref.read(expenseFilterProvider).copyWith(type: opt[0]);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: CategoryPicker(
          selected: ref.read(expenseFilterProvider).categoryId,
          onSelected: (id) {
            ref.read(expenseFilterProvider.notifier).state =
                ref.read(expenseFilterProvider).copyWith(categoryId: id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showDateFilter(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      ref.read(expenseFilterProvider.notifier).state =
          ref.read(expenseFilterProvider).copyWith(
                startDate: range.start,
                endDate: range.end,
              );
    }
  }
}

/// Swipe-to-delete row with a rounded error-tinted background.
class _DismissibleRow extends StatelessWidget {
  final dynamic transaction;
  final WidgetRef ref;
  final BuildContext context;

  const _DismissibleRow({
    required this.transaction,
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    final t = outerContext.tokens;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          color: t.error.withOpacity(t.isDark ? 0.16 : 0.10),
          borderRadius: Radii.brMd,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: Icon(Icons.delete_outline_rounded, color: t.error),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed =
            await ref.read(addExpenseProvider).delete(transaction.id);
        if (removed == null) return;
        // On-device storage with no cloud backup —
        // a mis-swipe must be recoverable.
        messenger.showSnackBar(SnackBar(
          content: Text(
            'Deleted ₹${transaction.amount.toStringAsFixed(0)}',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(addExpenseProvider).restore(removed),
          ),
        ));
      },
      // Tap to edit in place — a manual-entry app
      // needs a way to fix a typo.
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddExpenseScreen(existing: transaction),
          ),
        ),
        child: ExpenseCard(transaction: transaction),
      ),
    );
  }
}
