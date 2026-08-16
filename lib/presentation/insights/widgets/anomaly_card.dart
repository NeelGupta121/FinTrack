import 'package:flutter/material.dart';
import '../../../domain/usecases/analyze_spending.dart';
import '../../common/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../common/widgets/category_catalog.dart';

class AnomalyCard extends StatelessWidget {
  final Anomaly anomaly;
  const AnomalyCard({super.key, required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = anomaly.percentAboveAverage;
    // Two-step severity. The previous ternary had identical `warning` branches
    // for `pct > 50` and the fallback, so the middle test did nothing.
    final color = pct > 100 ? t.error : t.warning;

    // How many times the usual spend this was. Replaces the raw z-score badge:
    // a "22.3σ" label is meaningless to a person managing their money, and the
    // magnitude itself was an artefact of computing a z-score over a handful of
    // samples with almost no variance. A multiple is derived from the same two
    // numbers already on the card, so it is directly checkable by the reader.
    final multiple = anomaly.average > 0 ? anomaly.amount / anomaly.average : 0.0;

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
              child: Icon(CategoryCatalog.iconFor(anomaly.category),
                  size: 18, color: color),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '₹${CurrencyFormatter.digits.format(anomaly.amount)}',
                        style: AppText.money(t.textPrimary),
                      ),
                      Text(
                        ' in ${CategoryCatalog.displayLabel(anomaly.category)}',
                        style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${pct.toStringAsFixed(0)}% above your usual '
                    '₹${CurrencyFormatter.digits.format(anomaly.average)}',
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
                '${multiple.toStringAsFixed(1)}× usual',
                style: AppText.caption(color, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
