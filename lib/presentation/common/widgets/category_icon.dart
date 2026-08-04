import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_theme.dart';

/// Category avatar.
///
/// The previous version mapped each category to a different saturated Material
/// colour (orange / blue / purple / teal / red / pink / indigo / brown / green /
/// amber / lightGreen / cyan). Twelve competing hues is the single loudest
/// "default template" signal in the app, and it sat entirely outside theme
/// control.
///
/// Categories still need to be distinguishable at a glance, so rather than
/// flattening everything to one colour this maps each slug to a fixed index in
/// the two-hue [AppTokens.chartRamp]. Tints of indigo and emerald stay
/// differentiable while reading as one deliberate system.
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

  static const _icons = <String, IconData>{
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_car_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'bills': Icons.receipt_long_rounded,
    'health': Icons.favorite_rounded,
    'entertainment': Icons.movie_rounded,
    'education': Icons.school_rounded,
    'rent': Icons.home_rounded,
    'salary': Icons.account_balance_rounded,
    'investment': Icons.trending_up_rounded,
    'groceries': Icons.local_grocery_store_rounded,
    'travel': Icons.flight_rounded,
  };

  /// Stable slug -> ramp index. Fixed rather than hash-derived so a category
  /// keeps the same colour across builds.
  static const _rampIndex = <String, int>{
    'food': 0,
    'transport': 2,
    'shopping': 4,
    'bills': 6,
    'health': 1,
    'entertainment': 3,
    'education': 5,
    'rent': 7,
    'salary': 1,
    'investment': 0,
    'groceries': 3,
    'travel': 2,
  };

  static Color colorFor(String slug) {
    final i = _rampIndex[slug];
    if (i == null) return AppTokens.chartRamp[6];
    return AppTokens.chartRamp[i % AppTokens.chartRamp.length];
  }

  static IconData iconFor(String slug) =>
      _icons[slug] ?? Icons.category_rounded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = iconFor(slug);
    final tint = colorFor(slug);

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
