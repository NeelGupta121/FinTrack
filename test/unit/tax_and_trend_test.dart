import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/tax_saving.dart';
import 'package:fintrack/domain/usecases/spending_trend.dart';

void main() {
  group('Section80C financial year', () {
    test('April starts a new FY', () {
      expect(Section80C.fyStart(DateTime(2026, 4, 1)), DateTime(2026, 4, 1));
      expect(Section80C.fyLabel(DateTime(2026, 4, 1)), 'FY 2026-27');
    });

    test('March belongs to the FY that began the previous April', () {
      expect(Section80C.fyStart(DateTime(2026, 3, 31)), DateTime(2025, 4, 1));
      expect(Section80C.fyLabel(DateTime(2026, 3, 31)), 'FY 2025-26');
    });

    test('January is in the previous April FY', () {
      expect(Section80C.fyStart(DateTime(2027, 1, 10)), DateTime(2026, 4, 1));
    });

    test('isInCurrentFy includes 1 Apr and excludes the next 1 Apr', () {
      final now = DateTime(2026, 7, 31);
      expect(Section80C.isInCurrentFy(DateTime(2026, 4, 1), now), isTrue);
      expect(Section80C.isInCurrentFy(DateTime(2027, 3, 31), now), isTrue);
      expect(Section80C.isInCurrentFy(DateTime(2027, 4, 1), now), isFalse);
      expect(Section80C.isInCurrentFy(DateTime(2026, 3, 31), now), isFalse);
    });
  });

  group('Section80CProgress', () {
    test('reports headroom below the ceiling', () {
      final p = Section80CProgress.from(
          invested: 50000, count: 2, now: DateTime(2026, 7, 31));
      expect(p.invested, 50000);
      expect(p.remaining, 100000);
      expect(p.fraction, closeTo(1 / 3, 0.001));
      expect(p.limitReached, isFalse);
    });

    test('clamps at the ceiling and never reports negative headroom', () {
      final p = Section80CProgress.from(
          invested: 250000, count: 5, now: DateTime(2026, 7, 31));
      expect(p.remaining, 0);
      expect(p.fraction, 1.0);
      expect(p.limitReached, isTrue);
    });

    test('exactly at the limit counts as reached', () {
      final p = Section80CProgress.from(
          invested: Section80C.limit, count: 1, now: DateTime(2026, 7, 31));
      expect(p.limitReached, isTrue);
      expect(p.remaining, 0);
    });
  });

  group('SpendingTrend.lastMonths', () {
    test('returns a fixed number of buckets, oldest first, zero-filled', () {
      final series = SpendingTrend.lastMonths(
        [(date: DateTime(2026, 7, 10), amount: 500)],
        now: DateTime(2026, 7, 31),
        months: 6,
      );
      expect(series, hasLength(6));
      expect(series.first.month, DateTime(2026, 2, 1));
      expect(series.last.month, DateTime(2026, 7, 1));
      expect(series.last.total, 500);
      // Months with no spend are present with 0 (stable x-axis).
      expect(series.take(5).every((m) => m.total == 0), isTrue);
    });

    test('sums multiple entries within the same month', () {
      final series = SpendingTrend.lastMonths(
        [
          (date: DateTime(2026, 7, 1), amount: 100),
          (date: DateTime(2026, 7, 20), amount: 250),
        ],
        now: DateTime(2026, 7, 31),
        months: 3,
      );
      expect(series.last.total, 350);
    });

    test('ignores entries outside the window (older and future)', () {
      final series = SpendingTrend.lastMonths(
        [
          (date: DateTime(2025, 1, 1), amount: 9999), // far older
          (date: DateTime(2026, 9, 1), amount: 8888), // future month
          (date: DateTime(2026, 7, 5), amount: 10),
        ],
        now: DateTime(2026, 7, 31),
        months: 3,
      );
      expect(series.fold<double>(0, (s, m) => s + m.total), 10);
    });

    test('crosses a year boundary correctly', () {
      final series = SpendingTrend.lastMonths(
        [(date: DateTime(2025, 12, 15), amount: 700)],
        now: DateTime(2026, 2, 10),
        months: 4, // Nov 25, Dec 25, Jan 26, Feb 26
      );
      expect(series.first.month, DateTime(2025, 11, 1));
      expect(series[1].month, DateTime(2025, 12, 1));
      expect(series[1].total, 700);
      expect(series.last.month, DateTime(2026, 2, 1));
    });

    test('labels are short month names', () {
      final series = SpendingTrend.lastMonths(const [],
          now: DateTime(2026, 7, 31), months: 2);
      expect(series.map((m) => m.label).toList(), ['Jun', 'Jul']);
    });
  });

  group('SpendingTrend.momChangePercent', () {
    test('computes month-over-month change', () {
      final series = SpendingTrend.lastMonths(
        [
          (date: DateTime(2026, 6, 5), amount: 1000),
          (date: DateTime(2026, 7, 5), amount: 1500),
        ],
        now: DateTime(2026, 7, 31),
        months: 2,
      );
      expect(SpendingTrend.momChangePercent(series), closeTo(50, 0.001));
    });

    test('is null when the previous month was zero (undefined, not infinite)', () {
      final series = SpendingTrend.lastMonths(
        [(date: DateTime(2026, 7, 5), amount: 1500)],
        now: DateTime(2026, 7, 31),
        months: 2,
      );
      expect(SpendingTrend.momChangePercent(series), isNull);
    });

    test('is null with fewer than two months', () {
      final series = SpendingTrend.lastMonths(const [],
          now: DateTime(2026, 7, 31), months: 1);
      expect(SpendingTrend.momChangePercent(series), isNull);
    });
  });
}
