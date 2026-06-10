import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract class AppAnimations {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);

  static const curveDefault = Curves.easeOut;
  static const curveSmooth = Curves.easeInOut;
  static const curveBounce = Curves.bounceOut;

  static Duration staggerDelay(int index) =>
      Duration(milliseconds: 50 * index);

  static CustomTransitionPage<void> fadeSlideTransition(
      GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: curveDefault));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
