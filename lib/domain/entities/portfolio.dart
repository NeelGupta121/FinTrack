import 'holding.dart';

/// Aggregated portfolio view.
class Portfolio {
  final List<Holding> holdings;

  const Portfolio({required this.holdings});

  double get totalInvested => holdings.fold(0, (s, h) => s + h.investedValue);

  // TODO: Add currentValue (requires latest prices)
  // TODO: Add pnl, dayChange, allocation breakdown
}
