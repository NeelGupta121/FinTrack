import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_theme.dart';

/// Empty state.
///
/// The previous version was the generic "big circle with a tinted icon"
/// pattern. Two changes: the plate is a squircle matching the app's radius
/// scale rather than a circle, and it sits on a panel fill with a hairline
/// border so it reads as part of the surface system instead of a floating blob.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional second line for context under the headline message.
  final String? detail;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: t.panel,
                  borderRadius: Radii.brLg,
                  border: Border.all(color: t.borderStandard),
                ),
                child: Icon(icon, size: 26, color: t.textTertiary),
              ),
              const SizedBox(height: Space.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.cardTitle(t.textPrimary),
              ),
              if (detail != null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AppText.caption(t.textTertiary),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Space.xl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
