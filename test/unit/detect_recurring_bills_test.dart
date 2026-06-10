import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/detect_recurring_bills.dart';

void main() {
  late DetectRecurringBills useCase;

  setUp(() => useCase = DetectRecurringBills());

  group('DetectRecurringBills', () {
    test('detects monthly recurring bills', () {
      final txns = List.generate(4, (i) => {
        return {
          'merchant': 'Netflix',
          'amount': 499,
          'date': DateTime(2026, 2 + i, 15).toIso8601String(),
        };
      });

      final bills = useCase.call(txns);
      expect(bills.length, 1);
      expect(bills[0].merchant, 'Netflix');
      expect(bills[0].frequency, BillFrequency.monthly);
      expect(bills[0].amount, 499.0);
    });

    test('predicts next due date correctly', () {
      final txns = [
        {'merchant': 'Gym', 'amount': 1000, 'date': '2026-03-01'},
        {'merchant': 'Gym', 'amount': 1000, 'date': '2026-04-01'},
        {'merchant': 'Gym', 'amount': 1000, 'date': '2026-05-01'},
      ];

      final bills = useCase.call(txns);
      expect(bills[0].nextDueDate, DateTime(2026, 6, 1));
    });

    test('ignores one-time transactions', () {
      final txns = [
        {'merchant': 'OneOff Store', 'amount': 2500, 'date': '2026-03-15'},
      ];

      final bills = useCase.call(txns);
      expect(bills, isEmpty);
    });

    test('ignores inconsistent amounts (>5% variation)', () {
      final txns = [
        {'merchant': 'Electric', 'amount': 500, 'date': '2026-01-10'},
        {'merchant': 'Electric', 'amount': 800, 'date': '2026-02-10'},
        {'merchant': 'Electric', 'amount': 300, 'date': '2026-03-10'},
      ];

      final bills = useCase.call(txns);
      expect(bills, isEmpty);
    });

    test('detects weekly patterns', () {
      final txns = List.generate(5, (i) => {
        return {
          'merchant': 'Maid Service',
          'amount': 200,
          'date': DateTime(2026, 3, 1 + (i * 7)).toIso8601String(),
        };
      });

      final bills = useCase.call(txns);
      expect(bills.length, 1);
      expect(bills[0].frequency, BillFrequency.weekly);
    });
  });
}
