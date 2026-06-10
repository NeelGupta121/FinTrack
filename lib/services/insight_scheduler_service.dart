import 'package:workmanager/workmanager.dart';

const _taskDaily = 'com.fintrack.dailyInsights';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskDaily) {
      await InsightSchedulerService._runDailyAnalysis();
    }
    return true;
  });
}

class InsightSchedulerService {
  static Future<void> scheduleDaily() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      _taskDaily,
      _taskDaily,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> _runDailyAnalysis() async {
    // In production: instantiate datasources, run anomaly detection,
    // fetch news + sentiment, save results to Supabase insights table.
    // This runs headless via Workmanager — no UI context available.
  }
}
