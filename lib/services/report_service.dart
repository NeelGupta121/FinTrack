import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/local_database.dart';

class ReportService {
  Future<String> generateWeeklyDigest() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final transactions = LocalDatabase.transactions.values
        .where((t) {
          final d = DateTime.parse(t['date'] as String);
          return d.isAfter(weekAgo) && d.isBefore(now.add(const Duration(days: 1)));
        })
        .toList();

    final income = transactions
        .where((t) => t['type'] == 'income')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
    final expenses = transactions
        .where((t) => t['type'] == 'expense')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());

    final digest = 'Week of ${DateFormat('MMM d').format(weekAgo)}: '
        'Income ₹${income.toStringAsFixed(0)}, '
        'Expenses ₹${expenses.toStringAsFixed(0)}, '
        'Net ₹${(income - expenses).toStringAsFixed(0)}';

    final id = LocalDatabase.newId();
    await LocalDatabase.insights.put(id, {
      'id': id,
      'type': 'weekly',
      'summary': digest,
      'generated_at': now.toIso8601String(),
    });

    return digest;
  }

  Future<File> generateMonthlyReport() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final transactions = LocalDatabase.transactions.values
        .where((t) {
          final d = DateTime.parse(t['date'] as String);
          return d.isAfter(monthStart.subtract(const Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 1)));
        })
        .toList();

    final income = transactions
        .where((t) => t['type'] == 'income')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
    final expenses = transactions
        .where((t) => t['type'] == 'expense')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());

    final byCategory = <String, double>{};
    for (final tx in transactions.where((t) => t['type'] == 'expense')) {
      final cat = (tx['category_id'] as String?) ?? 'Other';
      byCategory[cat] = (byCategory[cat] ?? 0) + (tx['amount'] as num).toDouble();
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

    return file;
  }
}
