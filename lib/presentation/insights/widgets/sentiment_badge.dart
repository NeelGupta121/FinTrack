import 'package:flutter/material.dart';
import '../../../data/datasources/remote/gemini_ds.dart';
import '../../common/theme/app_theme.dart';

class SentimentBadge extends StatelessWidget {
  final SentimentResult sentiment;
  const SentimentBadge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (sentiment.sentiment) {
      'bullish' => (Icons.arrow_upward, AppTheme.positive),
      'bearish' => (Icons.arrow_downward, AppTheme.negative),
      _ => (Icons.remove, Theme.of(context).colorScheme.onSurfaceVariant),
    };

    return Tooltip(
      message: '${sentiment.sentiment} (${sentiment.score.toStringAsFixed(2)}): ${sentiment.reason}',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
