import '../repositories/expense_repository.dart';

/// Analyze spending patterns and detect anomalies.
class AnalyzeSpending {
  final ExpenseRepository _repo;
  AnalyzeSpending(this._repo);

  // TODO: Compare current month vs 30-day rolling average
  // Flag categories where spending > 2 standard deviations
  Future<void> call() async {}
}
