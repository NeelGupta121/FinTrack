import '../core/utils/logger.dart';
import '../data/datasources/local/local_database.dart';
import 'price_sync_service.dart';

/// Headless background market-data sync.
///
/// The Workmanager lifecycle (initialize + the single `@pragma('vm:entry-point')`
/// dispatcher) is owned by [InsightSchedulerService]; that dispatcher routes the
/// daily price-sync task here. This class only provides the job body.
class BackgroundSyncService {
  /// Runs in a fresh Workmanager isolate with NO app state, so Hive must be
  /// initialized before any box access. Never throws — a background callback
  /// that throws just produces retry/log noise.
  static Future<void> runDailyPriceSync() async {
    try {
      await LocalDatabase.init();
      final result = await PriceSyncService().syncNow();
      AppLogger.info(
        'Background price sync: ${result.updated} updated, '
        '${result.failed} failed, ${result.skipped} skipped',
        tag: 'BackgroundSync',
      );
    } catch (e, st) {
      AppLogger.error('Background price sync failed', tag: 'BackgroundSync', error: e, stackTrace: st);
    }
  }
}
