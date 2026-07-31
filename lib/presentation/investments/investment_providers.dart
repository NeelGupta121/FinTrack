import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/holding.dart';
import '../../domain/usecases/analyze_portfolio.dart';
import '../../domain/usecases/tax_saving.dart';

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
  double get dayChangePercent {
    final prevClose = currentValue - dayChange;
    return prevClose > 0 ? (dayChange / prevClose) * 100 : 0;
  }
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
    final sparkRaw = LocalDatabase.settings.get('portfolio_sparkline', defaultValue: <double>[]) as List? ?? [];
    final sparkline = sparkRaw.whereType<num>().map((e) => e.toDouble()).toList();

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

/// Annualised money-weighted return (XIRR) for the whole portfolio, expressed
/// as a percentage. Plain P&L% is misleading when purchases happen at different
/// times (SIPs); XIRR is the correct measure. Cashflows: each holding's cost is
/// an outflow on its purchase date, and today's total value is the closing
/// inflow. Returns null when there isn't enough dated data to solve.
final portfolioXirrProvider = FutureProvider.autoDispose<double?>((ref) async {
  try {
    final portfolio = await ref.watch(portfolioValueProvider.future);
    if (portfolio.currentValue <= 0) return null;

    final flows = <InvestmentTransaction>[];
    for (final raw in LocalDatabase.holdings.values) {
      final qty = (raw['quantity'] as num?)?.toDouble() ?? 0;
      final avg = (raw['avg_price'] as num?)?.toDouble() ?? 0;
      final cost = qty * avg;
      if (cost <= 0) continue;
      final bought = DateTime.tryParse(raw['purchase_date'] as String? ?? '');
      if (bought == null) continue; // undated holding can't join an XIRR series
      flows.add(InvestmentTransaction(amount: -cost, date: bought));
    }
    if (flows.isEmpty) return null;

    // Closing position valued today.
    flows.add(InvestmentTransaction(amount: portfolio.currentValue, date: DateTime.now()));

    // Needs at least one buy and a later valuation spanning real time.
    final earliest = flows.map((f) => f.date).reduce((a, b) => a.isBefore(b) ? a : b);
    if (DateTime.now().difference(earliest).inDays < 1) return null;

    final rate = AnalyzePortfolioUseCase().calculateXIRR(flows);
    if (rate == 0) return null; // solver reports 0 for non-convergence
    return rate * 100;
  } catch (e, st) {
    AppLogger.error('Failed to compute portfolio XIRR', tag: 'Investments', error: e, stackTrace: st);
    return null;
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

/// Section 80C progress for the current Indian financial year, summed from
/// holdings flagged as tax-saving. Only contributions dated inside the current
/// FY count toward the ₹1.5L ceiling. Reads the box directly, so writes must
/// invalidate it (see AddHoldingNotifier.add).
final section80cProvider = Provider.autoDispose<Section80CProgress>((ref) {
  final now = DateTime.now();
  double invested = 0;
  var count = 0;
  for (final h in LocalDatabase.holdings.values) {
    if (h['section_80c'] != true) continue;
    final bought = DateTime.tryParse(h['purchase_date'] as String? ?? '');
    if (bought == null || !Section80C.isInCurrentFy(bought, now)) continue;
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    invested += qty * avg;
    count++;
  }
  return Section80CProgress.from(invested: invested, count: count, now: now);
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
    bool section80c = false,
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
      'section_80c': section80c,
    });
    _ref.invalidate(holdingsListProvider);
    _ref.invalidate(portfolioValueProvider);
    _ref.invalidate(portfolioAllocationProvider);
    _ref.invalidate(portfolioXirrProvider);
    _ref.invalidate(section80cProvider);
  }
}
