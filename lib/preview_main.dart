import 'package:flutter/material.dart';
import 'presentation/common/theme/app_theme.dart';
import 'presentation/common/theme/app_animations.dart';
import 'presentation/common/widgets/empty_state.dart';
import 'presentation/investments/investment_providers.dart';
import 'presentation/investments/widgets/portfolio_value_card.dart';
import 'presentation/investments/widgets/allocation_chart.dart';
import 'presentation/investments/widgets/holding_card.dart';
import 'presentation/goals/goals_providers.dart';
import 'presentation/goals/widgets/goal_card.dart';
import 'domain/entities/holding.dart';

/// Standalone web preview of the modern FinTrack UI. Renders the REAL restyled
/// widgets with fake data. Uses only web-safe imports (no tflite/telephony/etc).
///
///   flutter build web -t lib/preview_main.dart --web-renderer html
void main() => runApp(const _PreviewApp());

final _fakePortfolio = PortfolioValue(
  totalInvested: 210000,
  currentValue: 243500,
  dayChange: 1820,
  sparkline: const <double>[200000, 205000, 202000, 210000, 225000, 240000, 243500],
);

final _fakeAllocation = [
  AllocationEntry(type: 'stock', value: 146100, percent: 60),
  AllocationEntry(type: 'mutual_fund', value: 60875, percent: 25),
  AllocationEntry(type: 'etf', value: 24350, percent: 10),
  AllocationEntry(type: 'gold', value: 12175, percent: 5),
];

const _reliance = Holding(id: '1', symbol: 'RELIANCE', name: 'Reliance Industries', type: 'stock', quantity: 10, avgPrice: 2400, currency: 'INR');
const _infy = Holding(id: '2', symbol: 'INFY', name: 'Infosys Ltd', type: 'stock', quantity: 15, avgPrice: 1600, currency: 'INR');

const _fakeGoal = FinancialGoal(
  id: 'g1',
  name: 'Emergency Fund',
  type: GoalType.emergency,
  targetAmount: 300000,
  currentAmount: 180000,
);

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _PreviewHome(),
      );
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();
  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinTrack'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.settings))],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _nav,
        onDestinationSelected: (i) => setState(() => _nav = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Investments'),
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: 'Insights'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero gradient balance card
          ShimmerGradientContainer(
            colors: AppTheme.brandGradient.colors,
            boxShadow: [
              BoxShadow(color: AppTheme.seed.withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 12)),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('Total Spent', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                ]),
                const SizedBox(height: 12),
                const Text('₹48,250', style: TextStyle(fontFamily: 'SpaceGrotesk', color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1)),
                const SizedBox(height: 6),
                Text('Across all tracked expenses', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _quickAction(Icons.add, 'Expense'),
            const SizedBox(width: 12),
            _quickAction(Icons.camera_alt, 'Scan'),
            const SizedBox(width: 12),
            _quickAction(Icons.show_chart, 'Holding'),
          ]),
          const SizedBox(height: 24),
          Text('Investments', style: tt.titleLarge),
          const SizedBox(height: 8),
          PortfolioValueCard(portfolio: _fakePortfolio),
          const SizedBox(height: 12),
          AllocationChart(entries: _fakeAllocation),
          const SizedBox(height: 12),
          const HoldingCard(holding: _reliance, currentPrice: 2820, dayChange: 1.4),
          const HoldingCard(holding: _infy, currentPrice: 1560, dayChange: -0.6),
          const SizedBox(height: 16),
          Text('Goals', style: tt.titleLarge),
          const SizedBox(height: 8),
          const GoalCard(goal: _fakeGoal, progress: {'on_track': true, 'months_needed': 24}),
          const SizedBox(height: 8),
          Card(
            child: SizedBox(
              height: 240,
              child: EmptyState(
                icon: Icons.savings,
                message: 'No savings goals yet',
                actionLabel: 'Create goal',
                onAction: () {},
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Transactions', style: tt.titleLarge),
          const SizedBox(height: 8),
          _txn(cs, Icons.fastfood, 'Zomato', 'Jul 6', '₹430'),
          _txn(cs, Icons.local_taxi, 'Uber', 'Jul 5', '₹280'),
          _txn(cs, Icons.shopping_cart, 'BigBasket', 'Jul 4', '₹1,240'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) => Expanded(
        child: PressableScale(
          child: FilledButton.tonal(
            onPressed: () {},
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _txn(ColorScheme cs, IconData icon, String name, String date, String amt) => ListTile(
        leading: CircleAvatar(backgroundColor: cs.secondaryContainer, child: Icon(icon, color: cs.onSecondaryContainer, size: 20)),
        title: Text(name),
        subtitle: Text(date),
        trailing: Text(amt, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppTheme.negative)),
      );
}
