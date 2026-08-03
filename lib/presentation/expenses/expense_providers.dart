import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/spending_trend.dart';
import '../../services/notification_service.dart';

class ExpenseFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final double? minAmount;
  final double? maxAmount;
  final String type; // 'expense' (default), 'income', or 'all'

  const ExpenseFilter({this.startDate, this.endDate, this.categoryId, this.minAmount, this.maxAmount, this.type = 'expense'});

  ExpenseFilter copyWith({DateTime? startDate, DateTime? endDate, String? categoryId, double? minAmount, double? maxAmount, String? type}) =>
      ExpenseFilter(
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        categoryId: categoryId ?? this.categoryId,
        minAmount: minAmount ?? this.minAmount,
        maxAmount: maxAmount ?? this.maxAmount,
        type: type ?? this.type,
      );
}

final expenseFilterProvider = StateProvider<ExpenseFilter>((_) => const ExpenseFilter());

final expenseListProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  try {
    final filter = ref.watch(expenseFilterProvider);
    var items = LocalDatabase.transactions.values
        .where((e) => filter.type == 'all'
            ? (e['type'] == 'expense' || e['type'] == 'income')
            : e['type'] == filter.type)
        .toList();

    if (filter.startDate != null) {
      items = items.where((e) => (DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime(2000)).isAfter(filter.startDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (filter.endDate != null) {
      items = items.where((e) => (DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime(2000)).isBefore(filter.endDate!.add(const Duration(days: 1)))).toList();
    }
    if (filter.categoryId != null) {
      items = items.where((e) => e['category_id'] == filter.categoryId).toList();
    }
    if (filter.minAmount != null) {
      items = items.where((e) => (e['amount'] as num? ?? 0).toDouble() >= filter.minAmount!).toList();
    }
    if (filter.maxAmount != null) {
      items = items.where((e) => (e['amount'] as num? ?? 0).toDouble() <= filter.maxAmount!).toList();
    }

    items.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return items.map((e) => Transaction(
      id: e['id'] as String,
      amount: (e['amount'] as num? ?? 0).toDouble(),
      type: (e['type'] as String?) ?? 'expense',
      description: e['description'] as String?,
      merchant: e['merchant'] as String?,
      date: DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime(2000),
      categoryId: e['category_id'] as String?,
      source: (e['source'] as String?) ?? 'manual',
    )).toList();
  } catch (e, st) {
    AppLogger.error('Failed to fetch expenses', tag: 'Expenses', error: e, stackTrace: st);
    rethrow;
  }
});

final addExpenseProvider = Provider((ref) => AddExpenseNotifier(ref));

class AddExpenseNotifier {
  final Ref _ref;
  AddExpenseNotifier(this._ref);

  Future<void> add({
    required double amount,
    required String categoryId,
    required DateTime date,
    String? description,
    String? merchant,
    String source = 'manual',
    String type = 'expense',
  }) async {
    final id = LocalDatabase.newId();
    await LocalDatabase.transactions.put(id, {
      'id': id,
      'amount': amount,
      'currency': 'INR',
      'type': type,
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'merchant': merchant,
      'source': source,
    });
    _invalidateDependents();
  }

  /// Updates an existing transaction in place, preserving its id and source.
  /// Every field the edit form can change is passed explicitly so a partially
  /// filled form can never silently blank a stored value.
  Future<void> update({
    required String id,
    required double amount,
    required String categoryId,
    required DateTime date,
    String? description,
    String? merchant,
    required String type,
  }) async {
    final existing = LocalDatabase.transactions.get(id);
    if (existing == null) {
      throw StateError('Transaction $id no longer exists');
    }
    await LocalDatabase.transactions.put(id, {
      ...Map<String, dynamic>.from(existing),
      'id': id,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'merchant': merchant,
    });
    _invalidateDependents();
  }

  /// Deletes a transaction and returns its stored row so the caller can offer
  /// Undo. Returns null when the id no longer exists.
  Future<Map<String, dynamic>?> delete(String id) async {
    final existing = LocalDatabase.transactions.get(id);
    if (existing == null) return null;
    final copy = Map<String, dynamic>.from(existing);
    await LocalDatabase.transactions.delete(id);
    _invalidateDependents();
    return copy;
  }

  /// Re-inserts a previously deleted transaction (Undo).
  Future<void> restore(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;
    await LocalDatabase.transactions.put(id, row);
    _invalidateDependents();
  }

  /// Single place that refreshes everything derived from the transactions box.
  /// Providers that read Hive directly are NOT rebuilt by a box write, so every
  /// mutation must come through here — forgetting one leaves stale UI (this bug
  /// already shipped once with spendingTrendProvider).
  void _invalidateDependents() {
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(monthlySummaryProvider);
    _ref.invalidate(spendingTrendProvider);
    _ref.invalidate(monthlyIncomeProvider);
  }
}

/// Month-over-month expense totals for the last 6 months (oldest first).
/// Reads the box directly, so every mutation must invalidate it (see
/// AddExpenseNotifier.add/delete) — a Hive write does not rebuild providers.
final spendingTrendProvider = Provider.autoDispose<List<MonthlySpend>>((ref) {
  final dated = <({DateTime date, double amount})>[];
  for (final e in LocalDatabase.transactions.values) {
    if (e['type'] != 'expense') continue;
    final d = DateTime.tryParse(e['date'] as String? ?? '');
    if (d == null) continue;
    dated.add((date: d, amount: (e['amount'] as num? ?? 0).toDouble()));
  }
  return SpendingTrend.lastMonths(dated, now: DateTime.now(), months: 6);
});

/// Total income logged in the current calendar month. Lives here (not in
/// wellness_providers) because it reads the transactions box directly and so
/// MUST be invalidated by every transaction mutation — see
/// AddExpenseNotifier._invalidateDependents.
final monthlyIncomeProvider = Provider.autoDispose<double>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  double total = 0;
  for (final e in LocalDatabase.transactions.values) {
    if (e['type'] != 'income') continue;
    final d = DateTime.tryParse(e['date'] as String? ?? '');
    if (d == null) continue;
    if (d.isAfter(start.subtract(const Duration(days: 1))) &&
        d.isBefore(end.add(const Duration(days: 1)))) {
      total += (e['amount'] as num? ?? 0).toDouble();
    }
  }
  return total;
});

class MonthlySummary {
  final double totalSpent;
  final double budget;
  final Map<String, double> categoryTotals;
  MonthlySummary({required this.totalSpent, required this.budget, required this.categoryTotals});
}

/// User-configurable monthly budget (persisted in Hive settings; default ₹50,000).
final monthlyBudgetProvider = Provider.autoDispose<double>((ref) =>
    (LocalDatabase.settings.get('monthly_budget') as num?)?.toDouble() ?? 50000.0);

final monthlySummaryProvider = FutureProvider.autoDispose<MonthlySummary>((ref) async {
  try {
    final budget = ref.watch(monthlyBudgetProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    final items = LocalDatabase.transactions.values
        .where((e) => e['type'] == 'expense')
        .where((e) {
          final d = DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime(2000);
          return d.isAfter(start.subtract(const Duration(days: 1))) && d.isBefore(end.add(const Duration(days: 1)));
        })
        .toList();

    double total = 0;
    final catTotals = <String, double>{};
    for (final e in items) {
      final amt = (e['amount'] as num? ?? 0).toDouble();
      total += amt;
      final cat = (e['category_id'] as String?) ?? 'miscellaneous';
      catTotals[cat] = (catTotals[cat] ?? 0) + amt;
    }

    return MonthlySummary(totalSpent: total, budget: budget, categoryTotals: catTotals);
  } catch (e, st) {
    AppLogger.error('Failed to fetch monthly summary', tag: 'Expenses', error: e, stackTrace: st);
    rethrow;
  }
});

/// Side-effect provider: fires a budget-threshold notification when this month's
/// spend reaches >=80% of the configured budget (no-op on web). Watch it from a
/// screen (expense list) to activate. Stable notification ID -> no spam.
final budgetAlertProvider = Provider.autoDispose<void>((ref) {
  final summary = ref.watch(monthlySummaryProvider).valueOrNull;
  if (summary == null || summary.budget <= 0) return;
  final pct = summary.totalSpent / summary.budget * 100;
  if (pct >= 80) {
    unawaited(ref.read(notificationServiceProvider).budgetThresholdAlert('Monthly budget', pct));
  }
});
