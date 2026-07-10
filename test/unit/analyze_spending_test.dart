import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/analyze_spending.dart';
import 'package:fintrack/domain/entities/transaction.dart';

Transaction _tx(String id, double amount, String category, {int daysAgo = 0}) {
  return Transaction(
    id: id,
    amount: amount,
    type: 'expense',
    date: DateTime.now().subtract(Duration(days: daysAgo)),
    categoryId: category,
  );
}

void main() {
  late AnalyzeSpendingUseCase useCase;

  setUp(() => useCase = AnalyzeSpendingUseCase());

  group('AnalyzeSpendingUseCase', () {
    test('flags transaction >2σ above category average', () {
      final txns = [
        _tx('1', 100, 'food', daysAgo: 1),
        _tx('2', 110, 'food', daysAgo: 5),
        _tx('3', 95, 'food', daysAgo: 10),
        _tx('4', 105, 'food', daysAgo: 15),
        _tx('5', 500, 'food', daysAgo: 2), // anomaly
      ];

      final anomalies = useCase.detectAnomalies(txns);
      expect(anomalies, isNotEmpty);
      expect(anomalies[0].amount, 500);
      expect(anomalies[0].zScore, greaterThan(2.0));
    });

    test('does not flag normal transactions', () {
      final txns = [
        _tx('1', 100, 'food', daysAgo: 1),
        _tx('2', 105, 'food', daysAgo: 5),
        _tx('3', 98, 'food', daysAgo: 10),
        _tx('4', 102, 'food', daysAgo: 15),
      ];

      final anomalies = useCase.detectAnomalies(txns);
      expect(anomalies, isEmpty);
    });

    test('handles empty history gracefully', () {
      final anomalies = useCase.detectAnomalies([]);
      expect(anomalies, isEmpty);
    });

    test('skips categories with fewer than 3 transactions', () {
      final txns = [
        _tx('1', 100, 'travel', daysAgo: 1),
        _tx('2', 9999, 'travel', daysAgo: 5),
      ];

      final anomalies = useCase.detectAnomalies(txns);
      expect(anomalies, isEmpty);
    });

    test('Anomaly.percentAboveAverage is finite (0) when average is 0', () {
      const a = Anomaly(category: 'x', amount: 100, average: 0, deviation: 0, zScore: 0);
      expect(a.percentAboveAverage, 0);
      expect(a.percentAboveAverage.isFinite, isTrue);
    });
  });
}
