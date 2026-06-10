import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/smart_import_service.dart';
import '../../data/datasources/local/tflite_datasource.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';

/// Cached value loaded in main.dart before runApp.
ThemeMode savedThemeMode = ThemeMode.system;

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

  Future<void> _scanSms(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Scanning SMS...')),
        ]),
      ),
    );
    try {
      final tflite = TfliteDatasource();
      await tflite.load();
      final result = await SmartImportService(tflite).scanAndImport();
      if (!context.mounted) return;
      Navigator.pop(context); // close progress dialog
      ref.invalidate(expenseListProvider);
      ref.invalidate(holdingsListProvider);
      final total = result.expenses + result.investments + result.income;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(total == 0
            ? 'No new transactions found in SMS (check SMS permission).'
            : 'Imported $total: ${result.expenses} expenses, ${result.investments} investments, ${result.income} income'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SMS scan failed. Grant SMS permission and try again.'),
      ));
    }
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
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(
                v ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),

          // Data
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('Scan SMS for transactions'),
            subtitle: const Text('Auto-import expenses & investments from bank SMS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _scanSms(context, ref),
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
