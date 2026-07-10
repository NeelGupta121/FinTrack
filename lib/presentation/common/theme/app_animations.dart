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

/// One-shot entrance animation: fades in while sliding up a few px.
/// Pass an [index] to stagger a column of items (50ms * index).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppAnimations.normal,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(AppAnimations.staggerDelay(widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Animates a number counting up from 0 to [value] on first build, formatting
/// each frame via [formatter]. Used for the dashboard hero amount.
class AnimatedCount extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  const AnimatedCount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(formatter(v), style: style),
      );
}

/// Wraps [child] so it scales down slightly while pressed, for tactile
/// feedback. Uses a [Listener] (pass-through) so an inner button still
/// receives its own tap + ripple — this is purely a visual affordance.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const PressableScale({super.key, required this.child, this.scale = 0.94});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// A hero surface whose gradient slowly drifts for a subtle "living" sheen.
/// The gradient direction lerps back and forth over [period]; low-cost enough
/// for a single hero card.
class ShimmerGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;
  final Duration period;
  const ShimmerGradientContainer({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.all(22),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.boxShadow,
    this.period = const Duration(seconds: 6),
  });

  @override
  State<ShimmerGradientContainer> createState() =>
      _ShimmerGradientContainerState();
}

class _ShimmerGradientContainerState extends State<ShimmerGradientContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.lerp(
                    Alignment.topLeft, Alignment.topRight, t)!,
                end: Alignment.lerp(
                    Alignment.bottomRight, Alignment.bottomLeft, t)!,
                colors: widget.colors,
              ),
              borderRadius: widget.borderRadius,
              boxShadow: widget.boxShadow,
            ),
            child: child,
          );
        },
      );
}
