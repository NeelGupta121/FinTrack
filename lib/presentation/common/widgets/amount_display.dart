import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animated_counter.dart';

/// A currency or percentage figure.
///
/// Two fixes over the previous version: the gain/loss colours come from the
/// token set instead of raw `Colors.green`/`Colors.red` (which ignored theme
/// brightness and were noticeably harsh on a dark canvas), and the numerals are
/// tabular so a column of amounts lines up on the decimal.
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
    final t = context.tokens;
    final color = value >= 0 ? t.success : t.error;
    final sign = showSign ? (value >= 0 ? '+' : '-') : '';
    final suffix = isPercent ? '%' : '';
    final prefix = isPercent ? '' : '₹';

    final base = style ?? AppText.money(t.textPrimary);
    final resolved = showSign ? base.copyWith(color: color) : base;

    if (!isPercent && value.abs() < 100000) {
      return AnimatedCounter(
        value: value,
        prefix: '$sign$prefix',
        style: resolved,
      );
    }

    return Text('$sign$prefix$_formatted$suffix', style: resolved);
  }
}
