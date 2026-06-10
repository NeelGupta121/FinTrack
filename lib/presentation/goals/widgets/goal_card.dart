import 'package:flutter/material.dart';
import '../goals_providers.dart';

class GoalCard extends StatelessWidget {
  final FinancialGoal goal;
  final Map<String, dynamic> progress;

  const GoalCard({super.key, required this.goal, required this.progress});

  IconData get _icon => switch (goal.type) {
        GoalType.emergency => Icons.shield,
        GoalType.retirement => Icons.elderly,
        GoalType.purchase => Icons.shopping_bag,
        GoalType.travel => Icons.flight,
        GoalType.education => Icons.school,
        GoalType.custom => Icons.flag,
      };

  @override
  Widget build(BuildContext context) {
    final onTrack = progress['on_track'] as bool;
    final months = progress['months_needed'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: onTrack ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    months == 0 ? '🎉 Done!' : onTrack ? '$months mo left' : 'Behind',
                    style: TextStyle(fontSize: 12, color: onTrack ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${goal.currentAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('₹${goal.remaining.toStringAsFixed(0)} left', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
