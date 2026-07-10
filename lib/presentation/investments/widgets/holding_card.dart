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
    final cs = Theme.of(context).colorScheme;
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final price = currentPrice ?? holding.avgPrice;
    final currentValue = holding.quantity * price;
    final pnl = currentValue - holding.investedValue;
    final pnlPercent = holding.investedValue > 0 ? (pnl / holding.investedValue) * 100 : 0.0;
    final isProfit = pnl >= 0;
    final color = isProfit ? AppTheme.positive : AppTheme.negative;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  child: Text(
                    holding.symbol.isNotEmpty ? holding.symbol[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holding.symbol, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(holding.name,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currFmt.format(currentValue), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${isProfit ? '+' : ''}${currFmt.format(pnl)} (${pnlPercent.toStringAsFixed(1)}%)',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Info(label: 'Qty', value: holding.quantity.toStringAsFixed(holding.quantity == holding.quantity.roundToDouble() ? 0 : 2)),
                _Info(label: 'Avg', value: currFmt.format(holding.avgPrice)),
                _Info(label: 'CMP', value: currFmt.format(price)),
                const Spacer(),
                if (dayChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (dayChange! >= 0 ? AppTheme.positive : AppTheme.negative).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${dayChange! >= 0 ? '+' : ''}${dayChange!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: dayChange! >= 0 ? AppTheme.positive : AppTheme.negative,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
