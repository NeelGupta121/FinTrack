import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const BottomNav({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
        NavigationDestination(icon: Icon(Icons.trending_up), label: 'Investments'),
        NavigationDestination(icon: Icon(Icons.lightbulb), label: 'Insights'),
      ],
    );
  }
}
