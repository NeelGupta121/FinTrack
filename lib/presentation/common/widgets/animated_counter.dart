import 'package:flutter/material.dart';
import '../theme/app_animations.dart';

class AnimatedCounter extends StatelessWidget {
  final double value;
  final Duration? duration;
  final String prefix;
  final TextStyle? style;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration,
    this.prefix = '₹',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration ?? AppAnimations.normal,
      curve: AppAnimations.curveSmooth,
      builder: (_, v, __) => Text(
        '$prefix${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}',
        style: style ?? Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
