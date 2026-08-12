import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../common/theme/app_animations.dart';
import '../common/theme/app_theme.dart';
import '../common/widgets/category_icon.dart';
import '../common/widgets/wellness_cards.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';
import 'wellness_providers.dart';

/// Dashboard.
///
/// The previous version was a single `ListView` of uniformly-sized bordered
/// cards separated by 16px gaps. Everything had identical visual weight, so
/// nothing read as primary — which is the main reason the screen felt dated
/// regardless of its colour palette.
///
/// This version establishes hierarchy:
///   * ONE hero (net worth), large and light.
///   * A 2-up bento row for the two secondary KPIs, which previously occupied
///     two full-width cards each competing with the hero.
///   * Quick actions as compact icon plates rather than three chunky buttons.
///   * Lists as borderless rows with hairline dividers instead of a card per
///     item, following the transaction-list convention in Copilot/Mercury.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AmbientGlow(
        child: CustomScrollView(
          slivers: [
            _DashboardHeader(greeting: _greeting()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                // Must clear the floating nav pill (66 + 12 margin + safe area)
                // AND the chat FAB that floats above it. At 80 the last section
                // was still hidden behind the nav at rest.
                136,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ---- Hero: net worth -------------------------------------
                  FadeSlideIn(
                    index: 0,
                    child: NetWorthCard(
                      onManageAccounts: () => context.push('/accounts'),
                    ),
                  ),
                  const SizedBox(height: Space.bento),

                  // ---- Bento: the two secondary KPIs, side by side ---------
                  // IntrinsicHeight is required: CrossAxisAlignment.stretch
                  // needs a bounded height, and a Row inside a sliver child has
                  // unbounded vertical constraints. Without it the Row throws
                  // and — in a release build — the rest of the list silently
                  // fails to lay out with no visible error.
                  const FadeSlideIn(
                    index: 1,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _SafeToSpendCard()),
                          SizedBox(width: Space.bento),
                          Expanded(child: _MonthSpendCard()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.bento),

                  const FadeSlideIn(index: 2, child: _HealthScoreCard()),
                  const SizedBox(height: Space.section),

                  // ---- Quick actions --------------------------------------
                  const _SectionLabel('Quick actions'),
                  const SizedBox(height: Space.md),
                  FadeSlideIn(
                    index: 3,
                    child: Row(
                      children: [
                        _QuickAction(
                            icon: Icons.add_rounded,
                            label: 'Expense',
                            onTap: () => context.push('/expenses/add')),
                        const SizedBox(width: Space.bento),
                        _QuickAction(
                            icon: Icons.camera_alt_rounded,
                            label: 'Scan',
                            onTap: () => context.push('/expenses/add?scan=1')),
                        const SizedBox(width: Space.bento),
                        _QuickAction(
                            icon: Icons.trending_up_rounded,
                            label: 'Holding',
                            onTap: () => context.push('/investments/add')),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.section),

                  // ---- Portfolio ------------------------------------------
                  const _SectionLabel('Portfolio'),
                  const SizedBox(height: Space.md),
                  const FadeSlideIn(index: 4, child: _PortfolioCard()),
                  const SizedBox(height: Space.section),

                  // ---- Spending trend (self-hides when empty) --------------
                  const FadeSlideIn(index: 5, child: SpendingTrendCard()),

                  // ---- Manage ---------------------------------------------
                  const _SectionLabel('Manage'),
                  const SizedBox(height: Space.md),
                  const FadeSlideIn(
                    index: 6,
                    child: _ManageGroup(
                      items: [
                        _ManageItem(Icons.account_balance_rounded,
                            'Accounts & Debts', '/accounts'),
                        _ManageItem(Icons.receipt_long_rounded,
                            'Bills & Subscriptions', '/bills'),
                        _ManageItem(Icons.flag_rounded, 'Goals', '/goals'),
                        _ManageItem(
                            Icons.description_rounded, 'Reports', '/reports'),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.section),

                  // ---- Recent transactions --------------------------------
                  Row(
                    children: [
                      const _SectionLabel('Recent activity'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/expenses'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  const FadeSlideIn(index: 7, child: _RecentActivity()),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsing header: a large greeting that shrinks to a compact title on
/// scroll, replacing the flat default AppBar.
class _DashboardHeader extends StatelessWidget {
  final String greeting;
  const _DashboardHeader({required this.greeting});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 108,
      backgroundColor: t.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          color: t.textSecondary,
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: Space.sm),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (ctx, constraints) {
          final expandRatio = ((constraints.maxHeight - kToolbarHeight) /
                  (108 - kToolbarHeight))
              .clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.lerp(
              const EdgeInsets.only(left: Space.gutter, bottom: Space.lg),
              const EdgeInsets.only(left: Space.gutter, bottom: Space.md),
              1 - expandRatio,
            )!,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The eyebrow fades out as the header collapses so the
                  // compact state is a single clean title.
                  Opacity(
                    opacity: expandRatio,
                    child: SizedBox(
                      height: 16 * expandRatio,
                      child: Text(greeting,
                          maxLines: 1,
                          style: AppText.micro(t.textTertiary)),
                    ),
                  ),
                  Text(
                    'FinTrack',
                    style: AppText.section(
                      t.textPrimary,
                      size: 20 + (8 * expandRatio),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppText.cardTitle(context.tokens.textPrimary),
      );
}

/// Shared shell for the compact bento cells so they stay visually identical.
class _MiniCard extends StatelessWidget {
  final Widget child;
  const _MiniCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.brMd,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: Radii.brMd,
              border: Border.all(color: t.borderStandard),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.accentSubtle,
                    borderRadius: Radii.brSm,
                  ),
                  child: Icon(icon, size: 19, color: t.accent),
                ),
                const SizedBox(height: Space.sm),
                Text(label, style: AppText.caption(t.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Total spent so far this month.
///
/// This was previously the full-bleed gradient hero showing all-time spend.
/// All-time spend is not an actionable number, so it has been demoted to a
/// bento cell and scoped to the current month, where it is comparable against
/// the safe-to-spend figure beside it.
class _MonthSpendCard extends ConsumerWidget {
  const _MonthSpendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final fmt = NumberFormat('#,##0');
    final expenses = ref.watch(expenseListProvider);
    final now = DateTime.now();

    return _MiniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPENT THIS MONTH', style: AppText.micro(t.textTertiary)),
          const SizedBox(height: Space.md),
          expenses.when(
            data: (list) {
              final total = list
                  .where((x) =>
                      x.type == 'expense' &&
                      x.date.year == now.year &&
                      x.date.month == now.month)
                  .fold<double>(0, (s, x) => s + x.amount);
              return AnimatedCount(
                value: total,
                formatter: (v) => '₹${fmt.format(v)}',
                style: AppText.money(t.textPrimary, size: 26),
              );
            },
            loading: () =>
                Text('₹0', style: AppText.money(t.textTertiary, size: 26)),
            error: (_, __) =>
                Text('₹0', style: AppText.money(t.textTertiary, size: 26)),
          ),
          const SizedBox(height: Space.xs),
          Text(DateFormat.MMMM().format(now),
              style: AppText.caption(t.textTertiary)),
        ],
      ),
    );
  }
}

/// "In My Pocket": budget left for the rest of the month + a per-day allowance.
class _SafeToSpendCard extends ConsumerWidget {
  const _SafeToSpendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final async = ref.watch(safeToSpendProvider);
    final fmt = NumberFormat('#,##0');

    return _MiniCard(
      child: async.when(
        loading: () => const SizedBox(
            height: 78,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => SizedBox(
            height: 78,
            child: Center(
                child: Text('Unavailable',
                    style: AppText.caption(t.textTertiary)))),
        data: (s) {
          final positive = !s.overBudget;
          // Deliberately NOT green when positive. Safe-to-spend is a neutral
          // budget figure, not a gain, and a large saturated green numeral here
          // out-shouted the single indigo accent. Green is reserved for actual
          // income/gains; red still signals the genuine problem state.
          final accent = positive ? t.textPrimary : t.error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SAFE TO SPEND', style: AppText.micro(t.textTertiary)),
              const SizedBox(height: Space.md),
              // The numeral slot stays NUMERIC in both states. Putting the
              // words "Over budget" here at 26px wrapped onto two lines and
              // overflowed the bento cell once real data pushed spend past the
              // budget; showing the amount over is also more actionable.
              Text(
                positive
                    ? '₹${fmt.format(s.remaining)}'
                    : '−₹${fmt.format(s.overspentBy)}',
                maxLines: 1,
                style: AppText.money(accent, size: 26),
              ),
              const SizedBox(height: Space.xs),
              Text(
                positive
                    ? '≈ ₹${fmt.format(s.perDay)}/day · ${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left'
                    : 'over this month\'s budget',
                style: AppText.caption(t.textTertiary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Financial health score (0-100) with its factor breakdown, so the number is
/// explainable rather than opaque.
class _HealthScoreCard extends ConsumerWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final async = ref.watch(healthScoreProvider);

    return _MiniCard(
      child: async.when(
        loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => SizedBox(
            height: 72,
            child: Center(
                child: Text('Health score unavailable',
                    style: AppText.caption(t.textTertiary)))),
        data: (h) {
          // With fewer than two usable signals a number would mislead
          // (it would punish a new user for not having entered data yet).
          if (!h.hasEnoughData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FINANCIAL HEALTH',
                    style: AppText.micro(t.textTertiary)),
                const SizedBox(height: Space.md),
                Text('Not enough data yet',
                    style: AppText.cardTitle(t.textPrimary)),
                const SizedBox(height: Space.xs),
                Text(
                  'Your score appears once at least two of these are known:'
                  ' a monthly budget, logged income, and investments.',
                  style: AppText.caption(t.textTertiary),
                ),
              ],
            );
          }

          final colour = h.score >= 65
              ? t.success
              : h.score >= 45
                  ? t.warning
                  : t.error;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('FINANCIAL HEALTH',
                      style: AppText.micro(t.textTertiary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm + 2, vertical: 3),
                    decoration: BoxDecoration(
                      color: colour.withOpacity(t.isDark ? 0.14 : 0.10),
                      borderRadius: Radii.brPill,
                    ),
                    child: Text(h.band,
                        style:
                            AppText.caption(colour, weight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${h.score}',
                      style: AppText.hero(t.textPrimary, size: 36)),
                  const SizedBox(width: Space.xs),
                  Text('/100', style: AppText.caption(t.textTertiary)),
                ],
              ),
              const SizedBox(height: Space.md),
              // Thin track, rounded, brand-coloured — reads as a meter rather
              // than a Material progress bar.
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xs),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: h.score / 100),
                  duration: Motion.chart,
                  curve: Motion.decelerate,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    backgroundColor: t.panel,
                    valueColor: AlwaysStoppedAnimation<Color>(colour),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              for (final f in h.factors)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${f.label} — ${f.detail}',
                            style: AppText.caption(t.textSecondary)),
                      ),
                      const SizedBox(width: Space.sm),
                      Text('${f.score}/${f.maxScore}',
                          style: AppText.money(t.textPrimary, size: 13)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PortfolioCard extends ConsumerWidget {
  const _PortfolioCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pv = ref.watch(portfolioValueProvider);
    final fmt = NumberFormat('#,##0');

    return _MiniCard(
      child: pv.when(
        loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PortfolioStat(label: 'INVESTED', value: '₹0'),
            _PortfolioStat(label: 'CURRENT', value: '₹0'),
            _PortfolioStat(label: 'RETURNS', value: '0%'),
          ],
        ),
        data: (p) {
          final returns = p.totalInvested > 0
              ? ((p.currentValue - p.totalInvested) / p.totalInvested * 100)
              : 0.0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PortfolioStat(
                  label: 'INVESTED', value: '₹${fmt.format(p.totalInvested)}'),
              _PortfolioStat(
                  label: 'CURRENT', value: '₹${fmt.format(p.currentValue)}'),
              _PortfolioStat(
                label: 'RETURNS',
                value:
                    '${returns >= 0 ? '+' : ''}${returns.toStringAsFixed(1)}%',
                // Zero is not a gain, so it stays neutral. Colouring 0.0%
                // green implied a positive result where there was none.
                colour: returns > 0
                    ? t.success
                    : returns < 0
                        ? t.error
                        : t.textPrimary,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortfolioStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? colour;
  const _PortfolioStat(
      {required this.label, required this.value, this.colour});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.micro(t.textTertiary)),
        const SizedBox(height: Space.xs + 2),
        Text(value,
            style: AppText.money(colour ?? t.textPrimary, size: 16)),
      ],
    );
  }
}

class _ManageItem {
  final IconData icon;
  final String label;
  final String route;
  const _ManageItem(this.icon, this.label, this.route);
}

/// Grouped navigation rows.
///
/// Previously four raw `ListTile`s inside a `Card` — the most Material-2
/// looking block on the screen. Now squircle icon plates, hairline dividers
/// inset past the icon, and a muted chevron.
class _ManageGroup extends StatelessWidget {
  final List<_ManageItem> items;
  const _ManageGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(height: 1, color: t.borderSubtle),
              ),
            InkWell(
              onTap: () => context.push(items[i].route),
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(Radii.md))
                  : i == items.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(Radii.md))
                      : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg, vertical: Space.md + 2),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: Radii.brSm,
                      ),
                      child: Icon(items[i].icon,
                          size: 17, color: t.textSecondary),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(items[i].label,
                          style: AppText.bodyText(t.textPrimary,
                              weight: FontWeight.w500)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recent transactions as borderless rows.
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final fmt = NumberFormat('#,##0');
    final expenses = ref.watch(expenseListProvider);

    return expenses.when(
      loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => _MiniCard(
        child: Text('Something went wrong.',
            style: AppText.caption(t.textTertiary)),
      ),
      data: (list) {
        final recent = list.take(5).toList();
        if (recent.isEmpty) {
          return _MiniCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 22, color: t.textTertiary),
                    const SizedBox(height: Space.sm),
                    Text('No transactions yet',
                        style: AppText.caption(t.textTertiary)),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: Radii.brMd,
            border: Border.all(color: t.borderStandard),
            boxShadow: t.cardShadow,
          ),
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: Divider(height: 1, color: t.borderSubtle),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg, vertical: Space.md),
                  child: Row(
                    children: [
                      CategoryIcon(slug: recent[i].categoryId ?? '', size: 34),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recent[i].description ??
                                  recent[i].merchant ??
                                  'Expense',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyText(t.textPrimary,
                                  weight: FontWeight.w500),
                            ),
                            const SizedBox(height: 1),
                            Text(DateFormat.MMMd().format(recent[i].date),
                                style: AppText.caption(t.textTertiary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        '${recent[i].type == 'income' ? '+' : '−'}₹${fmt.format(recent[i].amount)}',
                        style: AppText.money(
                          recent[i].type == 'income'
                              ? t.success
                              : t.textPrimary,
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
