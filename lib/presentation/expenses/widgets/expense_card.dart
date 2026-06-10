import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/transaction.dart';
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
    final cat = _category;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cat.color.withOpacity(0.15),
        child: Icon(cat.icon, color: cat.color, size: 20),
      ),
      title: Text(
        transaction.merchant ?? transaction.description ?? cat.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(DateFormat('d MMM').format(transaction.date), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          _SourceBadge(source: transaction.source),
        ],
      ),
      trailing: Text(
        currencyFmt.format(transaction.amount),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'sms' => ('SMS', Colors.blue),
      'ocr' => ('OCR', Colors.orange),
      _ => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
