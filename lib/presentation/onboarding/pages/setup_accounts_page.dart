import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/tflite_datasource.dart';
import '../../../services/smart_import_service.dart';

final smartImportProvider = FutureProvider.family<ImportResult?, bool>((ref, run) async {
  if (!run) return null;
  final tflite = TfliteDatasource();
  await tflite.load();
  final service = SmartImportService(tflite);
  return service.scanAndImport();
});

class SetupAccountsPage extends ConsumerStatefulWidget {
  const SetupAccountsPage({super.key});
  @override
  ConsumerState<SetupAccountsPage> createState() => _SetupAccountsPageState();
}

class _SetupAccountsPageState extends ConsumerState<SetupAccountsPage> {
  bool _scanning = false;
  ImportResult? _result;

  Future<void> _importSms() async {
    setState(() => _scanning = true);
    final result = await ref.read(smartImportProvider(true).future);
    setState(() { _scanning = false; _result = result; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Set Up Accounts', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 32),
          if (_result != null) _buildResultCard(theme)
          else ...[
            FilledButton.icon(
              onPressed: _scanning ? null : _importSms,
              icon: _scanning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sms),
              label: const Text('Import from SMS History'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Account Manually'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final r = _result!;
    final total = r.expenses + r.investments + r.income;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found $total transactions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _row(Icons.shopping_cart, '${r.expenses} expenses', Colors.red),
            _row(Icons.trending_up, '${r.investments} investments', Colors.blue),
            _row(Icons.account_balance_wallet, '${r.income} salary/credits', Colors.green),
            if (r.skipped > 0) _row(Icons.skip_next, '${r.skipped} duplicates skipped', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Text(label),
    ]),
  );
}
