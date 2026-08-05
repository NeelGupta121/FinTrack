import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_theme.dart';
import 'category_catalog.dart';

/// Category avatar.
///
/// Resolves through [CategoryCatalog], which is the single source of truth for
/// category id -> icon -> tint. This widget previously kept its own map keyed on
/// 12 short slugs while transactions store the 23 picker ids, so only 7 of 23
/// resolved and the remaining 16 — `food_delivery` among them — rendered a
/// generic plate. Analyze and the unit suite were both green throughout; the
/// only symptom was visual.
class CategoryIcon extends StatelessWidget {
  final String slug;
  final VoidCallback? onTap;
  final double size;

  const CategoryIcon({
    super.key,
    required this.slug,
    this.onTap,
    this.size = 40,
  });

  static Color colorFor(String slug) => CategoryCatalog.tintFor(slug);

  static IconData iconFor(String slug) => CategoryCatalog.iconFor(slug);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = CategoryCatalog.iconFor(slug);
    final tint = CategoryCatalog.tintFor(slug);

    // Squircle, not a circle: matches the app's radius scale. Circular avatars
    // on every row are a Material-2 holdover.
    final plate = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withOpacity(t.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: tint.withOpacity(t.isDark ? 0.22 : 0.18)),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );

    if (onTap == null) return plate;

    return PressableScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.32),
        child: plate,
      ),
    );
  }
}
