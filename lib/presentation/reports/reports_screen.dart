import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../common/theme/app_theme.dart';
import '../common/theme/app_animations.dart';
import '../common/widgets/empty_state.dart';
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
            padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
              vertical: Space.lg,
            ),
            child: FadeSlideIn(
              index: 0,
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
                  const SizedBox(width: Space.md),
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
          ),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(
                icon: Icons.error_outline,
                message: 'Something went wrong. Pull down to retry.',
              ),
              data: (reports) => reports.isEmpty
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      message: 'No reports generated yet.',
                      detail: 'Generate a weekly or monthly report to see it here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ).copyWith(bottom: Space.xxl),
                      itemCount: reports.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        index: i + 1,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: i == 0 ? 0 : Space.sm,
                          ),
                          child: _ReportTile(report: reports[i]),
                        ),
                      ),
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
    final t = context.tokens;
    final type = report['type'] as String;
    final date = DateTime.parse(report['generated_at'] as String);
    final summary = report['summary'] as String? ?? '';
    final filePath = report['file_path'] as String?;

    final iconData = type == 'weekly'
        ? Icons.calendar_view_week
        : Icons.calendar_month;

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: Radii.brMd,
        border: Border.all(color: t.borderStandard),
        boxShadow: t.cardShadow,
      ),
      child: InkWell(
        borderRadius: Radii.brMd,
        onTap: filePath != null
            ? () => Share.shareXFiles([XFile(filePath)])
            : null,
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
                child: Icon(iconData, size: 17, color: t.textSecondary),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${type[0].toUpperCase()}${type.substring(1)} Report',
                      style: AppText.bodyText(t.textPrimary,
                          weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy').format(date),
                      style: AppText.caption(t.textTertiary),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: AppText.caption(t.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (filePath != null)
                Icon(Icons.share_outlined, size: 20, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
