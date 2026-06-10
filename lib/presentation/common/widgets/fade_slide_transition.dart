import 'package:flutter/material.dart';
import '../theme/app_animations.dart';

enum SlideDirection { up, down, left, right }

class FadeSlideTransition extends StatefulWidget {
  final Duration? delay;
  final SlideDirection direction;
  final Widget child;

  const FadeSlideTransition({
    super.key,
    this.delay,
    this.direction = SlideDirection.up,
    required this.child,
  });

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  Offset get _begin => switch (widget.direction) {
        SlideDirection.up => const Offset(0, 0.15),
        SlideDirection.down => const Offset(0, -0.15),
        SlideDirection.left => const Offset(0.15, 0),
        SlideDirection.right => const Offset(-0.15, 0),
      };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.normal);
    final curved = CurvedAnimation(parent: _ctrl, curve: AppAnimations.curveDefault);
    _slide = Tween(begin: _begin, end: Offset.zero).animate(curved);
    _fade = Tween(begin: 0.0, end: 1.0).animate(curved);
    Future.delayed(widget.delay ?? Duration.zero, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}
