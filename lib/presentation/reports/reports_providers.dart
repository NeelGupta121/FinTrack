import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/report_service.dart';

final reportServiceProvider = Provider((_) => ReportService());

final reportsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = LocalDatabase.insights.values
      .where((e) => e['type'] == 'weekly' || e['type'] == 'monthly')
      .toList();
  items.sort((a, b) => (b['generated_at'] as String? ?? '').compareTo(a['generated_at'] as String? ?? ''));
  return items.take(20).map((e) => Map<String, dynamic>.from(e)).toList();
});

final generateReportProvider = FutureProvider.family<String, String>((ref, type) async {
  final service = ref.read(reportServiceProvider);
  if (type == 'weekly') {
    return service.generateWeeklyDigest();
  } else {
    final file = await service.generateMonthlyReport();
    return 'Report saved: ${file.path}';
  }
});
