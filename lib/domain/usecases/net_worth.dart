/// What kind of thing an account represents. This drives whether its balance
/// counts as an asset or a liability, so it is the single source of truth for
/// the sign of a balance anywhere in the app.
enum AccountKind {
  bank('bank', 'Bank account', false),
  cash('cash', 'Cash', false),
  wallet('wallet', 'Wallet / UPI', false),
  fd('fd', 'Fixed deposit', false),
  creditCard('credit_card', 'Credit card', true),
  loan('loan', 'Loan', true);

  const AccountKind(this.id, this.label, this.isLiability);

  /// Stable string persisted in Hive. Never rename these.
  final String id;

  /// Human label for pickers.
  final String label;

  /// True when a positive balance means money *owed*, not owned.
  final bool isLiability;

  static AccountKind fromId(String? id) =>
      AccountKind.values.firstWhere((k) => k.id == id, orElse: () => AccountKind.bank);
}

/// One account with its current balance.
///
/// For liabilities the balance is stored as a POSITIVE amount owed (e.g. a
/// ₹40,000 credit-card bill is `balance: 40000, kind: creditCard`), which keeps
/// user input natural — the sign is applied by [AccountKind.isLiability] rather
/// than asking the user to type a negative number.
class AccountBalance {
  final String id;
  final String name;
  final AccountKind kind;
  final double balance;

  const AccountBalance({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
  });

  bool get isLiability => kind.isLiability;

  /// Contribution to net worth: negative for liabilities.
  double get signedValue => isLiability ? -balance : balance;
}

/// Net worth split into its parts so the UI can explain the number rather than
/// just asserting it.
class NetWorthBreakdown {
  /// Cash-like account balances (bank, cash, wallet, FD).
  final double cashAssets;

  /// Current market value of investment holdings.
  final double investments;

  /// Total owed across credit cards and loans (positive number).
  final double liabilities;

  const NetWorthBreakdown({
    required this.cashAssets,
    required this.investments,
    required this.liabilities,
  });

  double get totalAssets => cashAssets + investments;
  double get netWorth => totalAssets - liabilities;

  /// True when there is nothing at all to report, so the UI can stay hidden
  /// instead of showing a meaningless ₹0 net worth.
  bool get isEmpty => cashAssets == 0 && investments == 0 && liabilities == 0;

  /// Debt as a fraction of assets (0..1+). Null when there are no assets, since
  /// a ratio against zero is undefined rather than infinite.
  double? get debtToAssetRatio => totalAssets > 0 ? liabilities / totalAssets : null;
}

/// A dated net-worth reading, used to draw the trend.
///
/// Stores the INPUT BREAKDOWN alongside the total. Past balances and past prices
/// are not retained anywhere, so a historical point can never be recomputed —
/// keeping the breakdown is what makes a later divergence *detectable* instead
/// of silent (e.g. the chart can flag "points before X reflect earlier balances").
class NetWorthPoint {
  final DateTime date;
  final double value;

  /// Cash-like account total at the time of recording. Null for points written
  /// before the breakdown existed.
  final double? cash;

  /// Investment market value at the time of recording. Null for legacy points.
  final double? investments;

  /// Total owed at the time of recording. Null for legacy points.
  final double? liabilities;

  const NetWorthPoint({
    required this.date,
    required this.value,
    this.cash,
    this.investments,
    this.liabilities,
  });

  /// True when this point carries its inputs and can be compared against a
  /// freshly computed breakdown.
  bool get hasBreakdown => cash != null && investments != null && liabilities != null;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
        if (cash != null) 'cash': cash,
        if (investments != null) 'investments': investments,
        if (liabilities != null) 'liabilities': liabilities,
      };

  static NetWorthPoint? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final d = DateTime.tryParse(raw['date'] as String? ?? '');
    final v = (raw['value'] as num?)?.toDouble();
    if (d == null || v == null) return null;
    return NetWorthPoint(
      date: d,
      value: v,
      // Absent on points written before the breakdown was added — treated as
      // unknown rather than zero, so they never masquerade as verified.
      cash: (raw['cash'] as num?)?.toDouble(),
      investments: (raw['investments'] as num?)?.toDouble(),
      liabilities: (raw['liabilities'] as num?)?.toDouble(),
    );
  }
}

class NetWorthCalculator {
  /// Sums accounts into a breakdown. [investments] is the live portfolio value,
  /// passed in so this stays free of storage and network concerns.
  static NetWorthBreakdown compute({
    required Iterable<AccountBalance> accounts,
    required double investments,
  }) {
    double cash = 0;
    double debt = 0;
    for (final a in accounts) {
      if (a.isLiability) {
        debt += a.balance;
      } else {
        cash += a.balance;
      }
    }
    return NetWorthBreakdown(
      cashAssets: cash,
      investments: investments,
      liabilities: debt,
    );
  }

  /// Appends today's reading to [history], keeping ONE point per calendar day
  /// (the latest wins) and at most [maxPoints] days. Pure: returns a new list.
  ///
  /// One-per-day matters because net worth is recomputed on every screen build;
  /// without it the trend would fill with dozens of identical same-day points.
  static List<NetWorthPoint> appendDaily(
    List<NetWorthPoint> history,
    double value, {
    required DateTime now,
    int maxPoints = 60,
    double? cash,
    double? investments,
    double? liabilities,
  }) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final out = [...history.where((p) => !sameDay(p.date, now))];
    out.add(NetWorthPoint(
      date: now,
      value: value,
      cash: cash,
      investments: investments,
      liabilities: liabilities,
    ));
    out.sort((a, b) => a.date.compareTo(b.date));
    if (out.length > maxPoints) {
      return out.sublist(out.length - maxPoints);
    }
    return out;
  }

  /// Drops every point dated on or after [from].
  ///
  /// Used when a retroactive edit or delete makes stored readings untrustworthy.
  /// A past point can never be recomputed (past balances and prices are not
  /// retained), so discarding it is the only honest option — the alternative,
  /// restamping today's value onto an old date, would flatten the trend into a
  /// straight line while still looking authoritative.
  static List<NetWorthPoint> truncateFrom(
    List<NetWorthPoint> history,
    DateTime from,
  ) {
    final cutoff = DateTime(from.year, from.month, from.day);
    return history
        .where((p) => DateTime(p.date.year, p.date.month, p.date.day).isBefore(cutoff))
        .toList();
  }

  /// True when [point] carries a breakdown that no longer matches [current] —
  /// i.e. the stored reading has diverged from reality. Legacy points without a
  /// breakdown return false (unknown, not "diverged").
  static bool hasDiverged(NetWorthPoint point, NetWorthBreakdown current) {
    if (!point.hasBreakdown) return false;
    const epsilon = 0.01;
    return (point.cash! - current.cashAssets).abs() > epsilon ||
        (point.investments! - current.investments).abs() > epsilon ||
        (point.liabilities! - current.liabilities).abs() > epsilon;
  }

  /// Change between the first and last points of [history].
  /// Null when there are fewer than two readings.
  static double? changeSinceStart(List<NetWorthPoint> history) {
    if (history.length < 2) return null;
    return history.last.value - history.first.value;
  }
}
