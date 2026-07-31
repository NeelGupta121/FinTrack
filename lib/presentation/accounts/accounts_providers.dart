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

/// Records today's net worth into history (one point per day). Call this from a
/// screen after the value is known; it is a no-op-ish write that keeps the trend
/// populated without a background job.
final netWorthRecorderProvider = Provider.autoDispose<void Function(double)>((ref) {
  return (double value) async {
    try {
      final current = ref.read(netWorthHistoryProvider);
      final updated = NetWorthCalculator.appendDaily(current, value, now: DateTime.now());
      // Skip the write when the stored series is already identical for today.
      final last = current.isNotEmpty ? current.last : null;
      final now = DateTime.now();
      final sameDay = last != null &&
          last.date.year == now.year &&
          last.date.month == now.month &&
          last.date.day == now.day;
      if (sameDay && last.value == value) return;
      await LocalDatabase.settings
          .put(_historyKey, updated.map((p) => p.toJson()).toList());
      ref.invalidate(netWorthHistoryProvider);
    } catch (e, st) {
      AppLogger.error('Failed to record net worth', tag: 'NetWorth', error: e, stackTrace: st);
    }
  };
});

final accountsNotifierProvider = Provider((ref) => AccountsNotifier(ref));

class AccountsNotifier {
  final Ref _ref;
  AccountsNotifier(this._ref);

  Future<void> upsert({
    String? id,
    required String name,
    required AccountKind kind,
    required double balance,
  }) async {
    final key = id ?? LocalDatabase.newId();
    await LocalDatabase.accounts.put(key, {
      'id': key,
      'name': name,
      'kind': kind.id,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    });
    _invalidate();
  }

  Future<void> delete(String id) async {
    await LocalDatabase.accounts.delete(id);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(netWorthProvider);
  }
}
