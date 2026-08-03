import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/usecases/net_worth.dart';
import 'accounts_providers.dart';

/// Manage cash-like accounts and debts. These balances are what turn the
/// portfolio-only view into a real net worth.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsListProvider);
    final fmt = NumberFormat('#,##0');
    final cs = Theme.of(context).colorScheme;

    final assets = accounts.where((a) => !a.isLiability).toList();
    final debts = accounts.where((a) => a.isLiability).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Debts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance, size: 48, color: cs.primary),
                    const SizedBox(height: 16),
                    Text('Add your accounts',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Enter bank, cash and wallet balances plus any credit-card '
                      'or loan amounts owed. FinTrack combines these with your '
                      'investments to show a real net worth.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (assets.isNotEmpty) ...[
                  _Header('Assets', total: assets.fold<double>(0, (s, a) => s + a.balance)),
                  ...assets.map((a) => _row(context, ref, a, fmt, cs, false)),
                ],
                if (debts.isNotEmpty) ...[
                  _Header('Owed', total: debts.fold<double>(0, (s, a) => s + a.balance)),
                  ...debts.map((a) => _row(context, ref, a, fmt, cs, true)),
                ],
              ],
            ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AccountBalance a,
      NumberFormat fmt, ColorScheme cs, bool isDebt) {
    return ListTile(
      leading: Icon(
        switch (a.kind) {
          AccountKind.bank => Icons.account_balance,
          AccountKind.cash => Icons.payments_outlined,
          AccountKind.wallet => Icons.account_balance_wallet_outlined,
          AccountKind.fd => Icons.lock_clock,
          AccountKind.creditCard => Icons.credit_card,
          AccountKind.loan => Icons.request_quote_outlined,
        },
        color: isDebt ? cs.error : cs.primary,
      ),
      title: Text(a.name),
      subtitle: Text(a.kind.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isDebt ? '−' : ''}₹${fmt.format(a.balance)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDebt ? cs.error : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _menu(context, ref, a),
          ),
        ],
      ),
      onTap: () => _edit(context, ref, existing: a),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, AccountBalance a) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') return _edit(context, ref, existing: a);
    if (action == 'delete') {
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(accountsNotifierProvider).delete(a.id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${a.name}')));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {AccountBalance? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final balCtrl =
        TextEditingController(text: existing == null ? '' : existing.balance.toStringAsFixed(0));
    var kind = existing?.kind ?? AccountKind.bank;
    var corrects = false;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add account' : 'Edit account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name (e.g. HDFC Savings)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountKind>(
                  value: kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final k in AccountKind.values)
                      DropdownMenuItem(
                        value: k,
                        child: Text('${k.label}${k.isLiability ? '  (owed)' : ''}'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => kind = v ?? AccountKind.bank),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: kind.isLiability ? 'Amount owed' : 'Current balance',
                    prefixText: '₹ ',
                    helperText: kind.isLiability
                        ? 'Enter a positive amount — it is subtracted automatically'
                        : null,
                  ),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: corrects,
                    onChanged: (v) => setLocal(() => corrects = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text("I'm correcting a mistake"),
                    subtitle: const Text(
                        'Clears the net-worth trend, because past readings used the wrong balance'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final balance = double.tryParse(balCtrl.text.trim());
    nameCtrl.dispose();
    balCtrl.dispose();
    if (saved != true) return;

    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an account name')));
      return;
    }
    if (balance == null || balance < 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid amount (0 or more)')));
      return;
    }
    await ref
        .read(accountsNotifierProvider)
        .upsert(id: existing?.id, name: name, kind: kind, balance: balance, correctsPastData: corrects);
    messenger.showSnackBar(SnackBar(content: Text('Saved $name')));
  }
}

class _Header extends StatelessWidget {
  final String title;
  final double total;
  const _Header(this.title, {required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Row(
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('₹${NumberFormat('#,##0').format(total)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
