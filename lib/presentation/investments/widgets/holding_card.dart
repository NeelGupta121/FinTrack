import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/holding.dart';
import '../../common/theme/app_theme.dart';

class HoldingCard extends StatelessWidget {
  final Holding holding;
  final double? currentPrice;
  final double? dayChange;
  const HoldingCard({super.key, required this.holding, this.currentPrice, this.dayChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final price = currentPrice ?? holding.avgPrice;
    final currentValue = holding.quantity * price;
    final pnl = currentValue - holding.investedValue;
    final pnlPercent = holding.investedValue > 0 ? (pnl / holding.investedValue) * 100 : 0.0;
    final isProfit = pnl >= 0;
    // Semantic colour: real gain = success, real loss = error.
    final pnlColor = isProfit ? t.success : t.error;

    return Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Squircle icon plate with first letter
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.accentSubtle,
                  borderRadius: Radii.brSm,
                ),
                alignment: Alignment.center,
                child: Text(
                  holding.symbol.isNotEmpty ? holding.symbol[0].toUpperCase() : '?',
                  style: AppText.bodyText(t.accent, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(holding.symbol,
                        style: AppText.bodyText(t.textPrimary, weight: FontWeight.w600)),
                    if (holding.name.isNotEmpty)
                      Text(holding.name,
                          style: AppText.caption(t.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currFmt.format(currentValue),
                      style: AppText.money(t.textPrimary)),
                  const SizedBox(height: Space.xxs),
                  Text(
                    '${isProfit ? '+' : ''}${currFmt.format(pnl)} (${pnlPercent.toStringAsFixed(1)}%)',
                    style: AppText.caption(pnlColor, weight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              _Info(label: 'Qty', value: holding.quantity.toStringAsFixed(holding.quantity == holding.quantity.roundToDouble() ? 0 : 2)),
              _Info(label: 'Avg', value: currFmt.format(holding.avgPrice)),
              _Info(label: 'CMP', value: currFmt.format(price)),
              const Spacer(),
              if (dayChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 3),
                  decoration: BoxDecoration(
                    color: (dayChange! >= 0 ? t.success : t.error).withOpacity(t.isDark ? 0.14 : 0.10),
                    borderRadius: Radii.brPill,
                  ),
                  child: Text(
                    '${dayChange! >= 0 ? '+' : ''}${dayChange!.toStringAsFixed(1)}%',
                    style: AppText.caption(
                      dayChange! >= 0 ? t.success : t.error,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(right: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.micro(t.textTertiary)),
          const SizedBox(height: Space.xxs),
          Text(value, style: AppText.money(t.textPrimary, size: 12)),
        ],
      ),
    );
  }
}
