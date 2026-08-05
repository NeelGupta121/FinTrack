import 'package:flutter/material.dart';

import '../../common/theme/app_theme.dart';
import '../../common/widgets/category_catalog.dart';

/// Re-exported so the five existing importers of this file keep resolving
/// `categories` and `CategoryItem` unchanged. The list itself now lives in
/// `common/widgets/category_catalog.dart` — see that file for why.
export '../../common/widgets/category_catalog.dart';

class CategoryPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const CategoryPicker({super.key, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: Space.md,
        crossAxisSpacing: Space.sm,
        // mainAxisExtent, NOT childAspectRatio: the cell content is a fixed
        // 44px plate plus a two-line label, so its height must be absolute.
        // With childAspectRatio the height scales with cell WIDTH, so on a wide
        // surface (tablet, or the 1200px test viewport) each cell ballooned to
        // ~356px and six rows overflowed the scroll extent, pushing the save
        // button out of the lazily-built range entirely.
        mainAxisExtent: 84,
      ),
      itemCount: categories.length,
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        final isSelected = cat.id == selected;
        final tint = CategoryCatalog.tintFor(cat.id);

        return InkWell(
          onTap: () => onSelected(cat.id),
          borderRadius: Radii.brMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected fills with the tint and inverts the glyph; unselected
              // is a soft tinted plate. Squircle to match the row avatars.
              AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.decelerate,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? tint
                      : tint.withOpacity(t.isDark ? 0.16 : 0.12),
                  borderRadius: Radii.brMd,
                  border: Border.all(
                    color: isSelected
                        ? tint
                        : tint.withOpacity(t.isDark ? 0.22 : 0.18),
                  ),
                ),
                child: Icon(
                  cat.icon,
                  size: 21,
                  color: isSelected ? Colors.white : tint,
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                cat.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(
                  isSelected ? t.textPrimary : t.textTertiary,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ).copyWith(fontSize: 11, height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }
}
