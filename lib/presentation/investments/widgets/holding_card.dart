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
    // Zero is not a gain. `pnl >= 0` painted a flat holding (a PPF at cost, a
    // just-bought position) green with a '+' prefix, implying a profit that
    // does not exist. Three-way: real gain, real loss, or neutral.
    final isFlat = pnl == 0;
    final isProfit = pnl > 0;
    // Semantic colour: real gain = success, real loss = error, flat = neutral.
    final pnlColor = _signColor(t, pnl);
    final pnlSign = isFlat ? '' : (isProfit ? '+' : '');

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
                    '$pnlSign${currFmt.format(pnl)} (${pnlPercent.toStringAsFixed(1)}%)',
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
                    color: _signColor(t, dayChange!)
                        .withOpacity(t.isDark ? 0.14 : 0.10),
                    borderRadius: Radii.brPill,
                  ),
                  child: Text(
                    '${dayChange! > 0 ? '+' : ''}${dayChange!.toStringAsFixed(1)}%',
                    style: AppText.caption(
                      _signColor(t, dayChange!),
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

/// Gain / loss / flat. Zero must read neutral -- never as a gain -- so a
/// holding sitting exactly at cost does not display a phantom profit.
/// Top-level so every widget in this file shares one rule.
Color _signColor(AppTokens t, double v) =>
    v > 0 ? t.success : (v < 0 ? t.error : t.textSecondary);
