import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  Future<String> generateWeeklyDigest() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final transactions = await _supabase
        .from('transactions')
        .select()
        .gte('date', weekAgo.toIso8601String())
        .lte('date', now.toIso8601String());

    final income = (transactions as List)
        .where((t) => (t['amount'] as num) > 0)
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
    final expenses = (transactions)
        .where((t) => (t['amount'] as num) < 0)
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble().abs());

    final digest = 'Week of ${DateFormat('MMM d').format(weekAgo)}: '
        'Income ₹${income.toStringAsFixed(0)}, '
        'Expenses ₹${expenses.toStringAsFixed(0)}, '
        'Net ₹${(income - expenses).toStringAsFixed(0)}';

    await _supabase.from('reports').insert({
      'type': 'weekly',
      'summary': digest,
      'generated_at': now.toIso8601String(),
    });

    return digest;
  }

  Future<File> generateMonthlyReport() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final transactions = await _supabase
        .from('transactions')
        .select()
        .gte('date', monthStart.toIso8601String())
        .lte('date', now.toIso8601String()) as List;

    final income = transactions
        .where((t) => (t['amount'] as num) > 0)
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
    final expenses = transactions
        .where((t) => (t['amount'] as num) < 0)
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble().abs());

    // Category breakdown
    final byCategory = <String, double>{};
    for (final tx in transactions.where((t) => (t['amount'] as num) < 0)) {
      final cat = tx['category'] as String? ?? 'Other';
      byCategory[cat] = (byCategory[cat] ?? 0) + (tx['amount'] as num).toDouble().abs();
    }

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Monthly Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text(DateFormat('MMMM yyyy').format(now)),
          pw.SizedBox(height: 20),
          pw.Text('Income: Rs ${income.toStringAsFixed(0)}'),
          pw.Text('Expenses: Rs ${expenses.toStringAsFixed(0)}'),
          pw.Text('Savings: Rs ${(income - expenses).toStringAsFixed(0)}'),
          pw.SizedBox(height: 20),
          pw.Text('Category Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...byCategory.entries.map((e) => pw.Text('  ${e.key}: Rs ${e.value.toStringAsFixed(0)}')),
        ],
      ),
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/report_${DateFormat('yyyy_MM').format(now)}.pdf');
    await file.writeAsBytes(await pdf.save());

    await _supabase.from('reports').insert({
      'type': 'monthly',
      'summary': 'Income ₹${income.toStringAsFixed(0)}, Expenses ₹${expenses.toStringAsFixed(0)}',
      'file_path': file.path,
      'generated_at': now.toIso8601String(),
    });

    return file;
  }
}
