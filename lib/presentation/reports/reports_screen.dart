import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'reports_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(generateReportProvider('weekly').future);
                      ref.invalidate(reportsListProvider);
                    },
                    icon: const Icon(Icons.summarize),
                    label: const Text('Weekly Digest'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(generateReportProvider('monthly').future);
                      ref.invalidate(reportsListProvider);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Monthly PDF'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Something went wrong. Pull down to retry.')),
              data: (reports) => reports.isEmpty
                  ? const Center(child: Text('No reports generated yet.'))
                  : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _ReportTile(report: reports[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final type = report['type'] as String;
    final date = DateTime.parse(report['generated_at'] as String);
    final summary = report['summary'] as String? ?? '';
    final filePath = report['file_path'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(type == 'weekly' ? Icons.calendar_view_week : Icons.calendar_month),
        title: Text('${type[0].toUpperCase()}${type.substring(1)} Report'),
        subtitle: Text('${DateFormat('MMM d, yyyy').format(date)}\n$summary', maxLines: 2),
        isThreeLine: true,
        trailing: filePath != null
            ? IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => Share.shareXFiles([XFile(filePath)]),
              )
            : null,
      ),
    );
  }
}
