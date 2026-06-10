import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FinTrack',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const _Placeholder('Dashboard')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/expenses', builder: (_, __) => const _Placeholder('Expenses')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/investments', builder: (_, __) => const _Placeholder('Investments')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insights', builder: (_, __) => const _Placeholder('Insights')),
        ]),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Investments'),
          NavigationDestination(icon: Icon(Icons.lightbulb), label: 'Insights'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
  );
}

final _lightTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF1B5E20),
  brightness: Brightness.light,
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF1B5E20),
  brightness: Brightness.dark,
);
