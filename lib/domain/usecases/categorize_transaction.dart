import '../repositories/ai_repository.dart';

/// Categorize an expense description using on-device TFLite.
class CategorizeTransaction {
  final AiRepository _repo;
  CategorizeTransaction(this._repo);

  Future<String> call(String description) => _repo.categorizeExpense(description);
}
