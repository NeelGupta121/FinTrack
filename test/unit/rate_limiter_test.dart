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
  });
}
