import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/holding.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_animations.dart';
import 'investment_providers.dart';
import 'add_holding_screen.dart';
import 'widgets/portfolio_value_card.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';

class HoldingsListScreen extends ConsumerWidget {
  const HoldingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(holdingsListProvider);
    final portfolioAsync = ref.watch(portfolioValueProvider);
    final allocationAsync = ref.watch(portfolioAllocationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Investments')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHoldingScreen())),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(holdingsListProvider);
          ref.invalidate(portfolioValueProvider);
          ref.invalidate(portfolioAllocationProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              index: 0,
              child: portfolioAsync.when(
                data: (pv) => PortfolioValueCard(portfolio: pv),
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
          child: PressableScale(scale: 0.97, child: HoldingCard(holding: h)),
        ));
        i++;
      }
      children.add(const SizedBox(height: 8));
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
