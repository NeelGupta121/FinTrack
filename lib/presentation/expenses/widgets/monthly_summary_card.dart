import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../common/theme/app_theme.dart';
import '../../common/widgets/category_icon.dart';
import '../expense_providers.dart';
import 'category_picker.dart';

class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummary summary;
  const MonthlySummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final remaining = summary.budget - summary.totalSpent;
    final progress = summary.budget > 0
        ? (summary.totalSpent / summary.budget).clamp(0.0, 1.0)
        : 0.0;

    // Top 3 categories by spend.
    final sorted = summary.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
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
            // Header: spent vs remaining.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIS MONTH', style: AppText.micro(t.textTertiary)),
                    const SizedBox(height: Space.xs),
                    Text(
                      fmt.format(summary.totalSpent),
                      style: AppText.money(t.textPrimary, size: 24),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('REMAINING', style: AppText.micro(t.textTertiary)),
                    const SizedBox(height: Space.xs),
                    Text(
                      fmt.format(remaining),
                      style: AppText.money(
                        remaining < 0 ? t.error : t.textPrimary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            // Thin rounded progress meter.
            ClipRRect(
              borderRadius: Radii.brPill,
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: t.panel,
                  color: progress > 0.9 ? t.error : t.accent,
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            // Top 3 category breakdown.
            ...top3.map((entry) {
              final cat = categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => categories.last,
              );
              final catProgress = summary.totalSpent > 0
                  ? (entry.value / summary.totalSpent).clamp(0.0, 1.0)
                  : 0.0;
              final tint = CategoryIcon.colorFor(cat.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Row(
                  children: [
                    CategoryIcon(slug: cat.id, size: 22),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: AppText.caption(t.textSecondary),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: Radii.brPill,
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: catProgress,
                            backgroundColor: t.panel,
                            color: tint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(
                      fmt.format(entry.value),
                      style: AppText.caption(
                        t.textPrimary,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
