import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/holding.dart';

final holdingsListProvider = FutureProvider.autoDispose<List<Holding>>((ref) async {
  final data = await SupabaseConfig.client
      .from('holdings')
      .select()
      .order('type')
      .order('name');
  return (data as List).map((e) => Holding(
    id: e['id'],
    symbol: e['symbol'] ?? '',
    name: e['name'],
    type: e['type'],
    quantity: (e['quantity'] as num).toDouble(),
    avgPrice: (e['avg_price'] as num).toDouble(),
    currency: e['currency'] ?? 'INR',
  )).toList();
});

class PortfolioValue {
  final double totalInvested;
  final double currentValue;
  final double dayChange;
  final List<double> sparkline; // 7-day values

  PortfolioValue({
    required this.totalInvested,
    required this.currentValue,
    required this.dayChange,
    required this.sparkline,
  });

  double get totalPnL => currentValue - totalInvested;
  double get totalPnLPercent => totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0;
  double get dayChangePercent => currentValue > 0 ? (dayChange / (currentValue - dayChange)) * 100 : 0;
}

final portfolioValueProvider = FutureProvider.autoDispose<PortfolioValue>((ref) async {
  final holdings = await ref.watch(holdingsListProvider.future);
  double totalInvested = 0;
  double currentValue = 0;

  // Fetch current prices from price_cache table
  final symbols = holdings.map((h) => h.symbol).toList();
  final priceData = await SupabaseConfig.client
      .from('price_cache')
      .select()
      .inFilter('symbol', symbols);

  final prices = <String, Map<String, dynamic>>{};
  for (final p in priceData as List) {
    prices[p['symbol']] = p;
  }

  for (final h in holdings) {
    totalInvested += h.investedValue;
    final price = prices[h.symbol];
    final currentPrice = price != null ? (price['price'] as num).toDouble() : h.avgPrice;
    currentValue += h.quantity * currentPrice;
  }

  // Fetch 7-day portfolio history
  final history = await SupabaseConfig.client
      .from('portfolio_snapshots')
      .select('value')
      .order('date', ascending: true)
      .limit(7);
  final sparkline = (history as List).map((e) => (e['value'] as num).toDouble()).toList();

  final prevClose = sparkline.length >= 2 ? sparkline[sparkline.length - 2] : currentValue;
  final dayChange = currentValue - prevClose;

  return PortfolioValue(
    totalInvested: totalInvested,
    currentValue: currentValue,
    dayChange: dayChange,
    sparkline: sparkline.isEmpty ? [currentValue] : sparkline,
  );
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
    await SupabaseConfig.client.from('holdings').insert({
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
