import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/holding.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/price_sync_service.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import 'investment_providers.dart';
import 'add_holding_screen.dart';
import 'widgets/portfolio_value_card.dart';
import '../common/widgets/wellness_cards.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';
import 'package:intl/intl.dart';

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
    final t = context.tokens;
    final holdingsAsync = ref.watch(holdingsListProvider);
    final portfolioAsync = ref.watch(portfolioValueProvider);
    final allocationAsync = ref.watch(portfolioAllocationProvider);

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        title: const Text('Investments'),
        actions: [
          _syncing
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
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
          // Bottom padding 136: nav-shell screen — floating pill nav overlays bottom.
          padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.lg, Space.gutter, 136,
          ),
          children: [
            FadeSlideIn(
              index: 0,
              child: portfolioAsync.when(
                data: (pv) => Column(
                  children: [
                    PortfolioValueCard(
                      portfolio: pv,
                      xirr: ref.watch(portfolioXirrProvider).valueOrNull,
                    ),
                    const SizedBox(height: Space.md),
                    const Section80CCard(),
                  ],
                ),
                loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => Text('Something went wrong. Pull down to retry.',
                    style: AppText.caption(t.textSecondary)),
              ),
            ),
            const SizedBox(height: Space.section),
            FadeSlideIn(
              index: 1,
              child: allocationAsync.when(
                data: (entries) => entries.isEmpty ? const SizedBox.shrink() : AllocationChart(entries: entries),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: Space.section),
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
              error: (_, __) => Center(
                child: Text('Something went wrong. Pull down to retry.',
                    style: AppText.caption(t.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingsGrouped extends ConsumerWidget {
  final List<Holding> holdings;
  const _HoldingsGrouped({required this.holdings});

  static const _typeLabels = {
    'stock': 'STOCKS',
    'mutual_fund': 'MUTUAL FUNDS',
    'etf': 'ETFS',
    'bond': 'BONDS',
    'gold': 'GOLD',
  };

  /// Latest cached market price for a holding, or null if we've never fetched
  /// one (the card then falls back to the average buy price).
  double? _cachedPrice(String symbol) {
    final cached = LocalDatabase.priceCache.get(symbol);
    final p = cached != null ? (cached['price'] as num?)?.toDouble() : null;
    return (p != null && p > 0) ? p : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final grouped = <String, List<Holding>>{};
    for (final h in holdings) {
      (grouped[h.type] ??= []).add(h);
    }

    final children = <Widget>[];
    var staggerIdx = 2; // starts after portfolio (0) and allocation (1)
    grouped.forEach((type, list) {
      // Uppercase eyebrow label for the asset-type group heading.
      children.add(Padding(
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
        child: Text(
          _typeLabels[type] ?? type.toUpperCase(),
          style: AppText.micro(t.textTertiary),
        ),
      ));
      for (final h in list) {
        // Cap stagger index so long lists don't accumulate huge delays.
        final idx = staggerIdx < 8 ? staggerIdx : 8;
        children.add(FadeSlideIn(
          index: idx,
          child: PressableScale(
            scale: 0.97,
            child: GestureDetector(
              // Tap to edit, long-press to delete — a mistyped holding was
              // previously permanent (no edit and no delete existed at all).
              onTap: () => _editHolding(context, ref, h.id),
              onLongPress: () => _confirmDeleteHolding(context, ref, h),
              child: HoldingCard(holding: h, currentPrice: _cachedPrice(h.symbol)),
            ),
          ),
        ));
        staggerIdx++;
      }
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// Opens the holding form prefilled from its stored Hive row.
void _editHolding(BuildContext context, WidgetRef ref, String id) {
  final row = LocalDatabase.holdings.get(id);
  if (row == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddHoldingScreen(existing: Map<String, dynamic>.from(row)),
    ),
  );
}

/// Confirms a holding delete, showing the value being destroyed, then offers
/// Undo. On-device storage has no cloud backup, so a mis-tap must be reversible.
Future<void> _confirmDeleteHolding(
    BuildContext context, WidgetRef ref, Holding h) async {
  final fmt = NumberFormat('#,##0');
  final invested = h.quantity * h.avgPrice;
  final messenger = ScaffoldMessenger.of(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${h.symbol}?'),
      content: Text(
          'This removes ${h.quantity} unit(s) of ${h.name.isEmpty ? h.symbol : h.name} '
          '— ₹${fmt.format(invested)} invested. It also clears the net-worth trend, '
          'because past readings included this holding.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return;

  final removed = await ref.read(addHoldingProvider).delete(h.id);
  if (removed == null) return;
  messenger.showSnackBar(SnackBar(
    content: Text('Deleted ${h.symbol}'),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () => ref.read(addHoldingProvider).restore(removed),
    ),
  ));
}
