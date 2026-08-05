import 'package:flutter/material.dart';

import '../../common/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // The user bubble is the one place the accent fills a surface, so its
    // foreground is white. The assistant bubble is a bordered card surface,
    // matching every other container in the app rather than a tinted blob.
    final bg = isUser ? t.accent : t.card;
    final fg = isUser ? Colors.white : t.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(
            vertical: Space.xs + 1, horizontal: Space.gutter),
        padding: const EdgeInsets.symmetric(
            vertical: Space.md, horizontal: Space.lg - 2),
        decoration: BoxDecoration(
          color: bg,
          border: isUser ? null : Border.all(color: t.borderStandard),
          boxShadow: isUser ? null : t.cardShadow,
          // The squared corner marks the speaker side.
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.lg),
            topRight: const Radius.circular(Radii.lg),
            bottomLeft: Radius.circular(isUser ? Radii.lg : Radii.xs),
            bottomRight: Radius.circular(isUser ? Radii.xs : Radii.lg),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Icon(Icons.auto_awesome_rounded, size: 15, color: t.accent),
              const SizedBox(width: Space.sm),
            ],
            Flexible(child: _buildFormattedText(context, text, fg)),
          ],
        ),
      ),
    );
  }

  /// Renders `**bold**` spans inline. Kept verbatim in behaviour — only the
  /// resulting text style is now token-derived.
  Widget _buildFormattedText(BuildContext context, String text, Color color) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
      text: TextSpan(style: AppText.bodyText(color), children: spans),
    );
  }
}
