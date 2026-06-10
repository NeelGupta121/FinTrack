import 'package:flutter/material.dart';
import 'animated_counter.dart';

class AmountDisplay extends StatelessWidget {
  final double value;
  final bool showSign;
  final bool isPercent;
  final TextStyle? style;

  const AmountDisplay({
    super.key,
    required this.value,
    this.showSign = false,
    this.isPercent = false,
    this.style,
  });

  String get _formatted {
    final abs = value.abs();
    if (abs >= 10000000) return '${(abs / 10000000).toStringAsFixed(1)}Cr';
    if (abs >= 100000) return '${(abs / 100000).toStringAsFixed(1)}L';
    return abs.toStringAsFixed(abs.truncateToDouble() == abs ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final color = value >= 0 ? Colors.green : Colors.red;
    final sign = showSign ? (value >= 0 ? '+' : '-') : '';
    final suffix = isPercent ? '%' : '';
    final prefix = isPercent ? '' : '₹';

    if (!isPercent && value.abs() < 100000) {
      return AnimatedCounter(
        value: value,
        prefix: '$sign$prefix',
        style: (style ?? Theme.of(context).textTheme.titleMedium)
            ?.copyWith(color: showSign ? color : null),
      );
    }

    return Text(
      '$sign$prefix$_formatted$suffix',
      style: (style ?? Theme.of(context).textTheme.titleMedium)
          ?.copyWith(color: showSign ? color : null),
    );
  }
}
