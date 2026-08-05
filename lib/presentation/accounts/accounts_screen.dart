import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/usecases/net_worth.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import '../common/widgets/empty_state.dart';
import 'accounts_providers.dart';

/// Manage cash-like accounts and debts. These balances are what turn the
/// portfolio-only view into a real net worth.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final accounts = ref.watch(accountsListProvider);
    final fmt = NumberFormat('#,##0');

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
          ? EmptyState(
              icon: Icons.account_balance,
              message: 'Add your accounts',
              detail: 'Enter bank, cash and wallet balances plus any credit-card '
                  'or loan amounts owed. FinTrack combines these with your '
                  'investments to show a real net worth.',
              actionLabel: 'Add account',
              onAction: () => _edit(context, ref),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.gutter,
                vertical: Space.lg,
              ).copyWith(bottom: 88),
              children: [
                if (assets.isNotEmpty) ...[
                  FadeSlideIn(
                    index: 0,
                    child: _SectionHeader(t, 'Assets',
                        total: assets.fold<double>(0, (s, a) => s + a.balance)),
                  ),
                  const SizedBox(height: Space.sm),
                  FadeSlideIn(
                    index: 1,
                    child: _accountGroup(context, ref, t, assets, fmt, false),
                  ),
                ],
                if (debts.isNotEmpty) ...[
                  SizedBox(height: assets.isNotEmpty ? Space.section : 0),
                  FadeSlideIn(
                    index: 2,
                    child: _SectionHeader(t, 'Owed',
                        total: debts.fold<double>(0, (s, a) => s + a.balance)),
                  ),
                  const SizedBox(height: Space.sm),
                  FadeSlideIn(
                    index: 3,
                    child: _accountGroup(context, ref, t, debts, fmt, true),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _accountGroup(BuildContext context, WidgetRef ref, AppTokens t,
      List<AccountBalance> items, NumberFormat fmt, bool isDebt) {
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
            _accountRow(context, ref, t, items[i], fmt, isDebt),
          ],
        ],
      ),
    );
  }

  Widget _accountRow(BuildContext context, WidgetRef ref, AppTokens t,
      AccountBalance a, NumberFormat fmt, bool isDebt) {
    final iconData = switch (a.kind) {
      AccountKind.bank => Icons.account_balance,
      AccountKind.cash => Icons.payments_outlined,
      AccountKind.wallet => Icons.account_balance_wallet_outlined,
      AccountKind.fd => Icons.lock_clock,
      AccountKind.creditCard => Icons.credit_card,
      AccountKind.loan => Icons.request_quote_outlined,
    };

    return InkWell(
      onTap: () => _edit(context, ref, existing: a),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.lg, vertical: Space.md + 2),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: t.panel,
                borderRadius: Radii.brSm,
              ),
              child: Icon(iconData, size: 17,
                  color: isDebt ? t.error : t.textSecondary),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a.name,
                      style: AppText.bodyText(t.textPrimary,
                          weight: FontWeight.w500)),
                  Text(a.kind.label,
                      style: AppText.caption(t.textTertiary)),
                ],
              ),
            ),
            Text(
              '${isDebt ? '−' : ''}₹${fmt.format(a.balance)}',
              style: AppText.money(
                isDebt ? t.error : t.textPrimary,
                size: 15,
              ),
            ),
            const SizedBox(width: Space.xs),
            GestureDetector(
              onTap: () => _menu(context, ref, a),
              child: Icon(Icons.more_vert, size: 20, color: t.textTertiary),
            ),
          ],
        ),
      ),
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

class _SectionHeader extends StatelessWidget {
  final AppTokens t;
  final String title;
  final double total;
  const _SectionHeader(this.t, this.title, {required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Space.xs),
        child: Row(
          children: [
            Text(title.toUpperCase(), style: AppText.micro(t.textTertiary)),
            const Spacer(),
            Text('₹${NumberFormat('#,##0').format(total)}',
                style: AppText.caption(t.textSecondary, weight: FontWeight.w500)),
          ],
        ),
      );
}
