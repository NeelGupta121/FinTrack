import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/empty_state.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
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
    final t = context.tokens;
    final anomalies = ref.watch(spendingAnomaliesProvider);
    return anomalies.when(
      data: (list) => list.isEmpty
          ? Center(
              child: Text(
                'No anomalies detected. Your spending looks normal! 🎉',
                style: AppText.bodyText(t.textSecondary),
              ),
            )
          : ListView.builder(
              // Nav shell branch: floating pill overlays this screen.
              padding: const EdgeInsets.only(
                left: Space.gutter,
                right: Space.gutter,
                top: Space.lg,
                bottom: 136,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => FadeSlideIn(
                index: i < 6 ? i : 6,
                child: AnomalyCard(anomaly: list[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Something went wrong. Pull down to retry.',
          style: AppText.bodyText(t.textSecondary),
        ),
      ),
    );
  }
}

class _PortfolioTab extends ConsumerWidget {
  const _PortfolioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final drift = ref.watch(driftAlertsProvider);
    final digest = ref.watch(weeklyDigestProvider);

    return ListView(
      // Nav shell branch: floating pill overlays this screen.
      padding: const EdgeInsets.only(
        left: Space.gutter,
        right: Space.gutter,
        top: Space.lg,
        bottom: 136,
      ),
      children: [
        const FadeSlideIn(index: 0, child: BenchmarkChart()),
        const SizedBox(height: Space.section),
        FadeSlideIn(
          index: 1,
          child: drift.when(
            data: (alerts) => alerts.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: Radii.brMd,
                      border: Border.all(color: t.borderStandard),
                      boxShadow: t.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: t.success.withOpacity(t.isDark ? 0.14 : 0.10),
                            borderRadius: Radii.brSm,
                          ),
                          child: Icon(Icons.check_rounded, size: 17, color: t.success),
                        ),
                        const SizedBox(width: Space.md),
                        Text(
                          'Portfolio on target ✅',
                          style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: Radii.brMd,
                      border: Border.all(color: t.borderStandard),
                      boxShadow: t.cardShadow,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < alerts.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 60),
                              child: Divider(height: 1, color: t.borderSubtle),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.lg,
                              vertical: Space.md + 2,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: (alerts[i].driftPct > 0
                                            ? t.warning
                                            : t.accent)
                                        .withOpacity(t.isDark ? 0.14 : 0.10),
                                    borderRadius: Radii.brSm,
                                  ),
                                  child: Icon(
                                    alerts[i].driftPct > 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 17,
                                    color: alerts[i].driftPct > 0
                                        ? t.warning
                                        : t.accent,
                                  ),
                                ),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alerts[i].symbol,
                                        style: AppText.bodyText(
                                          t.textPrimary,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${alerts[i].currentPct.toStringAsFixed(1)}% vs target ${alerts[i].targetPct.toStringAsFixed(1)}%',
                                        style: AppText.caption(t.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${alerts[i].driftPct > 0 ? "+" : ""}${alerts[i].driftPct.toStringAsFixed(1)}%',
                                  style: AppText.money(
                                    alerts[i].driftPct > 0 ? t.warning : t.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(
              'Something went wrong.',
              style: AppText.bodyText(t.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: Space.section),
        FadeSlideIn(
          index: 2,
          child: Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: Radii.brMd,
              border: Border.all(color: t.borderStandard),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.accentSubtle,
                      borderRadius: Radii.brSm,
                    ),
                    child: Icon(Icons.auto_awesome, size: 17, color: t.accent),
                  ),
                  const SizedBox(width: Space.md),
                  Text('AI Review', style: AppText.cardTitle(t.textPrimary)),
                ]),
                const SizedBox(height: Space.md),
                digest.when(
                  data: (text) => Text(
                    text,
                    style: AppText.bodyText(t.textSecondary),
                  ),
                  loading: () => Text(
                    'Generating insights...',
                    style: AppText.bodyText(t.textTertiary),
                  ),
                  error: (_, __) => Text(
                    'Something went wrong.',
                    style: AppText.bodyText(t.textSecondary),
                  ),
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
    final t = context.tokens;
    final holdingsAsync = ref.watch(holdingsInputProvider);
    return holdingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Something went wrong. Pull down to retry.',
          style: AppText.bodyText(t.textSecondary),
        ),
      ),
      data: (holdings) {
        if (holdings.isEmpty) {
          return const EmptyState(
            icon: Icons.lightbulb_outline,
            message: 'Add transactions to get insights',
          );
        }
        return ListView.builder(
          // Nav shell branch: floating pill overlays this screen.
          padding: const EdgeInsets.only(
            left: Space.gutter,
            right: Space.gutter,
            top: Space.lg,
            bottom: 136,
          ),
          itemCount: holdings.length,
          itemBuilder: (_, i) {
            final h = holdings[i];
            final news = ref.watch(newsWithSentimentProvider(h.symbol));
            return FadeSlideIn(
              index: i < 6 ? i : 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Text(
                      h.name,
                      style: AppText.cardTitle(t.textPrimary),
                    ),
                  ),
                  news.when(
                    data: (items) => Container(
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: Radii.brMd,
                        border: Border.all(color: t.borderStandard),
                        boxShadow: t.cardShadow,
                      ),
                      child: Column(
                        children: [
                          for (var j = 0; j < items.length; j++) ...[
                            if (j > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.lg),
                                child: Divider(height: 1, color: t.borderSubtle),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(Space.lg),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          items[j].article.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.bodyText(
                                            t.textPrimary,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: Space.xs),
                                        Text(
                                          items[j].article.snippet,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.caption(t.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: Space.md),
                                  SentimentBadge(sentiment: items[j].sentiment),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(Space.sm),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, __) => Text(
                      'Something went wrong.',
                      style: AppText.bodyText(t.textSecondary),
                    ),
                  ),
                  const SizedBox(height: Space.section),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
