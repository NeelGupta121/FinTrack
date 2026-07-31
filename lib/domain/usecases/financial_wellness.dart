import 'dart:math';

/// "In My Pocket" — how much is genuinely free to spend for the rest of the
/// month, plus a per-day allowance. Derived from the user's configured monthly
/// budget minus what they have already spent this month.
class SafeToSpend {
  /// Amount left in the budget for the rest of the month (never negative).
  final double remaining;

  /// How much can be spent per day for the rest of the month.
  final double perDay;

  /// Days left in the month, including today.
  final int daysLeft;

  /// True when spending has already exceeded the monthly budget.
  final bool overBudget;

  /// How far past the budget the user is (0 when within budget).
  final double overspentBy;

  const SafeToSpend({
    required this.remaining,
    required this.perDay,
    required this.daysLeft,
    required this.overBudget,
    required this.overspentBy,
  });
}

/// A single scored component of the financial health score.
class HealthFactor {
  final String label;
  final int score;
  final int maxScore;
  final String detail;

  /// False when there isn't enough data to judge this factor (e.g. no income
  /// logged). Unscoreable factors must not be read as "bad", only as "unknown".
  final bool scoreable;

  const HealthFactor({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.detail,
    this.scoreable = true,
  });
}

/// Overall financial health: a single 0-100 number plus its breakdown, so the
/// user can see *why* the score is what it is (and what to improve).
class HealthScore {
  final int score;
  final List<HealthFactor> factors;

  const HealthScore({required this.score, required this.factors});

  /// How many factors had enough data to be judged.
  int get scoreableCount => factors.where((f) => f.scoreable).length;

  /// A score built from a single signal is not a meaningful health reading —
  /// it would either flatter or punish a user who has simply not entered data
  /// yet. Require at least two of the three signals before showing a number.
  bool get hasEnoughData => scoreableCount >= 2;

  /// Plain-language band for the score.
  String get band {
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 45) return 'Fair';
    return 'Needs work';
  }
}

/// Pure calculations for the wellness widgets. No storage or Flutter imports so
/// this is directly unit-testable.
class FinancialWellness {
  /// Days remaining in [now]'s month, counting today.
  static int daysLeftInMonth(DateTime now) {
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return max(1, lastDay - now.day + 1);
  }

  /// Computes the safe-to-spend figure. [budget] and [spent] are for the
  /// current month.
  static SafeToSpend safeToSpend({
    required double budget,
    required double spent,
    required DateTime now,
  }) {
    final daysLeft = daysLeftInMonth(now);
    final rawRemaining = budget - spent;
    final over = rawRemaining < 0;
    final remaining = over ? 0.0 : rawRemaining;
    return SafeToSpend(
      remaining: remaining,
      perDay: remaining / daysLeft,
      daysLeft: daysLeft,
      overBudget: over,
      overspentBy: over ? -rawRemaining : 0,
    );
  }

  /// Rule-based 0-100 health score from three locally-computable signals:
  /// budget pace (40), savings rate (30) and portfolio diversification (30).
  ///
  /// [holdingValueByType] maps an investment type (stock, mutual_fund, ...) to
  /// its total value, used to reward spreading money across asset types.
  static HealthScore healthScore({
    required double budget,
    required double spentThisMonth,
    required double incomeThisMonth,
    required Map<String, double> holdingValueByType,
    required DateTime now,
  }) {
    final factors = <HealthFactor>[];

    // 1. Budget pace (40 pts) — are you spending faster than the month elapses?
    if (budget <= 0) {
      factors.add(const HealthFactor(
          label: 'Budget pace',
          score: 0,
          maxScore: 40,
          detail: 'Set a monthly budget to score this',
          scoreable: false));
    } else {
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final monthElapsed = now.day / lastDay; // 0..1
      final budgetUsed = spentThisMonth / budget;
      // Spending at or below the elapsed fraction of the month = full marks.
      final int paceScore;
      if (budgetUsed <= monthElapsed) {
        paceScore = 40;
      } else if (budgetUsed >= 1.5) {
        paceScore = 0;
      } else {
        // Linear taper from on-pace to 150% of budget.
        final overshoot = (budgetUsed - monthElapsed) / max(0.01, 1.5 - monthElapsed);
        paceScore = (40 * (1 - overshoot)).round().clamp(0, 40);
      }
      factors.add(HealthFactor(
        label: 'Budget pace',
        score: paceScore,
        maxScore: 40,
        detail: '${(budgetUsed * 100).round()}% of budget used, '
            '${(monthElapsed * 100).round()}% through the month',
      ));
    }

    // 2. Savings rate (30 pts) — 20% saved is the classic healthy target.
    if (incomeThisMonth <= 0) {
      factors.add(const HealthFactor(
          label: 'Savings rate',
          score: 0,
          maxScore: 30,
          detail: 'Log income to score this',
          scoreable: false));
    } else {
      final rate = (incomeThisMonth - spentThisMonth) / incomeThisMonth; // may be negative
      final int savingsScore = rate <= 0 ? 0 : (30 * min(1.0, rate / 0.20)).round().clamp(0, 30);
      factors.add(HealthFactor(
        label: 'Savings rate',
        score: savingsScore,
        maxScore: 30,
        detail: '${(rate * 100).round()}% of income kept this month',
      ));
    }

    // 3. Diversification (30 pts) — reward >=3 asset types and no single type
    // dominating more than 70% of the portfolio.
    final total = holdingValueByType.values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) {
      factors.add(const HealthFactor(
          label: 'Diversification',
          score: 0,
          maxScore: 30,
          detail: 'Add investments to score this',
          scoreable: false));
    } else {
      final typeCount = holdingValueByType.entries.where((e) => e.value > 0).length;
      final largestShare = holdingValueByType.values.reduce(max) / total;
      var divScore = min(20, typeCount * 7); // 1 type=7, 2=14, 3+=20
      if (largestShare <= 0.70) divScore += 10; // balanced bonus
      factors.add(HealthFactor(
        label: 'Diversification',
        score: divScore.clamp(0, 30),
        maxScore: 30,
        detail: '$typeCount asset ${typeCount == 1 ? 'type' : 'types'}, '
            'largest ${(largestShare * 100).round()}%',
      ));
    }

    final total0to100 = factors.fold<int>(0, (s, f) => s + f.score).clamp(0, 100);
    return HealthScore(score: total0to100, factors: factors);
  }
}
