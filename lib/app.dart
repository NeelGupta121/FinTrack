import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/common/theme/app_theme.dart';
import 'presentation/common/widgets/bottom_nav.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/expenses/expense_list_screen.dart';
import 'presentation/expenses/add_expense_screen.dart';
import 'presentation/investments/investments_screen.dart';
import 'presentation/insights/insights_screen.dart';
import 'presentation/settings/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: BottomNav(shell: shell),
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpenseListScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddExpenseScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/investments',
            builder: (_, __) => const InvestmentsScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddInvestmentScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

class FinTrackApp extends ConsumerWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FinTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
