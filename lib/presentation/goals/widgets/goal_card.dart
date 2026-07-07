import 'package:flutter/material.dart';
import '../../common/theme/app_theme.dart';
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
    final cs = Theme.of(context).colorScheme;
    final onTrack = progress['on_track'] as bool;
    final months = progress['months_needed'] as int;
    final statusColor = onTrack ? AppTheme.positive : AppTheme.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  child: Icon(_icon, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    months == 0 ? '🎉 Done!' : onTrack ? '$months mo left' : 'Behind',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goal.progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppTheme.positive),
              ),
            ),
            const SizedBox(height: 10),
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
