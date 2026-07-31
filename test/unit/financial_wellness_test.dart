import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/financial_wellness.dart';

void main() {
  group('daysLeftInMonth', () {
    test('counts today as remaining', () {
      // 15 Jan -> 31-15+1 = 17
      expect(FinancialWellness.daysLeftInMonth(DateTime(2026, 1, 15)), 17);
    });

    test('last day of month leaves 1', () {
      expect(FinancialWellness.daysLeftInMonth(DateTime(2026, 1, 31)), 1);
    });

    test('handles February in a leap year', () {
      expect(FinancialWellness.daysLeftInMonth(DateTime(2024, 2, 1)), 29);
    });
  });

  group('safeToSpend', () {
    test('splits the remainder across days left', () {
      final s = FinancialWellness.safeToSpend(
        budget: 30000,
        spent: 10000,
        now: DateTime(2026, 1, 21), // 11 days left
      );
      expect(s.remaining, 20000);
      expect(s.daysLeft, 11);
      expect(s.perDay, closeTo(20000 / 11, 0.001));
      expect(s.overBudget, isFalse);
      expect(s.overspentBy, 0);
    });

    test('clamps at zero and reports the overspend when past budget', () {
      final s = FinancialWellness.safeToSpend(
        budget: 10000,
        spent: 12500,
        now: DateTime(2026, 1, 15),
      );
      expect(s.remaining, 0);
      expect(s.perDay, 0);
      expect(s.overBudget, isTrue);
      expect(s.overspentBy, 2500);
    });

    test('zero budget is treated as fully spent, not a crash', () {
      final s = FinancialWellness.safeToSpend(
        budget: 0,
        spent: 0,
        now: DateTime(2026, 1, 15),
      );
      expect(s.remaining, 0);
      expect(s.overBudget, isFalse);
    });
  });

  group('healthScore', () {
    test('rewards on-pace spending, healthy savings and diversification', () {
      final h = FinancialWellness.healthScore(
        budget: 30000,
        spentThisMonth: 5000, // well under pace
        incomeThisMonth: 100000, // 95% kept -> caps savings score
        holdingValueByType: const {'stock': 40000, 'mutual_fund': 40000, 'gold': 20000},
        now: DateTime(2026, 1, 15),
      );
      expect(h.score, 100);
      expect(h.band, 'Excellent');
      expect(h.factors, hasLength(3));
    });

    test('scores zero and stays finite with no data at all', () {
      final h = FinancialWellness.healthScore(
        budget: 0,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        holdingValueByType: const {},
        now: DateTime(2026, 1, 15),
      );
      expect(h.score, 0);
      // Each factor should explain that data is missing rather than be blank.
      for (final f in h.factors) {
        expect(f.detail, isNotEmpty);
        expect(f.score, 0);
        expect(f.scoreable, isFalse);
      }
      // No usable signals -> the score must not be presented as meaningful.
      expect(h.hasEnoughData, isFalse);
      expect(h.scoreableCount, 0);
    });

    test('a budget alone is not enough data to show a score', () {
      // Regression: a brand-new user with only a default budget previously
      // rendered "40/100 - Needs work", punishing them for not entering data.
      final h = FinancialWellness.healthScore(
        budget: 50000,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        holdingValueByType: const {},
        now: DateTime(2026, 1, 15),
      );
      expect(h.scoreableCount, 1);
      expect(h.hasEnoughData, isFalse);
    });

    test('two usable signals are enough to show a score', () {
      final h = FinancialWellness.healthScore(
        budget: 50000,
        spentThisMonth: 10000,
        incomeThisMonth: 80000,
        holdingValueByType: const {},
        now: DateTime(2026, 1, 15),
      );
      expect(h.scoreableCount, 2);
      expect(h.hasEnoughData, isTrue);
    });

    test('penalises heavy overspending on budget pace', () {
      final h = FinancialWellness.healthScore(
        budget: 10000,
        spentThisMonth: 20000, // 200% of budget
        incomeThisMonth: 0,
        holdingValueByType: const {},
        now: DateTime(2026, 1, 2),
      );
      final pace = h.factors.firstWhere((f) => f.label == 'Budget pace');
      expect(pace.score, 0);
    });

    test('negative savings rate scores zero, never negative', () {
      final h = FinancialWellness.healthScore(
        budget: 50000,
        spentThisMonth: 60000, // spent more than earned
        incomeThisMonth: 40000,
        holdingValueByType: const {},
        now: DateTime(2026, 1, 15),
      );
      final savings = h.factors.firstWhere((f) => f.label == 'Savings rate');
      expect(savings.score, 0);
      expect(h.score, greaterThanOrEqualTo(0));
    });

    test('single concentrated asset type gets no balanced bonus', () {
      final h = FinancialWellness.healthScore(
        budget: 30000,
        spentThisMonth: 1000,
        incomeThisMonth: 50000,
        holdingValueByType: const {'stock': 100000},
        now: DateTime(2026, 1, 15),
      );
      final div = h.factors.firstWhere((f) => f.label == 'Diversification');
      expect(div.score, 7); // 1 type * 7, no <=70% bonus
    });
  });
}
