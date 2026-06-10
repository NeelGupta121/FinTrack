import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/holding.dart';

final holdingsListProvider = FutureProvider.autoDispose<List<Holding>>((ref) async {
  try {
    final items = LocalDatabase.holdings.values.toList()
      ..sort((a, b) => (a['type'] as String? ?? '').compareTo(b['type'] as String? ?? ''));
    return items.map((e) => Holding(
      id: e['id'] as String,
      symbol: (e['symbol'] as String?) ?? '',
      name: (e['name'] as String?) ?? '',
      type: (e['type'] as String?) ?? 'other',
      quantity: (e['quantity'] as num?)?.toDouble() ?? 1.0,
      avgPrice: (e['avg_price'] as num?)?.toDouble() ?? 0.0,
      currency: (e['currency'] as String?) ?? 'INR',
    )).toList();
  } catch (e, st) {
    AppLogger.error('Failed to fetch holdings', tag: 'Investments', error: e, stackTrace: st);
    rethrow;
  }
});

class PortfolioValue {
  final double totalInvested;
  final double currentValue;
  final double dayChange;
  final List<double> sparkline;

  PortfolioValue({required this.totalInvested, required this.currentValue, required this.dayChange, required this.sparkline});

  double get totalPnL => currentValue - totalInvested;
  double get totalPnLPercent => totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0;
  double get dayChangePercent => currentValue > 0 ? (dayChange / (currentValue - dayChange)) * 100 : 0;
}

final portfolioValueProvider = FutureProvider.autoDispose<PortfolioValue>((ref) async {
  try {
    final holdings = await ref.watch(holdingsListProvider.future);
    double totalInvested = 0;
    double currentValue = 0;

    for (final h in holdings) {
      totalInvested += h.investedValue;
      final cached = LocalDatabase.priceCache.get(h.symbol);
      final currentPrice = cached != null ? (cached['price'] as num? ?? 0).toDouble() : h.avgPrice;
      currentValue += h.quantity * currentPrice;
    }

    // Sparkline from settings (stored as list of recent portfolio values)
    final sparkRaw = LocalDatabase.settings.get('portfolio_sparkline', defaultValue: <double>[]) as List;
    final sparkline = sparkRaw.map((e) => (e as num).toDouble()).toList();

    final prevClose = sparkline.length >= 2 ? sparkline[sparkline.length - 2] : currentValue;
    final dayChange = currentValue - prevClose;

    return PortfolioValue(
      totalInvested: totalInvested,
      currentValue: currentValue,
      dayChange: dayChange,
      sparkline: sparkline.isEmpty ? [currentValue] : sparkline,
    );
  } catch (e, st) {
    AppLogger.error('Failed to compute portfolio value', tag: 'Investments', error: e, stackTrace: st);
    rethrow;
  }
});

class AllocationEntry {
  final String type;
  final double value;
  final double percent;
  AllocationEntry({required this.type, required this.value, required this.percent});
}

final portfolioAllocationProvider = FutureProvider.autoDispose<List<AllocationEntry>>((ref) async {
  final holdings = await ref.watch(holdingsListProvider.future);
  final grouped = <String, double>{};
  double total = 0;

  for (final h in holdings) {
    final val = h.investedValue;
    grouped[h.type] = (grouped[h.type] ?? 0) + val;
    total += val;
  }

  return grouped.entries
      .map((e) => AllocationEntry(type: e.key, value: e.value, percent: total > 0 ? (e.value / total) * 100 : 0))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
});

final addHoldingProvider = Provider((ref) => AddHoldingNotifier(ref));

class AddHoldingNotifier {
  final Ref _ref;
  AddHoldingNotifier(this._ref);

  Future<void> add({
    required String symbol,
    required String name,
    required String type,
    required double quantity,
    required double avgPrice,
    required DateTime purchaseDate,
    String? accountId,
  }) async {
    final id = LocalDatabase.newId();
    await LocalDatabase.holdings.put(id, {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type,
      'quantity': quantity,
      'avg_price': avgPrice,
      'currency': 'INR',
      'purchase_date': purchaseDate.toIso8601String(),
      'account_id': accountId,
    });
    _ref.invalidate(holdingsListProvider);
    _ref.invalidate(portfolioValueProvider);
    _ref.invalidate(portfolioAllocationProvider);
  }
}
