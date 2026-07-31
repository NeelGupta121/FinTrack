import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/holding.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/price_sync_service.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_animations.dart';
import 'investment_providers.dart';
import 'add_holding_screen.dart';
import 'widgets/portfolio_value_card.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';

class HoldingsListScreen extends ConsumerStatefulWidget {
  const HoldingsListScreen({super.key});

  @override
  ConsumerState<HoldingsListScreen> createState() => _HoldingsListScreenState();
}

class _HoldingsListScreenState extends ConsumerState<HoldingsListScreen>
    with WidgetsBindingObserver {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-sync once the first frame is up (throttled to ~once/day).
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app after a day away should refresh prices too.
    if (state == AppLifecycleState.resumed) _autoSync();
  }

  /// Throttled auto-refresh: only fetches when the last sync is stale, so
  /// opening the tab repeatedly doesn't spam the market-data APIs.
  Future<void> _autoSync() async {
    if (!mounted || _syncing) return;
    if (ref.read(priceSyncServiceProvider).shouldAutoSync()) {
      await _refresh(showMessage: false);
    }
  }

  /// Fetch live prices/NAVs, then rebuild the portfolio views from the fresh
  /// cache. Shows a status snackbar summarising what happened.
  Future<void> _refresh({bool showMessage = true}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    PriceSyncResult? result;
    try {
      result = await ref.read(priceSyncServiceProvider).syncNow();
    } catch (_) {
      // syncNow isolates per-symbol errors; a throw here is unexpected/global.
    } finally {
      // Recompute holdings/value/allocation from the (now updated) cache.
      ref.invalidate(holdingsListProvider);
      ref.invalidate(portfolioValueProvider);
      ref.invalidate(portfolioAllocationProvider);
      if (mounted) setState(() => _syncing = false);
    }

    if (!mounted || !showMessage) return;
    final r = result;
    final String msg;
    if (r == null || !r.didAnything) {
      msg = 'No holdings to update yet.';
    } else if (r.updated == 0 && r.skipped > 0 && r.failed == 0) {
      msg = 'Nothing to update — ${r.skipped} holding(s) need a market data source/API key.';
    } else {
      final parts = <String>['Updated ${r.updated} price${r.updated == 1 ? '' : 's'}'];
      if (r.failed > 0) parts.add('${r.failed} failed');
      if (r.skipped > 0) parts.add('${r.skipped} skipped');
      msg = parts.join(' · ');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(holdingsListProvider);
    final portfolioAsync = ref.watch(portfolioValueProvider);
    final allocationAsync = ref.watch(portfolioAllocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
        actions: [
          _syncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              : IconButton(
                  tooltip: 'Refresh prices',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHoldingScreen())),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(showMessage: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              index: 0,
              child: portfolioAsync.when(
                data: (pv) => PortfolioValueCard(
                  portfolio: pv,
                  xirr: ref.watch(portfolioXirrProvider).valueOrNull,
                ),
                loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const Text('Something went wrong. Pull down to retry.'),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 1,
              child: allocationAsync.when(
                data: (entries) => entries.isEmpty ? const SizedBox.shrink() : AllocationChart(entries: entries),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
            holdingsAsync.when(
              data: (holdings) => holdings.isEmpty
                  ? EmptyState(
                      icon: Icons.trending_up,
                      message: 'Track your first investment',
                      actionLabel: 'Add Holding',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHoldingScreen())),
                    )
                  : _HoldingsGrouped(holdings: holdings),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Something went wrong. Pull down to retry.')),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingsGrouped extends StatelessWidget {
  final List<Holding> holdings;
  const _HoldingsGrouped({required this.holdings});

  static const _typeLabels = {
    'stock': 'Stocks',
    'mutual_fund': 'Mutual Funds',
    'etf': 'ETFs',
    'bond': 'Bonds',
    'gold': 'Gold',
  };

  /// Latest cached market price for a holding, or null if we've never fetched
  /// one (the card then falls back to the average buy price).
  double? _cachedPrice(String symbol) {
    final cached = LocalDatabase.priceCache.get(symbol);
    final p = cached != null ? (cached['price'] as num?)?.toDouble() : null;
    return (p != null && p > 0) ? p : null;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Holding>>{};
    for (final h in holdings) {
      (grouped[h.type] ??= []).add(h);
    }

    final children = <Widget>[];
    var i = 0;
    grouped.forEach((type, list) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _typeLabels[type] ?? type.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ));
      for (final h in list) {
        // Cap the stagger window so long lists don't accumulate huge delays.
        children.add(FadeSlideIn(
          index: i < 6 ? i : 6,
          child: PressableScale(
            scale: 0.97,
            child: HoldingCard(holding: h, currentPrice: _cachedPrice(h.symbol)),
          ),
        ));
        i++;
      }
      children.add(const SizedBox(height: 8));
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
