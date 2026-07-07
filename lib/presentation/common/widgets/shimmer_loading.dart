import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

enum ShimmerVariant { card, listTile, chart }

class ShimmerLoading extends StatelessWidget {
  final ShimmerVariant variant;

  const ShimmerLoading({super.key, this.variant = ShimmerVariant.card});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: switch (variant) {
        ShimmerVariant.card => _card(),
        ShimmerVariant.listTile => _listTile(),
        ShimmerVariant.chart => _chart(),
      },
    );
  }

  Widget _box(double w, double h, {double radius = 16}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)));

  Widget _circle(double d) => Container(
      width: d, height: d, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle));

  Widget _card() => Padding(
      padding: const EdgeInsets.all(16), child: _box(double.infinity, 120, radius: 20));

  Widget _listTile() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _circle(44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _box(140, 14),
          const SizedBox(height: 8),
          _box(80, 12),
        ])),
      ]));

  Widget _chart() => Padding(
      padding: const EdgeInsets.all(16), child: _box(double.infinity, 200, radius: 20));
}
