import 'package:flutter/material.dart';
import '../theme/app_animations.dart';

class CategoryIcon extends StatefulWidget {
  final String slug;
  final VoidCallback? onTap;
  final double size;

  const CategoryIcon({super.key, required this.slug, this.onTap, this.size = 40});

  @override
  State<CategoryIcon> createState() => _CategoryIconState();
}

class _CategoryIconState extends State<CategoryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: AppAnimations.fast, upperBound: 0.1);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static final _icons = <String, IconData>{
    'food': Icons.restaurant, 'transport': Icons.directions_car,
    'shopping': Icons.shopping_bag, 'bills': Icons.receipt_long,
    'health': Icons.local_hospital, 'entertainment': Icons.movie,
    'education': Icons.school, 'rent': Icons.home,
    'salary': Icons.account_balance, 'investment': Icons.trending_up,
    'groceries': Icons.local_grocery_store, 'travel': Icons.flight,
  };

  static final _colors = <String, Color>{
    'food': Colors.orange, 'transport': Colors.blue,
    'shopping': Colors.purple, 'bills': Colors.teal,
    'health': Colors.red, 'entertainment': Colors.pink,
    'education': Colors.indigo, 'rent': Colors.brown,
    'salary': Colors.green, 'investment': Colors.amber,
    'groceries': Colors.lightGreen, 'travel': Colors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[widget.slug] ?? Icons.category;
    final color = _colors[widget.slug] ?? Colors.grey;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + _ctrl.value, child: child),
        child: CircleAvatar(
          radius: widget.size / 2,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: widget.size * 0.55),
        ),
      ),
    );
  }
}
