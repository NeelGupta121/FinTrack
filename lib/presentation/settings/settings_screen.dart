import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/model_config.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/backup_service.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
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

  Future<void> _exportData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.exportAndShare();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
            'This replaces your current transactions, holdings, categories, goals '
            'and accounts with the contents of the backup file. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not read the selected file')));
        return;
      }
      final result = await BackupService.importFromJsonString(utf8.decode(bytes));
      ref.invalidate(expenseListProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(monthlyBudgetProvider);
      messenger.showSnackBar(SnackBar(content: Text('Imported ${result.restored} records')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.lg,
        ),
        children: [
          // Preferences section
          FadeSlideIn(
            index: 0,
            child: _sectionLabel(t, 'PREFERENCES'),
          ),
          const SizedBox(height: Space.sm),
          FadeSlideIn(
            index: 1,
            child: _groupedCard(t, [
              _SettingsRow(
                icon: Icons.currency_rupee,
                label: 'Currency',
                trailing: Text('INR (₹)',
                    style: AppText.caption(t.textTertiary)),
              ),
              _SettingsRow(
                icon: Icons.account_balance_wallet,
                label: 'Monthly budget',
                trailing: Text(
                  '₹${ref.watch(monthlyBudgetProvider).toStringAsFixed(0)}',
                  style: AppText.caption(t.textSecondary, weight: FontWeight.w500),
                ),
                onTap: () => _editBudget(context, ref),
              ),
              _SettingsRow(
                icon: Icons.dark_mode,
                label: 'Dark Mode',
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).set(
                      v ? ThemeMode.dark : ThemeMode.light),
                ),
                onTap: () => ref.read(themeModeProvider.notifier).set(
                    themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
              ),
            ]),
          ),

          const SizedBox(height: Space.section),

          // AI section
          FadeSlideIn(
            index: 2,
            child: _sectionLabel(t, 'AI'),
          ),
          const SizedBox(height: Space.sm),
          FadeSlideIn(
            index: 3,
            child: _groupedCard(t, [
              _SettingsRow(
                icon: Icons.smart_toy_outlined,
                label: 'AI Model',
                subtitle: ref.watch(geminiModelProvider),
                onTap: () => _pickModel(context, ref),
              ),
            ]),
          ),

          const SizedBox(height: Space.section),

          // Data section
          FadeSlideIn(
            index: 4,
            child: _sectionLabel(t, 'DATA'),
          ),
          const SizedBox(height: Space.sm),
          FadeSlideIn(
            index: 5,
            child: _groupedCard(t, [
              _SettingsRow(
                icon: Icons.download_outlined,
                label: 'Export data (backup)',
                subtitle: 'Save all your data to a JSON file you can keep or share',
                onTap: () => _exportData(context),
              ),
              _SettingsRow(
                icon: Icons.upload_outlined,
                label: 'Import data (restore)',
                subtitle: 'Replace current data from a FinTrack backup file',
                onTap: () => _importData(context, ref),
              ),
            ]),
          ),

          const SizedBox(height: Space.section),

          // About section
          FadeSlideIn(
            index: 6,
            child: _sectionLabel(t, 'ABOUT'),
          ),
          const SizedBox(height: Space.sm),
          FadeSlideIn(
            index: 7,
            child: _groupedCard(t, [
              const _SettingsRow(
                icon: Icons.info_outline,
                label: 'FinTrack',
                subtitle: 'v0.1.0 • AI-powered finance tracker',
              ),
              _SettingsRow(
                icon: Icons.code,
                label: 'Open Source Licenses',
                onTap: () => showLicensePage(context: context, applicationName: 'FinTrack'),
              ),
            ]),
          ),

          const SizedBox(height: Space.xxl),
        ],
      ),
    );
  }

  Widget _sectionLabel(AppTokens t, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: Space.xs),
      child: Text(title, style: AppText.micro(t.textTertiary)),
    );
  }

  Widget _groupedCard(AppTokens t, List<_SettingsRow> items) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(height: 1, color: t.borderSubtle),
              ),
            _buildRow(t, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(AppTokens t, _SettingsRow row) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.lg, vertical: Space.md + 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: t.panel, borderRadius: Radii.brSm),
            child: Icon(row.icon, size: 17, color: t.textSecondary),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(row.label,
                    style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500)),
                if (row.subtitle != null)
                  Text(row.subtitle!,
                      style: AppText.caption(t.textTertiary)),
              ],
            ),
          ),
          if (row.trailing != null)
            row.trailing!
          else if (row.onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );

    if (row.onTap != null) {
      return InkWell(onTap: row.onTap, child: content);
    }
    return content;
  }
}

class _SettingsRow {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}
