import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/holding.dart';

class HoldingCard extends StatelessWidget {
  final Holding holding;
  final double? currentPrice;
  final double? dayChange;
  const HoldingCard({super.key, required this.holding, this.currentPrice, this.dayChange});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final price = currentPrice ?? holding.avgPrice;
    final currentValue = holding.quantity * price;
    final pnl = currentValue - holding.investedValue;
    final pnlPercent = holding.investedValue > 0 ? (pnl / holding.investedValue) * 100 : 0.0;
    final isProfit = pnl >= 0;
    final color = isProfit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holding.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(holding.name, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currFmt.format(currentValue), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${isProfit ? '+' : ''}${currFmt.format(pnl)} (${pnlPercent.toStringAsFixed(1)}%)',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Info(label: 'Qty', value: holding.quantity.toStringAsFixed(holding.quantity == holding.quantity.roundToDouble() ? 0 : 2)),
                _Info(label: 'Avg', value: currFmt.format(holding.avgPrice)),
                _Info(label: 'CMP', value: currFmt.format(price)),
                if (dayChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (dayChange! >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${dayChange! >= 0 ? '+' : ''}${dayChange!.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 10, color: dayChange! >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
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
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
