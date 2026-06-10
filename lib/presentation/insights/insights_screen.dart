import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/empty_state.dart';
import 'insights_providers.dart';
import 'widgets/anomaly_card.dart';
import 'widgets/sentiment_badge.dart';
import 'widgets/benchmark_chart.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Spending'), icon: Icon(Icons.trending_up)),
                ButtonSegment(value: 1, label: Text('Portfolio'), icon: Icon(Icons.pie_chart)),
                ButtonSegment(value: 2, label: Text('News'), icon: Icon(Icons.newspaper)),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [_SpendingTab(), _PortfolioTab(), _NewsTab()],
      ),
    );
  }
}

class _SpendingTab extends ConsumerWidget {
  const _SpendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomalies = ref.watch(spendingAnomaliesProvider);
    return anomalies.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('No anomalies detected. Your spending looks normal! 🎉'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => AnomalyCard(anomaly: list[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PortfolioTab extends ConsumerWidget {
  const _PortfolioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drift = ref.watch(driftAlertsProvider);
    final digest = ref.watch(weeklyDigestProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const BenchmarkChart(),
        const SizedBox(height: 16),
        drift.when(
          data: (alerts) => alerts.isEmpty
              ? const Card(child: ListTile(title: Text('Portfolio on target ✅')))
              : Column(children: alerts.map((a) => Card(
                  child: ListTile(
                    leading: Icon(a.driftPct > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: a.driftPct > 0 ? Colors.orange : Colors.blue),
                    title: Text(a.symbol),
                    subtitle: Text('${a.currentPct.toStringAsFixed(1)}% vs target ${a.targetPct.toStringAsFixed(1)}%'),
                    trailing: Text('${a.driftPct > 0 ? "+" : ""}${a.driftPct.toStringAsFixed(1)}%'),
                  ),
                )).toList()),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 8),
                  const Text('AI Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                digest.when(
                  data: (text) => Text(text),
                  loading: () => const Text('Generating insights...'),
                  error: (e, _) => Text('$e'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsTab extends ConsumerWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(holdingsInputProvider);
    return holdingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (holdings) {
        if (holdings.isEmpty) {
          return const EmptyState(
            icon: Icons.lightbulb_outline,
            message: 'Add transactions to get insights',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: holdings.length,
          itemBuilder: (_, i) {
            final h = holdings[i];
            final news = ref.watch(newsWithSentimentProvider(h.symbol));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(h.name, style: Theme.of(context).textTheme.titleMedium),
                ),
                news.when(
                  data: (items) => Column(children: items.map((n) => Card(
                    child: ListTile(
                      title: Text(n.article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(n.article.snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: SentimentBadge(sentiment: n.sentiment),
                    ),
                  )).toList()),
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
