import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/transaction.dart';

class ExpenseFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final double? minAmount;
  final double? maxAmount;

  const ExpenseFilter({this.startDate, this.endDate, this.categoryId, this.minAmount, this.maxAmount});

  ExpenseFilter copyWith({DateTime? startDate, DateTime? endDate, String? categoryId, double? minAmount, double? maxAmount}) =>
      ExpenseFilter(
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        categoryId: categoryId ?? this.categoryId,
        minAmount: minAmount ?? this.minAmount,
        maxAmount: maxAmount ?? this.maxAmount,
      );
}

final expenseFilterProvider = StateProvider<ExpenseFilter>((_) => const ExpenseFilter());

final expenseListProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  try {
    final filter = ref.watch(expenseFilterProvider);
    var items = LocalDatabase.transactions.values
        .where((e) => e['type'] == 'expense')
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
      items = items.where((e) => (e['amount'] as num).toDouble() >= filter.minAmount!).toList();
    }
    if (filter.maxAmount != null) {
      items = items.where((e) => (e['amount'] as num).toDouble() <= filter.maxAmount!).toList();
    }

    items.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return items.map((e) => Transaction(
      id: e['id'] as String,
      amount: (e['amount'] as num).toDouble(),
      type: 'expense',
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
  }) async {
    final id = LocalDatabase.newId();
    await LocalDatabase.transactions.put(id, {
      'id': id,
      'amount': amount,
      'currency': 'INR',
      'type': 'expense',
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'merchant': merchant,
      'source': source,
    });
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(monthlySummaryProvider);
  }

  Future<void> delete(String id) async {
    await LocalDatabase.transactions.delete(id);
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(monthlySummaryProvider);
  }
}

class MonthlySummary {
  final double totalSpent;
  final double budget;
  final Map<String, double> categoryTotals;
  MonthlySummary({required this.totalSpent, required this.budget, required this.categoryTotals});
}

final monthlySummaryProvider = FutureProvider.autoDispose<MonthlySummary>((ref) async {
  try {
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
      final amt = (e['amount'] as num).toDouble();
      total += amt;
      final cat = (e['category_id'] as String?) ?? 'miscellaneous';
      catTotals[cat] = (catTotals[cat] ?? 0) + amt;
    }

    return MonthlySummary(totalSpent: total, budget: 50000, categoryTotals: catTotals);
  } catch (e, st) {
    AppLogger.error('Failed to fetch monthly summary', tag: 'Expenses', error: e, stackTrace: st);
    rethrow;
  }
});
