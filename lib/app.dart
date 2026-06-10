import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/common/theme/app_theme.dart';
import 'presentation/common/theme/app_animations.dart';
import 'presentation/common/widgets/bottom_nav.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/expenses/expense_list_screen.dart';
import 'presentation/expenses/add_expense_screen.dart';
import 'presentation/investments/investments_screen.dart';
import 'presentation/insights/insights_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/investments/add_holding_screen.dart';

final _onboardingDone = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
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
              GoRoute(path: 'add', pageBuilder: (_, state) =>
                  AppAnimations.fadeSlideTransition(state, const AddExpenseScreen())),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/investments',
            builder: (_, __) => const InvestmentsScreen(),
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
    GoRoute(path: '/settings', pageBuilder: (_, state) =>
        AppAnimations.fadeSlideTransition(state, const SettingsScreen())),
  ],
);

class FinTrackApp extends ConsumerWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboarded = ref.watch(_onboardingDone);
    return onboarded.when(
      loading: () => const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))),
      error: (_, __) => MaterialApp.router(routerConfig: _router),
      data: (done) => MaterialApp.router(
        title: 'FinTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: done ? _router : GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
            GoRoute(path: '/', redirect: (_, __) => '/onboarding'),
          ],
        ),
      ),
    );
  }
}
