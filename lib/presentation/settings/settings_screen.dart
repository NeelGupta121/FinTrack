import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/model_config.dart';
import '../../data/datasources/local/local_database.dart';
import '../expenses/expense_providers.dart';

/// Cached value loaded in main.dart before runApp.
ThemeMode savedThemeMode = ThemeMode.dark;

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(savedThemeMode);

  void set(ThemeMode mode) {
    state = mode;
    SharedPreferences.getInstance().then((p) => p.setString('theme_mode', mode.name));
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((_) => ThemeModeNotifier());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickModel(BuildContext context, WidgetRef ref) async {
    final current = ref.read(geminiModelProvider);
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AI Model'),
        children: [
          for (final m in GeminiModelConfig.available)
            RadioListTile<String>(
              value: m,
              groupValue: current,
              title: Text(m),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == current) return;
    await GeminiModelConfig.set(chosen);
    ref.read(geminiModelProvider.notifier).state = chosen;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI model switched to $chosen')),
      );
    }
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = ref.read(monthlyBudgetProvider);
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Budget', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(ctrl.text.trim());
              if (value == null || value <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Enter a budget greater than 0')),
                );
                return;
              }
              Navigator.pop(ctx);
              await LocalDatabase.settings.put('monthly_budget', value);
              ref.invalidate(monthlyBudgetProvider);
              ref.invalidate(monthlySummaryProvider);
              messenger.showSnackBar(
                SnackBar(content: Text('Monthly budget set to ₹${value.toStringAsFixed(0)}')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile
          const _SectionHeader('Profile'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('User'),
            subtitle: const Text('user@example.com'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),

          // Preferences
          const _SectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.currency_rupee),
            title: const Text('Currency'),
            trailing: const Text('INR (₹)'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Monthly budget'),
            trailing: Text('₹${ref.watch(monthlyBudgetProvider).toStringAsFixed(0)}'),
            onTap: () => _editBudget(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(
                v ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),

          // AI
          const _SectionHeader('AI'),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI Model'),
            subtitle: Text(ref.watch(geminiModelProvider)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickModel(context, ref),
          ),
          const Divider(),

          // About
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('FinTrack'),
            subtitle: Text('v0.1.0 • AI-powered finance tracker'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            onTap: () => showLicensePage(context: context, applicationName: 'FinTrack'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary)),
      );
}
