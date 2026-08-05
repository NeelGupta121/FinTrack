import 'package:flutter/material.dart';
import '../common/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/pdf_import_service.dart';
import 'expense_providers.dart';
import 'widgets/category_picker.dart';

/// Imports transactions from a bank/credit-card statement PDF.
/// Flow: pick PDF -> extract text -> parse (Gemini, regex fallback) -> review
/// list (toggle + set category) -> bulk-save selected as `source: 'import'`.
class ImportStatementScreen extends ConsumerStatefulWidget {
  const ImportStatementScreen({super.key});

  @override
  ConsumerState<ImportStatementScreen> createState() => _ImportStatementScreenState();
}

enum _Stage { idle, working, review, importing }

class _ImportStatementScreenState extends ConsumerState<ImportStatementScreen> {
  final _service = PdfImportService();
  _Stage _stage = _Stage.idle;
  String _status = '';
  String? _error;
  List<ParsedTxn> _txns = [];

  final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  Future<void> _pickAndParse() async {
    setState(() {
      _error = null;
      _stage = _Stage.working;
      _status = 'Opening file picker…';
    });
    try {
      final path = await _service.pickPdf();
      if (path == null) {
        // User cancelled the picker.
        setState(() => _stage = _Stage.idle);
        return;
      }
      setState(() => _status = 'Reading PDF…');
      final text = await _service.extractText(path);
      setState(() => _status = 'Extracting transactions…');
      final parsed = await _service.parse(text);
      if (!mounted) return;
      if (parsed.isEmpty) {
        setState(() {
          _stage = _Stage.idle;
          _error = 'No transactions found in this statement. Try a different '
              'PDF, or add expenses manually.';
        });
        return;
      }
      setState(() {
        _txns = parsed;
        _stage = _Stage.review;
      });
    } on StatementImportException catch (e) {
      if (mounted) setState(() { _stage = _Stage.idle; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _stage = _Stage.idle; _error = 'Import failed: $e'; });
    }
  }

  Future<void> _importSelected() async {
    final selected = _txns.where((t) => t.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _stage = _Stage.importing);
    for (final t in selected) {
      final id = LocalDatabase.newId();
      await LocalDatabase.transactions.put(id, {
        'id': id,
        'amount': t.amount,
        'currency': 'INR',
        'type': t.type,
        'category_id': t.categoryId,
        'date': t.date.toIso8601String(),
        'description': t.description,
        'merchant': null,
        'source': 'import',
      });
    }
    // Rebuild expense views from the newly-imported data.
    ref.invalidate(expenseListProvider);
    ref.invalidate(monthlySummaryProvider);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${selected.length} transaction${selected.length == 1 ? '' : 's'} ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _txns.where((t) => t.selected).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Statement (PDF)'),
        actions: [
          if (_stage == _Stage.review)
            TextButton(
              onPressed: () => setState(() {
                final allOn = _txns.every((t) => t.selected);
                for (final t in _txns) {
                  t.selected = !allOn;
                }
              }),
              child: Text(_txns.every((t) => t.selected) ? 'None' : 'All'),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.idle => _buildIdle(),
        _Stage.working => _buildBusy(_status),
        _Stage.importing => _buildBusy('Importing…'),
        _Stage.review => _buildReview(),
      },
      bottomNavigationBar: _stage == _Stage.review
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: selectedCount == 0 ? null : _importSelected,
                  child: Text('Import $selectedCount selected'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildIdle() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Import from a statement PDF', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Pick a bank or credit-card statement. Transactions are extracted '
                'for you to review before anything is saved. Password-protected or '
                'scanned PDFs are not supported yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _pickAndParse,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose PDF'),
              ),
            ],
          ),
        ),
      );

  Widget _buildBusy(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(msg),
          ],
        ),
      );

  Widget _buildReview() => ListView.separated(
        itemCount: _txns.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final t = _txns[i];
          final isIncome = t.type == 'income';
          return CheckboxListTile(
            value: t.selected,
            onChanged: (v) => setState(() => t.selected = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Row(
              children: [
                Text(DateFormat('d MMM yyyy').format(t.date), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                // Compact category selector per row.
                Expanded(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: categories.any((c) => c.id == t.categoryId) ? t.categoryId : 'other',
                    underline: const SizedBox.shrink(),
                    style: Theme.of(context).textTheme.bodySmall,
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => t.categoryId = v ?? 'other'),
                  ),
                ),
              ],
            ),
            secondary: Text(
              '${isIncome ? '+' : '-'}${_currFmt.format(t.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isIncome
                    ? AppTokens.of(context).success
                    : AppTokens.of(context).textPrimary,
              ),
            ),
          );
        },
      );
}
