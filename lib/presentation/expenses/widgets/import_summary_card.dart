import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/tflite_datasource.dart';
import '../../../services/smart_import_service.dart';

final manualImportProvider = StateProvider<ImportResult?>((ref) => null);

class ImportSummaryCard extends ConsumerWidget {
  const ImportSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(manualImportProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('SMS Auto-Import', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (result != null)
              Text('Auto-imported: ${result.expenses + result.investments + result.income} new transactions')
            else
              Text('Tap to scan SMS for new transactions', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _rescan(ref),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Re-scan SMS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescan(WidgetRef ref) async {
    final tflite = TfliteDatasource();
    await tflite.load();
    final service = SmartImportService(tflite);
    final result = await service.scanAndImport();
    ref.read(manualImportProvider.notifier).state = result;
    tflite.dispose();
  }
}
