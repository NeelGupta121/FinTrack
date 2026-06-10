import 'package:flutter/material.dart';
import '../../common/widgets/fade_slide_transition.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const _features = [
    (Icons.auto_awesome, 'Track Expenses with AI'),
    (Icons.trending_up, 'Monitor Investments'),
    (Icons.insights, 'Get Smart Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet,
              size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Welcome to FinTrack',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Your AI-powered financial companion',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 48),
          ...List.generate(_features.length, (i) {
            final (icon, label) = _features[i];
            return FadeSlideTransition(
              delay: Duration(milliseconds: 200 + i * 200),
              child: ListTile(
                leading: Icon(icon, color: theme.colorScheme.primary),
                title: Text(label),
              ),
            );
          }),
        ],
      ),
    );
  }
}
