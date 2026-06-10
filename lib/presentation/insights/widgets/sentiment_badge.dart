import 'package:flutter/material.dart';
import '../../../data/datasources/remote/gemini_ds.dart';

class SentimentBadge extends StatelessWidget {
  final SentimentResult sentiment;
  const SentimentBadge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (sentiment.sentiment) {
      'bullish' => (Icons.arrow_upward, Colors.green),
      'bearish' => (Icons.arrow_downward, Colors.red),
      _ => (Icons.remove, Colors.grey),
    };

    return Tooltip(
      message: '${sentiment.sentiment} (${sentiment.score.toStringAsFixed(2)}): ${sentiment.reason}',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
