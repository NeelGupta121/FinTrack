import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding_provider.dart';

class SetupAccountsPage extends ConsumerStatefulWidget {
  const SetupAccountsPage({super.key});
  @override
  ConsumerState<SetupAccountsPage> createState() => _SetupAccountsPageState();
}

class _SetupAccountsPageState extends ConsumerState<SetupAccountsPage> {
  bool _scanning = false;
  int? _txCount;

  Future<void> _importSms() async {
    setState(() => _scanning = true);
    final count = await ref.read(smsImportProvider(true).future);
    setState(() { _scanning = false; _txCount = count; });
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
          if (_txCount != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Found $_txCount transactions from SMS',
                    style: theme.textTheme.titleMedium),
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: _scanning ? null : _importSms,
              icon: _scanning
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
}
