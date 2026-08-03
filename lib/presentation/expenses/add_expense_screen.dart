import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'expense_providers.dart';
import '../../domain/entities/transaction.dart';
import 'widgets/category_picker.dart';
import '../../services/receipt_ocr_service.dart';
import '../../core/utils/logger.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final bool autoScan;

  /// When non-null the screen edits this transaction in place instead of
  /// creating a new one. Its id and source are preserved.
  final Transaction? existing;

  const AddExpenseScreen({super.key, this.autoScan = false, this.existing});

  bool get isEditing => existing != null;

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
  /// 'expense' or 'income' — manual entry supports both (income was previously
  /// only creatable via PDF statement import).
  String _type = 'expense';

  bool get _isIncome => _type == 'income';

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      // Edit mode — prefill from the stored transaction.
      _amountCtrl.text = ex.amount.toStringAsFixed(
          ex.amount == ex.amount.roundToDouble() ? 0 : 2);
      _notesCtrl.text = ex.description ?? '';
      _categoryId = ex.categoryId;
      _date = ex.date;
      _type = ex.type == 'income' ? 'income' : 'expense';
    }
    if (widget.autoScan) {
      // Launched from the dashboard "Scan" action — open the camera immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanReceipt();
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.isEditing ? 'Edit' : 'Add'} ${_isIncome ? 'Income' : 'Expense'}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Expense vs Income — manual entry supports both.
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward, size: 16)),
                ButtonSegment(
                    value: 'income',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
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
              onPressed: _showScanOptions,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Receipt / Screenshot'),
            ),
            const SizedBox(height: 24),
            // Save
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.isEditing ? 'Save changes' : (_isIncome ? 'Save Income' : 'Save Expense')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Validate the amount field first (shows inline error under the field).
    final amountValid = _formKey.currentState!.validate();
    // Category is required but lives outside the Form — surface it explicitly
    // instead of silently returning (which made Save look like it did nothing).
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category first')),
      );
      return;
    }
    if (!amountValid) return;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(addExpenseProvider);
      final amount = double.parse(_amountCtrl.text);
      final notes = _notesCtrl.text.isEmpty ? null : _notesCtrl.text;
      if (widget.isEditing) {
        await notifier.update(
          id: widget.existing!.id,
          amount: amount,
          categoryId: _categoryId!,
          date: _date,
          description: notes,
          merchant: widget.existing!.merchant,
          type: _type,
        );
      } else {
        await notifier.add(
          amount: amount,
          categoryId: _categoryId!,
          date: _date,
          description: notes,
          type: _type,
        );
      }
      if (mounted) {
        final noun = _isIncome ? 'Income' : 'Expense';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.isEditing ? '$noun updated ✅' : '$noun added ✅')));
        Navigator.pop(context);
      }
    } catch (e, st) {
      // Never swallow the failure — the missing catch is why a save error
      // looked like a dead button (spinner flashed, nothing else happened).
      AppLogger.error('Failed to save transaction', tag: 'Expenses', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pick a screenshot / image'),
              subtitle: const Text('e.g. a payment confirmation from your gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(fromGallery: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanReceipt({bool fromGallery = false}) async {
    final data = fromGallery
        ? await ReceiptOcrService.scanFromGallery()
        : await ReceiptOcrService.scanFromCamera();
    if (!mounted) return;
    if (data == null) return; // user cancelled the camera — no nagging
    final gotSomething = data.amount != null || data.date != null || data.merchant != null;
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
