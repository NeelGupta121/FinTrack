import 'package:flutter/material.dart';
import '../../common/theme/app_theme.dart';
import '../goals_providers.dart';
import '../../../core/utils/currency_formatter.dart';

class GoalCard extends StatelessWidget {
  final FinancialGoal goal;
  final Map<String, dynamic> progress;
  final VoidCallback? onAddFunds;

  const GoalCard({super.key, required this.goal, required this.progress, this.onAddFunds});

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
    final t = context.tokens;
    final onTrack = progress['on_track'] as bool;
    final months = progress['months_needed'] as int;
    final statusColor = months == 0
        ? t.success
        : onTrack
            ? t.success
            : t.warning;
    final statusLabel = months == 0
        ? '🎉 Done!'
        : onTrack
            ? '$months mo left'
            : 'Behind';

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: Radii.brMd,
          border: Border.all(color: t.borderStandard),
          boxShadow: t.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Squircle icon plate
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.panel,
                    borderRadius: Radii.brSm,
                  ),
                  child: Icon(_icon, size: 18, color: t.textSecondary),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    goal.name,
                    style: AppText.cardTitle(t.textPrimary),
                  ),
                ),
                // Status badge
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
                    statusLabel,
                    style: AppText.caption(statusColor, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            // Thin rounded progress meter
            ClipRRect(
              borderRadius: Radii.brPill,
              child: LinearProgressIndicator(
                value: goal.progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: t.panel,
                valueColor: AlwaysStoppedAnimation(t.accent),
              ),
            ),
            const SizedBox(height: Space.md),
            // Tabular money row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${CurrencyFormatter.digits.format(goal.currentAmount)}'
                  ' / ₹${CurrencyFormatter.digits.format(goal.targetAmount)}',
                  style: AppText.money(t.textPrimary, size: 14),
                ),
                Text(
                  '₹${CurrencyFormatter.digits.format(goal.remaining)} left',
                  style: AppText.money(t.textTertiary, size: 14),
                ),
              ],
            ),
            if (onAddFunds != null && goal.progress < 1.0) ...[
              const SizedBox(height: Space.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAddFunds,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add funds'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
