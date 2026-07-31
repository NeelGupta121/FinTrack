import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/local/local_database.dart';
import 'investment_providers.dart';

class AddHoldingScreen extends ConsumerStatefulWidget {
  const AddHoldingScreen({super.key});

  @override
  ConsumerState<AddHoldingScreen> createState() => _AddHoldingScreenState();
}

class _AddHoldingScreenState extends ConsumerState<AddHoldingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbolCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _type = 'stock';
  DateTime _purchaseDate = DateTime.now();
  String? _accountId;
  bool _section80c = false;
  List<Map<String, dynamic>> _accounts = [];
  bool _saving = false;

  static const _types = ['stock', 'mutual_fund', 'etf', 'bond', 'gold'];
  static const _typeLabels = {'stock': 'Stock', 'mutual_fund': 'Mutual Fund', 'etf': 'ETF', 'bond': 'Bond', 'gold': 'Gold'};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final data = LocalDatabase.accounts.values.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() => _accounts = data);
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(addHoldingProvider).add(
        symbol: _symbolCtrl.text.trim().toUpperCase(),
        name: _nameCtrl.text.trim(),
        type: _type,
        quantity: double.parse(_qtyCtrl.text),
        avgPrice: double.parse(_priceCtrl.text),
        purchaseDate: _purchaseDate,
        accountId: _accountId,
        section80c: _section80c,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Holding added ✅')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Holding')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _symbolCtrl,
              decoration: const InputDecoration(labelText: 'Symbol', hintText: 'e.g. RELIANCE, 119551'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Reliance Industries'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabels[t] ?? t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => v == null || double.tryParse(v) == null || double.parse(v) <= 0 ? 'Enter valid quantity' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Average Buy Price (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => v == null || double.tryParse(v) == null || double.parse(v) <= 0 ? 'Enter valid price' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase Date'),
              subtitle: Text(DateFormat('d MMM yyyy').format(_purchaseDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _purchaseDate = picked);
              },
            ),
            const SizedBox(height: 12),
            if (_accounts.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(labelText: 'Account/Broker'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._accounts.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String))),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _section80c,
              onChanged: (v) => setState(() => _section80c = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Tax-saving (Section 80C)'),
              subtitle: const Text(
                  'Counts toward the ₹1.5L 80C deduction for this financial year '
                  '(e.g. ELSS, PPF, NPS, tax-saver FD)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
