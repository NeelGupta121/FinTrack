import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// Thrown when a per-key daily quota is exhausted.
class RateLimitExceeded implements Exception {
  final String message;
  RateLimitExceeded(this.message);

  @override
  String toString() => 'RateLimitExceeded: $message';
}

/// Persistence backend for rate-limit counters. Lets the limiter survive app
/// restarts (Hive-backed in production) while staying purely in-memory in unit
/// tests (no store / Hive not initialised).
abstract class RateLimitStore {
  Map<String, dynamic>? read(String key);
  void write(String key, Map<String, dynamic> value);
}

/// Hive-backed store. No-ops gracefully when the box isn't open (e.g. in unit
/// tests that never call Hive.initFlutter), so the limiter falls back to
/// in-memory counting instead of crashing.
class HiveRateLimitStore implements RateLimitStore {
  static const boxName = 'rate_limits';

  @override
  Map<String, dynamic>? read(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final raw = Hive.box(boxName).get(key);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  void write(String key, Map<String, dynamic> value) {
    if (!Hive.isBoxOpen(boxName)) return; // Hive not ready -> in-memory only
    Hive.box(boxName).put(key, value);
  }
}

/// Per-key daily rate limiter with a rolling 24h window.
///
/// Counts are persisted via [RateLimitStore] so a real upstream quota
/// (Alpha Vantage 25/day, Gemini 1000/day, NewsAPI 100/day) is not silently
/// reset every time the app restarts. Only successful calls are counted.
class RateLimiter {
  final Map<String, _Bucket> _buckets = {};
  final RateLimitStore _store;

  RateLimiter({RateLimitStore? store}) : _store = store ?? HiveRateLimitStore();

  Future<T> execute<T>(String key, int maxPerDay, Future<T> Function() fn) async {
    final bucket = _bucketFor(key, maxPerDay);
    bucket.ensureAvailable(); // reset-if-elapsed + throw-if-exhausted (does NOT count)
    final result = await fn(); // a throwing call is not charged to the quota
    bucket.commit(); // count only successful calls
    _store.write(key, bucket.toMap()); // persist so the count survives restarts
    return result;
  }

  _Bucket _bucketFor(String key, int maxPerDay) {
    return _buckets.putIfAbsent(key, () {
      final bucket = _Bucket(maxPerDay);
      bucket.hydrate(_store.read(key)); // restore persisted count/window if present
      return bucket;
    });
  }
}

class _Bucket {
  final int maxPerDay;
  int _count = 0;
  DateTime _resetAt = DateTime.now().add(const Duration(days: 1));

  _Bucket(this.maxPerDay);

  void hydrate(Map<String, dynamic>? saved) {
    if (saved == null) return;
    _count = (saved['count'] as num?)?.toInt() ?? 0;
    _resetAt = DateTime.tryParse('${saved['resetAt']}') ?? _resetAt;
  }

  Map<String, dynamic> toMap() => {
        'count': _count,
        'resetAt': _resetAt.toIso8601String(),
      };

  /// Reset the daily window if elapsed and throw if the quota is exhausted.
  /// Does NOT increment — call [commit] only after the guarded call succeeds.
  void ensureAvailable() {
    if (DateTime.now().isAfter(_resetAt)) {
      _count = 0;
      _resetAt = DateTime.now().add(const Duration(days: 1));
      AppLogger.debug('Rate limiter bucket reset', tag: 'RateLimiter');
    }
    if (_count >= maxPerDay) {
      AppLogger.warning('Rate limit reached: $maxPerDay/day', tag: 'RateLimiter');
      throw RateLimitExceeded('$maxPerDay/day limit reached');
    }
  }

  void commit() => _count++;
}
