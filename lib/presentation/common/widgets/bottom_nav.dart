import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Floating pill bottom navigation.
///
/// Replaces the stock M3 `NavigationBar`, whose full-width bar with a wide
/// indicator pill is one of the most recognisable "default Flutter" tells.
/// The 2026 convention (Revolut, Copilot, Cleo) is an inset floating container
/// with a pill radius, a hairline border and a soft shadow, so page content
/// scrolls beneath it.
///
/// Deliberately NOT using BackdropFilter for a frosted effect: under CanvasKit
/// each instance costs a saveLayer plus a GPU blur pass every frame, and this
/// widget is permanently on screen. A solid surface at pill radius reads
/// almost identically for a fraction of the cost.
class BottomNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const BottomNav({super.key, required this.shell});

  static const _items = <_NavSpec>[
    _NavSpec(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavSpec(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Expenses'),
    _NavSpec(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Invest'),
    _NavSpec(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: Space.lg,
        right: Space.lg,
        bottom: Space.md + (bottomInset > 0 ? bottomInset * 0.5 : 0),
        top: Space.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.isDark ? t.card : t.card,
          borderRadius: Radii.brPill,
          border: Border.all(color: t.borderStandard),
          boxShadow: t.floatShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.sm, vertical: Space.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavButton(
                    spec: _items[i],
                    selected: shell.currentIndex == i,
                    onTap: () => shell.goBranch(
                      i,
                      initialLocation: i == shell.currentIndex,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavSpec(this.icon, this.activeIcon, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.accent : t.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brPill,
        splashColor: t.accentSubtle,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.decelerate,
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          decoration: BoxDecoration(
            color: selected ? t.accentSubtle : Colors.transparent,
            borderRadius: Radii.brPill,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cross-fades between outlined and filled variants rather than
              // swapping instantly, so selection reads as a state change.
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  selected ? spec.activeIcon : spec.icon,
                  key: ValueKey(selected),
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
