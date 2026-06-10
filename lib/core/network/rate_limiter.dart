/// Per-key rate limiter with daily reset.
class RateLimitExceeded implements Exception {
  final String message;
  RateLimitExceeded(this.message);

  @override
  String toString() => 'RateLimitExceeded: $message';
}

class RateLimiter {
  final Map<String, _Bucket> _buckets = {};

  Future<T> execute<T>(String key, int maxPerDay, Future<T> Function() fn) async {
    final bucket = _buckets.putIfAbsent(key, () => _Bucket(maxPerDay));
    bucket.acquire();
    return fn();
  }
}

class _Bucket {
  final int maxPerDay;
  int _count = 0;
  DateTime _resetAt = DateTime.now().add(const Duration(days: 1));

  _Bucket(this.maxPerDay);

  void acquire() {
    if (DateTime.now().isAfter(_resetAt)) {
      _count = 0;
      _resetAt = DateTime.now().add(const Duration(days: 1));
    }
    if (_count >= maxPerDay) {
      throw RateLimitExceeded('$maxPerDay/day limit reached');
    }
    _count++;
  }
}
