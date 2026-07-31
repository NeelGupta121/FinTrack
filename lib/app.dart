import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/common/theme/app_theme.dart';
import 'presentation/common/theme/app_animations.dart';
import 'presentation/common/widgets/bottom_nav.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/expenses/expense_list_screen.dart';
import 'presentation/expenses/add_expense_screen.dart';
import 'presentation/investments/holdings_list_screen.dart';
import 'presentation/insights/insights_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/investments/add_holding_screen.dart';
import 'presentation/chat/chat_screen.dart';
import 'presentation/bills/bills_screen.dart';
import 'presentation/goals/goals_screen.dart';
import 'presentation/reports/reports_screen.dart';
import 'presentation/accounts/accounts_screen.dart';

/// Cached onboarding status -- set in main() before runApp, updated by OnboardingScreen.
bool onboardingComplete = false;

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (!onboardingComplete && loc != '/onboarding') return '/onboarding';
    if (onboardingComplete && loc == '/onboarding') return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: BottomNav(shell: shell),
        floatingActionButton: FloatingActionButton(
          heroTag: 'chat_fab',
          onPressed: () => GoRouter.of(context).push('/chat'),
          child: const Icon(Icons.smart_toy),
        ),
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
              GoRoute(path: 'add', pageBuilder: (_, state) =>
                  AppAnimations.fadeSlideTransition(state, AddExpenseScreen(autoScan: state.uri.queryParameters['scan'] == '1'))),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/investments',
            builder: (_, __) => const HoldingsListScreen(),
            routes: [
              GoRoute(path: 'add', pageBuilder: (_, state) =>
                  AppAnimations.fadeSlideTransition(state, const AddHoldingScreen())),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
    GoRoute(path: '/bills', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const BillsScreen())),
    GoRoute(path: '/goals', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const GoalsScreen())),
    GoRoute(path: '/reports', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const ReportsScreen())),
    GoRoute(path: '/accounts', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const AccountsScreen())),
    GoRoute(path: '/settings', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const SettingsScreen())),
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
