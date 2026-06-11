import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_key_provider.dart';
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

  Future<void> _showApiKeyDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste your API key',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Get a free key at aistudio.google.com/apikey',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(geminiKeyProvider.notifier).set(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved ✅')),
        );
      }
    }
  }

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
      String msg;
      if (!result.permissionGranted) {
        msg = 'SMS permission denied. Enable it in system Settings → Apps → FinTrack → Permissions → SMS.';
      } else if (result.error != null) {
        msg = 'Scan error: ${result.error}';
      } else if (result.scanned == 0) {
        msg = 'No SMS found on device in the last 90 days.';
      } else if (total == 0) {
        msg = 'Read ${result.scanned} SMS but none matched bank/transaction patterns.';
      } else {
        msg = 'Imported $total of ${result.scanned} SMS: ${result.expenses} expenses, ${result.investments} investments, ${result.income} income';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 6),
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

          // AI
          const _SectionHeader('AI'),
          Consumer(builder: (context, ref, _) {
            final key = ref.watch(geminiKeyProvider);
            return ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('Gemini API Key'),
              subtitle: Text(key.isEmpty ? 'Tap to set' : '••••••••'),
              trailing: key.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        await ref.read(geminiKeyProvider.notifier).clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key cleared')),
                          );
                        }
                      },
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(context, ref),
            );
          }),
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
