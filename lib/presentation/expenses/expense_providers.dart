import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/transaction.dart';

// Filter state
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
  final filter = ref.watch(expenseFilterProvider);
  var query = SupabaseConfig.client.from('transactions').select().eq('type', 'expense').order('date', ascending: false);

  if (filter.startDate != null) query = query.gte('date', filter.startDate!.toIso8601String());
  if (filter.endDate != null) query = query.lte('date', filter.endDate!.toIso8601String());
  if (filter.categoryId != null) query = query.eq('category_id', filter.categoryId!);
  if (filter.minAmount != null) query = query.gte('amount', filter.minAmount!);
  if (filter.maxAmount != null) query = query.lte('amount', filter.maxAmount!);

  final data = await query;
  return (data as List).map((e) => Transaction(
    id: e['id'],
    amount: (e['amount'] as num).toDouble(),
    type: 'expense',
    description: e['description'],
    merchant: e['merchant'],
    date: DateTime.parse(e['date']),
    categoryId: e['category_id'],
    source: e['source'] ?? 'manual',
  )).toList();
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
    await SupabaseConfig.client.from('transactions').insert({
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
    await SupabaseConfig.client.from('transactions').delete().eq('id', id);
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
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);

  final data = await SupabaseConfig.client
      .from('transactions')
      .select()
      .eq('type', 'expense')
      .gte('date', start.toIso8601String())
      .lte('date', end.toIso8601String());

  final items = data as List;
  double total = 0;
  final catTotals = <String, double>{};
  for (final e in items) {
    final amt = (e['amount'] as num).toDouble();
    total += amt;
    final cat = e['category_id'] as String? ?? 'miscellaneous';
    catTotals[cat] = (catTotals[cat] ?? 0) + amt;
  }

  return MonthlySummary(totalSpent: total, budget: 50000, categoryTotals: catTotals);
});
