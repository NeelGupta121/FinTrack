import 'package:flutter/material.dart';
import '../../../domain/usecases/analyze_spending.dart';
import '../../common/theme/app_theme.dart';

class AnomalyCard extends StatelessWidget {
  final Anomaly anomaly;
  const AnomalyCard({super.key, required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = anomaly.percentAboveAverage;
    final color = pct > 100
        ? t.error
        : pct > 50
            ? t.warning
            : t.warning;

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
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(t.isDark ? 0.14 : 0.10),
                borderRadius: Radii.brSm,
              ),
              child: Icon(_categoryIcon(anomaly.category), size: 18, color: color),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '₹${anomaly.amount.toStringAsFixed(0)}',
                        style: AppText.money(t.textPrimary),
                      ),
                      Text(
                        ' in ${anomaly.category}',
                        style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${pct.toStringAsFixed(0)}% above average (₹${anomaly.average.toStringAsFixed(0)})',
                    style: AppText.caption(t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(t.isDark ? 0.14 : 0.10),
                borderRadius: Radii.brPill,
              ),
              child: Text(
                '${anomaly.zScore.toStringAsFixed(1)}σ',
                style: AppText.caption(color, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    const map = {
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'shopping': Icons.shopping_bag,
      'bills': Icons.receipt_long,
      'entertainment': Icons.movie,
      'health': Icons.local_hospital,
    };
    return map[category.toLowerCase()] ?? Icons.category;
  }
}
