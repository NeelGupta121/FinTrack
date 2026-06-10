import 'package:flutter/material.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.lightbulb, color: Theme.of(context).colorScheme.tertiary),
              title: const Text('AI insights will appear here'),
              subtitle: const Text('Add transactions to get personalized analysis'),
            ),
          ),
        ],
      ),
    );
  }
}
