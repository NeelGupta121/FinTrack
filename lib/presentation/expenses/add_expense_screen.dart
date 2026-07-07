import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'expense_providers.dart';
import 'widgets/category_picker.dart';
import '../../services/receipt_ocr_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? 'Enter amount' : null,
              autofocus: true,
            ),
            const SizedBox(height: 24),
            // Category
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            CategoryPicker(selected: _categoryId, onSelected: (id) => setState(() => _categoryId = id)),
            if (_categoryId == null) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Select a category', style: TextStyle(color: Colors.red, fontSize: 12))),
            const SizedBox(height: 16),
            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('EEE, d MMMM yyyy').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Receipt photo
            OutlinedButton.icon(
              onPressed: _scanReceipt,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Receipt'),
            ),
            const SizedBox(height: 24),
            // Save
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(addExpenseProvider).add(
            amount: double.parse(_amountCtrl.text),
            categoryId: _categoryId!,
            date: _date,
            description: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added ✅')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanReceipt() async {
    final data = await ReceiptOcrService.scanFromCamera();
    if (!mounted) return;
    final gotSomething =
        data != null && (data.amount != null || data.date != null || data.merchant != null);
    if (gotSomething) {
      setState(() {
        if (data.amount != null) _amountCtrl.text = data.amount!.toStringAsFixed(0);
        if (data.date != null) _date = data.date!;
      });
      if (data.merchant != null && _notesCtrl.text.isEmpty) {
        _notesCtrl.text = data.merchant!;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data.amount != null
            ? 'Scanned ₹${data.amount!.toStringAsFixed(0)} — review and save'
            : 'Partial scan — please check the fields'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't read the receipt. Enter details manually or try a clearer photo."),
      ));
    }
  }
}
