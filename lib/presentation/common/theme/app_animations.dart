import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_tokens.dart';

/// Motion for the 2026 refresh.
///
/// Durations and curves come from [Motion] in app_tokens.dart. The headline
/// change is the easing: `Cubic(0.16, 1, 0.3, 1)` (Linear's decelerate) instead
/// of `Curves.easeOut`. It travels most of its distance immediately then settles
/// — motion you feel rather than watch.
///
/// `curveBounce` is retained for API compatibility but deliberately no longer
/// bounces: elastic overshoot on a monetary figure reads as toy-like, which is
/// a documented anti-pattern in every serious finance product.
abstract class AppAnimations {
  static const Duration fast = Motion.fast;
  static const Duration normal = Motion.entrance;
  static const Duration slow = Motion.count;

  static const Curve curveDefault = Motion.decelerate;
  static const Curve curveSmooth = Motion.smooth;
  static const Curve curveBounce = Motion.emphasized;

  static Duration staggerDelay(int index) => Motion.stagger(index);

  /// Route transition: fade + a short rise, no horizontal slide. Matches the
  /// shared-axis feel without pulling in the `animations` package.
  static CustomTransitionPage<void> fadeSlideTransition(
      GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: Motion.route,
      reverseTransitionDuration: Motion.normal,
      child: child,
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Motion.decelerate);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// One-shot entrance: fades in while rising ~10px. Pass an [index] to stagger
/// a column (40ms per item, capped at 12 items so long lists stay snappy).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = Motion.entrance,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Motion.decelerate);
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _c, curve: Motion.decelerate));

  @override
  void initState() {
    super.initState();
    // Only schedule a timer when there is an actual stagger to wait for.
    // A zero-duration Future.delayed still allocates a real timer, which
    // leaves flutter_test with a pending-timer failure and costs one timer
    // per entrance animation at index 0 (of which there are many).
    final delay = Motion.stagger(widget.index);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
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

/// Counts a number up on first build, formatting each frame via [formatter].
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
    this.duration = Motion.count,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Motion.decelerate,
        builder: (_, v, __) => Text(formatter(v), style: style),
      );
}

/// Scales [child] down slightly while pressed. Uses a pass-through [Listener]
/// so an inner button still gets its own tap and ripple.
///
/// Default scale moved 0.94 -> 0.97: a subtler press is the current convention
/// (Copilot, Arc) and 0.94 on a large card reads as rubbery.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const PressableScale({super.key, required this.child, this.scale = 0.97});

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
          duration: Motion.tap,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Hero surface with a slowly drifting gradient.
///
/// The drift period is long (14s) and the travel small, so it reads as a
/// living surface rather than an animation. Previously 6s, which was
/// perceptible enough to be distracting on a balance figure.
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
    this.padding = const EdgeInsets.all(Space.xl),
    this.borderRadius = Radii.brXl,
    this.boxShadow,
    this.period = const Duration(seconds: 14),
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
                begin:
                    Alignment.lerp(Alignment.topLeft, Alignment.topCenter, t)!,
                end: Alignment.lerp(
                    Alignment.bottomRight, Alignment.bottomCenter, t)!,
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

/// Ambient depth: two soft off-screen radial washes behind content.
///
/// Cheap on Flutter web (plain gradient fills, no saveLayer) and gives a dark
/// canvas atmosphere without resorting to BackdropFilter, which costs 2-4ms
/// per frame per instance under CanvasKit.
class AmbientGlow extends StatelessWidget {
  final Widget child;
  final Color? primary;
  final Color? secondary;
  final double opacity;
  const AmbientGlow({
    super.key,
    required this.child,
    this.primary,
    this.secondary,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Both washes stay inside the accent family. An earlier version used the
    // success green for the second wash, which produced a visible green tint on
    // the right edge of a near-black canvas — it read as a rendering artifact
    // rather than as atmosphere.
    final a = (primary ?? t.accent).withOpacity(t.isDark ? 0.14 : 0.06);
    final b = (secondary ?? t.accentHover).withOpacity(t.isDark ? 0.07 : 0.035);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.9, -0.85),
                    radius: 1.1,
                    colors: [a, Colors.transparent],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1.0, -0.35),
                      radius: 0.9,
                      colors: [b, Colors.transparent],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
