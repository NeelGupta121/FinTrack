import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/network/rate_limiter.dart';

void main() {
  late RateLimiter limiter;

  setUp(() => limiter = RateLimiter());

  group('RateLimiter', () {
    test('allows calls within daily limit', () async {
      for (int i = 0; i < 3; i++) {
        final result = await limiter.execute('api', 5, () async => i);
        expect(result, i);
      }
    });

    test('throws RateLimitExceeded when limit reached', () async {
      for (int i = 0; i < 3; i++) {
        await limiter.execute('api', 3, () async => i);
      }
      expect(
        () => limiter.execute('api', 3, () async => 'nope'),
        throwsA(isA<RateLimitExceeded>()),
      );
    });

    test('multiple keys are independent', () async {
      for (int i = 0; i < 2; i++) {
        await limiter.execute('key_a', 2, () async => i);
      }
      // key_a exhausted, key_b still works
      expect(
        () => limiter.execute('key_a', 2, () async => 'fail'),
        throwsA(isA<RateLimitExceeded>()),
      );
      final result = await limiter.execute('key_b', 2, () async => 'ok');
      expect(result, 'ok');
    });

    test('executes the provided function and returns result', () async {
      final result = await limiter.execute('k', 10, () async => 42);
      expect(result, 42);
    });

    test('persists count across instances (survives restart)', () async {
      final store = _FakeRateLimitStore();
      final before = RateLimiter(store: store);
      await before.execute('api', 3, () async => 1);
      await before.execute('api', 3, () async => 1);

      // A fresh limiter sharing the same store simulates an app restart.
      final after = RateLimiter(store: store);
      await after.execute('api', 3, () async => 1); // 3rd call still allowed
      expect(
        () => after.execute('api', 3, () async => 'nope'),
        throwsA(isA<RateLimitExceeded>()),
      );
    });

    test('does not charge failed calls against the quota', () async {
      final l = RateLimiter();
      for (var i = 0; i < 5; i++) {
        try {
          await l.execute('flaky', 3, () async => throw Exception('boom'));
        } catch (_) {}
      }
      // All 5 failed -> quota untouched -> 3 successful calls still allowed.
      for (var i = 0; i < 3; i++) {
        expect(await l.execute('flaky', 3, () async => 'ok'), 'ok');
      }
    });
  });
}

/// In-memory [RateLimitStore] for tests — simulates persisted storage.
class _FakeRateLimitStore implements RateLimitStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Map<String, dynamic>? read(String key) => _data[key];

  @override
  void write(String key, Map<String, dynamic> value) => _data[key] = value;
}
