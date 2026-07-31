/// Section 80C tax-saving tracker (India).
///
/// Under Section 80C an individual can claim a deduction of up to ₹1,50,000 per
/// financial year for qualifying investments (ELSS, PPF, NPS Tier-1, life
/// insurance premiums, 5-year tax-saver FDs, principal on a home loan, ...).
/// FinTrack lets the user flag a holding as 80C-eligible; this sums the flagged
/// contributions made inside the current Indian financial year (1 Apr - 31 Mar).
class Section80C {
  /// The statutory ceiling for a financial year, in rupees.
  static const double limit = 150000;

  /// Start of the Indian financial year containing [now] (1 April).
  /// Jan-Mar belong to the FY that began the previous April.
  static DateTime fyStart(DateTime now) =>
      now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);

  /// Exclusive end of the financial year containing [now] (1 April next year).
  static DateTime fyEndExclusive(DateTime now) {
    final start = fyStart(now);
    return DateTime(start.year + 1, 4, 1);
  }

  /// Human label for the FY containing [now], e.g. "FY 2026-27".
  static String fyLabel(DateTime now) {
    final start = fyStart(now);
    final endShort = (start.year + 1) % 100;
    return 'FY ${start.year}-${endShort.toString().padLeft(2, '0')}';
  }

  /// True when [date] falls inside the financial year containing [now].
  static bool isInCurrentFy(DateTime date, DateTime now) {
    final start = fyStart(now);
    final end = fyEndExclusive(now);
    return !date.isBefore(start) && date.isBefore(end);
  }
}

/// Progress toward the ₹1.5L Section 80C ceiling for one financial year.
class Section80CProgress {
  /// Total 80C-eligible amount invested in this financial year.
  final double invested;

  /// Headroom left before hitting the ₹1.5L ceiling (never negative).
  final double remaining;

  /// Fraction of the ceiling used, clamped to 0..1 (for progress bars).
  final double fraction;

  /// True once the ceiling is reached — further 80C investment earns no extra
  /// deduction this year.
  final bool limitReached;

  /// Financial-year label, e.g. "FY 2026-27".
  final String fyLabel;

  /// Number of holdings counted.
  final int count;

  const Section80CProgress({
    required this.invested,
    required this.remaining,
    required this.fraction,
    required this.limitReached,
    required this.fyLabel,
    required this.count,
  });

  /// Computes progress from the eligible amounts invested this FY.
  factory Section80CProgress.from({
    required double invested,
    required int count,
    required DateTime now,
  }) {
    final capped = invested.clamp(0.0, double.infinity);
    final remaining = (Section80C.limit - capped).clamp(0.0, Section80C.limit);
    return Section80CProgress(
      invested: capped,
      remaining: remaining,
      fraction: (capped / Section80C.limit).clamp(0.0, 1.0),
      limitReached: capped >= Section80C.limit,
      fyLabel: Section80C.fyLabel(now),
      count: count,
    );
  }
}
