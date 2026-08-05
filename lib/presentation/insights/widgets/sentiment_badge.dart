import 'package:flutter/material.dart';
import '../../../data/datasources/remote/gemini_ds.dart';
import '../../common/theme/app_theme.dart';

class SentimentBadge extends StatelessWidget {
  final SentimentResult sentiment;
  const SentimentBadge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, color, label) = switch (sentiment.sentiment) {
      'bullish' => (Icons.arrow_upward, t.success, 'Bullish'),
      'bearish' => (Icons.arrow_downward, t.error, 'Bearish'),
      _ => (Icons.remove, t.textTertiary, 'Neutral'),
    };

    return Tooltip(
      message: '${sentiment.sentiment} (${sentiment.score.toStringAsFixed(2)}): ${sentiment.reason}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(t.isDark ? 0.14 : 0.10),
          borderRadius: Radii.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: Space.xs),
            Text(label, style: AppText.caption(color, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
