import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/report_service.dart';

final reportServiceProvider = Provider((_) => ReportService());

final reportsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('reports')
      .select()
      .order('generated_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(response as List);
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
