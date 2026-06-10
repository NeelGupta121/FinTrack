import '../entities/transaction.dart';

/// Contract for expense/transaction data operations.
abstract class ExpenseRepository {
  Future<List<Transaction>> getTransactions({DateTime? from, DateTime? to, String? categoryId});
  Future<Transaction> addTransaction(Transaction txn);
  Future<void> deleteTransaction(String id);
  Future<double> getMonthlyTotal(DateTime month);
  // TODO: getBudgetStatus, getRecurring
}
