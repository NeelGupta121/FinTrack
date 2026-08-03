import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/local/local_database.dart';
import '../../domain/usecases/net_worth.dart';
import '../investments/investment_providers.dart';

const _historyKey = 'net_worth_history';

/// All accounts the user has entered, assets first then liabilities.
/// Reads the box directly, so mutations must invalidate it (see AccountsNotifier).
final accountsListProvider = Provider.autoDispose<List<AccountBalance>>((ref) {
  final out = <AccountBalance>[];
  for (final raw in LocalDatabase.accounts.values) {
    final id = raw['id'] as String?;
    if (id == null) continue;
    out.add(AccountBalance(
      id: id,
      name: (raw['name'] as String?) ?? 'Account',
      kind: AccountKind.fromId(raw['kind'] as String?),
      // Legacy rows (created before balances existed) have no balance -> 0.
      balance: (raw['balance'] as num?)?.toDouble() ?? 0,
    ));
  }
  out.sort((a, b) {
    if (a.isLiability != b.isLiability) return a.isLiability ? 1 : -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
});

/// Persisted net-worth readings (oldest first) for the trend chart.
final netWorthHistoryProvider = Provider.autoDispose<List<NetWorthPoint>>((ref) {
  final raw = LocalDatabase.settings.get(_historyKey, defaultValue: <dynamic>[]) as List? ?? [];
  return raw.map(NetWorthPoint.fromJson).whereType<NetWorthPoint>().toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

/// Real net worth: cash-like accounts + live portfolio value − money owed.
final netWorthProvider = FutureProvider.autoDispose<NetWorthBreakdown>((ref) async {
  final accounts = ref.watch(accountsListProvider);
  // Portfolio value already reflects live prices where available.
  final portfolio = await ref.watch(portfolioValueProvider.future);
  return NetWorthCalculator.compute(
    accounts: accounts,
    investments: portfolio.currentValue,
  );
});

/// Records today's net worth into history (one point per day), including the
/// input breakdown so a later divergence is detectable.
final netWorthRecorderProvider =
    Provider.autoDispose<void Function(NetWorthBreakdown)>((ref) {
  return (NetWorthBreakdown nw) async {
    try {
      final current = ref.read(netWorthHistoryProvider);
      final now = DateTime.now();
      final value = nw.netWorth;
      // Skip the write when today's stored point is already identical.
      final last = current.isNotEmpty ? current.last : null;
      final sameDay = last != null &&
          last.date.year == now.year &&
          last.date.month == now.month &&
          last.date.day == now.day;
      if (sameDay && last.value == value && !NetWorthCalculator.hasDiverged(last, nw)) {
        return;
      }
      final updated = NetWorthCalculator.appendDaily(
        current,
        value,
        now: now,
        cash: nw.cashAssets,
        investments: nw.investments,
        liabilities: nw.liabilities,
      );
      await LocalDatabase.settings
          .put(_historyKey, updated.map((p) => p.toJson()).toList());
      ref.invalidate(netWorthHistoryProvider);
    } catch (e, st) {
      AppLogger.error('Failed to record net worth', tag: 'NetWorth', error: e, stackTrace: st);
    }
  };
});

/// Discards net-worth history from [from] onward. Call this after a retroactive
/// edit/delete that makes stored readings untrustworthy — a past point cannot be
/// recomputed because past balances and prices are not retained.
final netWorthTruncateProvider =
    Provider.autoDispose<Future<void> Function(DateTime)>((ref) {
  return (DateTime from) async {
    try {
      final current = ref.read(netWorthHistoryProvider);
      final kept = NetWorthCalculator.truncateFrom(current, from);
      if (kept.length == current.length) return; // nothing to drop
      await LocalDatabase.settings
          .put(_historyKey, kept.map((p) => p.toJson()).toList());
      ref.invalidate(netWorthHistoryProvider);
    } catch (e, st) {
      AppLogger.error('Failed to truncate net worth history',
          tag: 'NetWorth', error: e, stackTrace: st);
    }
  };
});

final accountsNotifierProvider = Provider((ref) => AccountsNotifier(ref));

class AccountsNotifier {
  final Ref _ref;
  AccountsNotifier(this._ref);

  /// Creates or updates an account.
  ///
  /// [correctsPastData] tells us whether the balance is being *fixed* (the old
  /// value was wrong, so recorded history is untrustworthy) or has simply
  /// *changed today* (past readings were correct and must be kept). These are
  /// indistinguishable from the data alone, so the caller decides.
  Future<void> upsert({
    String? id,
    required String name,
    required AccountKind kind,
    required double balance,
    bool correctsPastData = false,
  }) async {
    final key = id ?? LocalDatabase.newId();
    final existing = id == null ? null : LocalDatabase.accounts.get(id);
    final balanceChanged =
        existing != null && ((existing['balance'] as num?)?.toDouble() ?? 0) != balance;

    await LocalDatabase.accounts.put(key, {
      'id': key,
      'name': name,
      'kind': kind.id,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // A corrected balance invalidates every stored reading (accounts carry no
    // dated history, so we cannot tell which points are affected) — discard the
    // whole series rather than let the trend show numbers we know are wrong.
    if (correctsPastData && balanceChanged) {
      await _ref.read(netWorthTruncateProvider)(DateTime(1970));
    }
    _invalidate();
  }

  Future<void> delete(String id) async {
    await LocalDatabase.accounts.delete(id);
    // Deleting an account always makes recorded history wrong: every past point
    // included this balance and it can never be reconstructed.
    await _ref.read(netWorthTruncateProvider)(DateTime(1970));
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(netWorthProvider);
  }
}
