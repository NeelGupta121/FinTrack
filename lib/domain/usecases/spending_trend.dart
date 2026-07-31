/// One month's spend in a trend series.
class MonthlySpend {
  /// First day of the month this bucket represents.
  final DateTime month;

  /// Short label for an axis, e.g. "Jul".
  final String label;

  /// Total expense amount in this month.
  final double total;

  const MonthlySpend({required this.month, required this.label, required this.total});
}

/// Builds a month-over-month spending series from dated amounts, so the UI can
/// render a bar chart without doing date maths in the widget layer.
class SpendingTrend {
  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String monthLabel(DateTime d) => _monthLabels[d.month - 1];

  /// Returns exactly [months] buckets ending with the month containing [now],
  /// oldest first. Months with no spend are present with a total of 0 so the
  /// chart keeps a stable, evenly-spaced x-axis.
  ///
  /// [dated] is a list of (date, amount) pairs — expenses only; the caller
  /// filters by type.
  static List<MonthlySpend> lastMonths(
    Iterable<({DateTime date, double amount})> dated, {
    required DateTime now,
    int months = 6,
  }) {
    assert(months > 0);
    // Build the ordered buckets first.
    final buckets = <DateTime, double>{};
    final order = <DateTime>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = DateTime(m.year, m.month, 1);
      buckets[key] = 0;
      order.add(key);
    }

    final earliest = order.first;
    // Exclusive upper bound = first day of the month after `now`.
    final endExclusive = DateTime(now.year, now.month + 1, 1);

    for (final e in dated) {
      if (e.date.isBefore(earliest) || !e.date.isBefore(endExclusive)) continue;
      final key = DateTime(e.date.year, e.date.month, 1);
      // Guard: only accumulate into a bucket we actually created.
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + e.amount;
      }
    }

    return [
      for (final k in order)
        MonthlySpend(month: k, label: monthLabel(k), total: buckets[k]!),
    ];
  }

  /// Percentage change from the previous month to the latest month.
  /// Null when there aren't two months or the previous month was zero
  /// (a percentage change from zero is undefined, not "infinite growth").
  static double? momChangePercent(List<MonthlySpend> series) {
    if (series.length < 2) return null;
    final prev = series[series.length - 2].total;
    final curr = series.last.total;
    if (prev <= 0) return null;
    return (curr - prev) / prev * 100;
  }
}
