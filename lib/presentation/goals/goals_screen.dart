import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import 'goals_providers.dart';
import 'widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Something went wrong. Pull down to retry.')),
        data: (goals) => goals.isEmpty
            ? EmptyState(
                icon: Icons.flag,
                message: 'Set your first financial goal',
                actionLabel: 'Add Goal',
                onAction: () => _showAddGoalSheet(context, ref),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.gutter,
                  vertical: Space.lg,
                ),
                itemCount: goals.length,
                itemBuilder: (_, i) {
                  final goal = goals[i];
                  final progress = ref.watch(goalProgressProvider(goal));
                  return FadeSlideIn(
                    index: i < 6 ? i : 6,
                    child: PressableScale(
                      scale: 0.97,
                      child: GoalCard(
                        goal: goal,
                        progress: progress,
                        onAddFunds: () => _showAddFundsDialog(context, ref, goal),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, WidgetRef ref, FinancialGoal goal) {
    final messenger = ScaffoldMessenger.of(context);
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add funds to ${goal.name}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Enter an amount greater than 0')),
                );
                return;
              }
              Navigator.pop(ctx);
              await ref.read(addFundsProvider((goalId: goal.id, amount: amount)).future);
              messenger.showSnackBar(
                SnackBar(content: Text('Added ₹${amount.toStringAsFixed(0)} to ${goal.name}')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(amountCtrl.dispose);
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var selectedType = GoalType.custom;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final t = ctx.tokens;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              MediaQuery.of(ctx).viewInsets.bottom + Space.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sheet handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderStandard,
                      borderRadius: Radii.brPill,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text(
                  'New Goal',
                  style: AppText.section(t.textPrimary, size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Goal name'),
                ),
                const SizedBox(height: Space.lg),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target amount (₹)',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: Space.lg),
                DropdownButtonFormField<GoalType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: GoalType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (nameCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Enter a name and a target amount greater than 0')),
                      );
                      return;
                    }
                    await ref.read(addGoalProvider({
                      'name': nameCtrl.text.trim(),
                      'type': selectedType.name,
                      'target_amount': amount,
                      'current_amount': 0,
                    }).future);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Goal'),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }
}
