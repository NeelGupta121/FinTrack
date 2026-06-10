import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/empty_state.dart';
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) => goals.isEmpty
            ? EmptyState(
                icon: Icons.flag,
                message: 'Set your first financial goal',
                actionLabel: 'Add Goal',
                onAction: () => _showAddGoalSheet(context, ref),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: goals.length,
                itemBuilder: (_, i) {
                  final goal = goals[i];
                  final progress = ref.watch(goalProgressProvider(goal));
                  return GoalCard(goal: goal, progress: progress);
                },
              ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var selectedType = GoalType.custom;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New Goal', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal name')),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target amount (₹)', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GoalType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: GoalType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => selectedType = v!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                    await ref.read(addGoalProvider({
                      'name': nameCtrl.text,
                      'type': selectedType.name,
                      'target_amount': double.tryParse(amountCtrl.text) ?? 0,
                      'current_amount': 0,
                    }).future);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Create Goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
