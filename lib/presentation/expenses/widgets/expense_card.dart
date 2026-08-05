import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/transaction.dart';
import '../../common/theme/app_theme.dart';
import '../../common/widgets/category_icon.dart';
import 'category_picker.dart';

class ExpenseCard extends StatelessWidget {
  final Transaction transaction;
  const ExpenseCard({super.key, required this.transaction});

  CategoryItem get _category => categories.firstWhere(
        (c) => c.id == transaction.categoryId,
        orElse: () => categories.last,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cat = _category;
    final currencyFmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final isIncome = transaction.type == 'income';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          // Squircle category plate via the shared CategoryIcon widget.
          CategoryIcon(slug: cat.id, size: 36),
          const SizedBox(width: Space.md),
          // Title + date stacked.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant ??
                      transaction.description ??
                      cat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyText(
                    t.textPrimary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM').format(transaction.date),
                      style: AppText.caption(t.textTertiary),
                    ),
                    _SourceBadge(source: transaction.source),
                  ],
                ),
              ],
            ),
          ),
          // Amount — tabular via AppText.money.
          Text(
            '${isIncome ? '+' : ''}${currencyFmt.format(transaction.amount)}',
            style: AppText.money(
              isIncome ? t.success : t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle inline badge for imported/OCR transactions.
class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (label, tint) = switch (source) {
      'ocr' => ('OCR', t.warning),
      'import' => ('Imported', t.accent),
      _ => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: Space.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xs + 2,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: tint.withOpacity(t.isDark ? 0.14 : 0.10),
          borderRadius: Radii.brXs,
        ),
        child: Text(
          label,
          style: AppText.micro(tint),
        ),
      ),
    );
  }
}
