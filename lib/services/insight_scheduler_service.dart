import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../data/datasources/local/local_database.dart';
import '../domain/entities/transaction.dart';
import '../domain/usecases/analyze_spending.dart';
import '../core/utils/logger.dart';
import 'background_sync_service.dart';

const _taskDaily = 'com.fintrack.dailyInsights';
const _taskPriceSync = 'com.fintrack.dailyPriceSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Headless background isolate: initialize the binding and register plugins
    // so path_provider (used by Hive.initFlutter) works. Without this, plugin
    // method channels are unregistered in the isolate.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    // Single OS entrypoint for ALL periodic jobs — route by task name.
    if (task == _taskDaily) {
      await InsightSchedulerService._runDailyAnalysis();
    } else if (task == _taskPriceSync) {
      await BackgroundSyncService.runDailyPriceSync();
    }
    return true;
  });
}

class InsightSchedulerService {
  /// Registers all periodic background jobs (daily insight analysis + daily
  /// market-price sync). Called once at startup (main.dart, non-web).
  /// Initializes Workmanager exactly once with the shared [callbackDispatcher].
  static Future<void> scheduleDaily() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      _taskDaily,
      _taskDaily,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    // Daily market-price/NAV refresh so P&L updates even without opening the app.
    await Workmanager().registerPeriodicTask(
      _taskPriceSync,
      _taskPriceSync,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> _runDailyAnalysis() async {
    // Runs headless in a fresh Workmanager isolate — NO app state is available,
    // so Hive must be initialized here before any box access.
    try {
      await LocalDatabase.init();

      final txns = LocalDatabase.transactions.values.map((e) {
        final m = Map<String, dynamic>.from(e);
        return Transaction(
          id: m['id'] as String? ?? '',
          amount: (m['amount'] as num? ?? 0).toDouble(),
          type: m['type'] as String? ?? 'expense',
          description: m['description'] as String?,
          merchant: m['merchant'] as String?,
          date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime(2000),
          categoryId: m['category_id'] as String?,
          source: m['source'] as String? ?? 'manual',
        );
      }).toList();

      final anomalies = AnalyzeSpendingUseCase().detectAnomalies(txns);

      // Persist a lightweight daily insight record (idempotent per day).
      final day = DateTime.now().toIso8601String().substring(0, 10);
      await LocalDatabase.insights.put('daily_$day', {
        'id': 'daily_$day',
        'type': 'daily_analysis',
        'generated_at': DateTime.now().toIso8601String(),
        'anomaly_count': anomalies.length,
        'top_categories': anomalies.take(3).map((a) => a.category).toList(),
      });
      AppLogger.info('Daily insight analysis complete: ${anomalies.length} anomalies',
          tag: 'InsightScheduler');
    } catch (e, st) {
      // Headless: never throw out of the callback (would just retry/log noise).
      AppLogger.error('Daily insight analysis failed', tag: 'InsightScheduler', error: e, stackTrace: st);
    }
  }
}
